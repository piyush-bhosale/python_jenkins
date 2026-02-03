pipeline {
  agent { label 'myagent' }

  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  environment {
    SONAR_TOKEN = credentials('SonarQube2')
    DOCKERHUB_REPO = 'piyushbhosale9226/python_jenkins'
    IMAGE_LOCAL_NAME = 'python-jenkins-demo'
    S3_BUCKET = 'demo-python-jenkins'
    AWS_REGION = 'ap-south-1'
  }

  stages {

    stage('Checkout Code') {
      steps { checkout scm }
    }

    stage('Preflight Validation') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          echo "Validating Python Environment"
          python3 --version
          pip3 --version

          echo "Checking required project files"
          test -f pyproject.toml || test -f setup.py

          echo "Checking required directories"
          test -d app || true
          test -d tests

          echo "Checking requirements-dev.txt exists"
          test -f requirements-dev.txt

          echo "Preflight checks passed"
        '''
      }
    }

    stage('Setup Python') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          python3 -m venv .venv
          source .venv/bin/activate

          python -m pip install --upgrade pip wheel setuptools
          pip install -r requirements-dev.txt
          pip install -e .
        '''
      }
    }

    stage('Dependency Lock Enforcement') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          echo "Checking requirements-dev.txt is fully pinned (== only)"
          test -f requirements-dev.txt

          # Ignore blanks/comments/options, fail if line is unpinned or uses >= <= ~= !=
          bad=$(grep -nEv '^(\\s*$|\\s*#|\\s*-r\\s+|\\s*-c\\s+|\\s*--|\\s*-f\\s+|\\s*-i\\s+)' requirements-dev.txt \
                | grep -nE '(^[^=<>!~@]+$|>=|<=|~=|!=)' || true)

          if [[ -n "$bad" ]]; then
            echo "Found non-locked dependencies in requirements-dev.txt:"
            echo "$bad"
            exit 1
          fi

          echo "requirements-dev.txt looks locked (pinned)"
        '''
      }
    }

    stage('Run Tests') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail
          source .venv/bin/activate

          pytest -q --junitxml=report.xml --cov=. --cov-report=xml
        '''
      }
    }

    stage('Python Quality Stack') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail
          source .venv/bin/activate

          echo "=============================="
          echo "1) Ruff Lint"
          echo "=============================="
          python -m ruff --version
          python -m ruff check .

          echo "=============================="
          echo "2) Ruff Format Check (NON-BLOCKING)"
          echo "=============================="
          python -m ruff format --check . || true

          echo "=============================="
          echo "3) Black Format Check (optional, NON-BLOCKING)"
          echo "=============================="
          python -m black --check . || true

          echo "=============================="
          echo "4) Mypy Type Checking (optional, NON-BLOCKING)"
          echo "=============================="
          python -m mypy --ignore-missing-imports . || true

          echo "=============================="
          echo "5) Bandit Security Scan (NON-BLOCKING)"
          echo "=============================="
          python -m bandit -r app tests -ll || true

          echo "=============================="
          echo "6) pip-audit (Dependency Scan, NON-BLOCKING)"
          echo "=============================="
          pip-audit || true
        '''
      }
    }

    stage('OWASP Dependency-Check (CVE Scan)') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail
          cp -f requirements-dev.txt requirements.txt
        '''

        catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') {
          dependencyCheck(
            odcInstallation: 'OWASP-DC',
            additionalArguments: '''
              --scan .
              --format XML
              --out .
              --enableExperimental
              --exclude **/.venv/**
              --exclude **/.git/**
              --exclude **/__pycache__/**
            ''',
            debug: true
          )
          dependencyCheckPublisher(
            pattern: '**/dependency-check-report.xml',
            stopBuild: false,
            skipNoReportFiles: true
          )
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('SonarQube_Server') {
          sh '''#!/usr/bin/env bash
            set -euxo pipefail

            sonar-scanner \
              -Dsonar.projectKey=python_jenkins \
              -Dsonar.projectName=python_jenkins \
              -Dsonar.sources=app \
              -Dsonar.tests=tests \
              -Dsonar.python.coverage.reportPaths=coverage.xml \
              -Dsonar.junit.reportPaths=report.xml \
              -Dsonar.login=${SONAR_TOKEN}
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 20, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Build Package (Wheel + sdist)') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail
          source .venv/bin/activate

          rm -rf dist/ build/ *.egg-info || true
          python -m pip install --upgrade build
          python -m build
          ls -lh dist/
        '''
      }
    }

    stage('Build Docker Image') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          GIT_SHA=$(git rev-parse --short HEAD)
          LOCAL_TAG="${IMAGE_LOCAL_NAME}:${BUILD_NUMBER}-${GIT_SHA}"

          echo "Building Docker image: ${LOCAL_TAG}"
          docker build -t "${LOCAL_TAG}" .

          echo "${LOCAL_TAG}" > image_tag.txt
          echo "Image created: ${LOCAL_TAG}"
        '''
      }
    }

    stage('Trivy Image Scan') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          LOCAL_TAG=$(cat image_tag.txt)
          echo "Trivy scanning image: ${LOCAL_TAG}"

          # Non-blocking scan + JSON report [4](https://github.com/aquasecurity/trivy)[5](https://janik6n.net/posts/run-security-scans-on-terraform-and-opentofu-project-with-trivy-and-github-actions/)
          trivy image --no-progress --severity HIGH,CRITICAL --exit-code 0 "${LOCAL_TAG}" || true
          trivy image --no-progress --format json --output trivy-image-report.json "${LOCAL_TAG}" || true

          echo "Trivy scan completed (non-blocking)."
        '''
      }
    }

    stage('Push Image to DockerHub') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKERHUB_USER',
          passwordVariable: 'DOCKERHUB_PASS'
        )]) {
          sh '''#!/usr/bin/env bash
            set -euxo pipefail

            LOCAL_TAG=$(cat image_tag.txt)
            TAG="${LOCAL_TAG#*:}"
            DOCKERHUB_IMAGE="${DOCKERHUB_REPO}:${TAG}"

            echo "➡ Tagging image for Docker Hub: ${DOCKERHUB_IMAGE}"
            docker tag "${LOCAL_TAG}" "${DOCKERHUB_IMAGE}"

            # Secure login using --password-stdin [2](https://nvd.nist.gov/developers/request-an-api-key)[6](https://ttlnews.blogspot.com/2023/12/owasp-dependencycheck-returns-403.html)
            echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin

            # Push image to Docker Hub [3](https://github.com/EmAdd9/Dependency-Check)
            docker push "${DOCKERHUB_IMAGE}"

            echo "Pushed to Docker Hub: ${DOCKERHUB_IMAGE}"
            echo "${DOCKERHUB_IMAGE}" > dockerhub_image.txt
          '''
        }
      }
    }

    stage('Upload Artifacts to S3 (demo-python-jenkins)') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          # Build region arg properly (safe even with set -u)
          AWS_REGION_VALUE="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
          REGION_ARG=()
          if [[ -n "${AWS_REGION_VALUE}" ]]; then
            REGION_ARG=(--region "${AWS_REGION_VALUE}")
          fi

          DEST="s3://${S3_BUCKET}/jenkins-builds/${JOB_NAME}/${BUILD_NUMBER}/"
          echo "⬆ Uploading artifacts to: ${DEST}"

          # Upload build artifacts (recursive for directories) [1](https://ichard26.github.io/blog/2026/01/whats-new-in-pip-26.0/)
          if [[ -d dist ]]; then
            aws s3 cp dist/ "${DEST}dist/" --recursive "${REGION_ARG[@]}"
          fi

          # Upload reports and metadata if present [1](https://ichard26.github.io/blog/2026/01/whats-new-in-pip-26.0/)
          [[ -f coverage.xml ]] && aws s3 cp coverage.xml "${DEST}" "${REGION_ARG[@]}" || true
          [[ -f report.xml ]] && aws s3 cp report.xml "${DEST}" "${REGION_ARG[@]}" || true

          ls dependency-check-report.* >/dev/null 2>&1 && aws s3 cp dependency-check-report.* "${DEST}" "${REGION_ARG[@]}" || true
          [[ -f trivy-image-report.json ]] && aws s3 cp trivy-image-report.json "${DEST}" "${REGION_ARG[@]}" || true
          [[ -f image_tag.txt ]] && aws s3 cp image_tag.txt "${DEST}" "${REGION_ARG[@]}" || true
          [[ -f dockerhub_image.txt ]] && aws s3 cp dockerhub_image.txt "${DEST}" "${REGION_ARG[@]}" || true

          echo "S3 upload complete"
        '''
      }
    }

  }

  post {
    always {
      junit allowEmptyResults: true, testResults: 'report.xml'

      archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
      archiveArtifacts artifacts: 'report.xml', allowEmptyArchive: true
      archiveArtifacts artifacts: 'dist/*', allowEmptyArchive: true
      archiveArtifacts artifacts: 'dependency-check-report.*', allowEmptyArchive: true

      archiveArtifacts artifacts: 'image_tag.txt,trivy-image-report.json,dockerhub_image.txt', allowEmptyArchive: true
    }
  }
}
