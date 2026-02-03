pipeline {
  agent { label 'myagent' }

  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  environment {
    SONAR_TOKEN = credentials('SonarQube2')
  }

  stages {

    stage('Checkout Code') {
      steps { checkout scm }
    }

    stage('Preflight Validation') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          echo "➡ Validating Python Environment"
          python3 --version
          pip3 --version

          echo "➡ Checking required project files"
          test -f pyproject.toml || test -f setup.py

          echo "➡ Checking required directories"
          test -d app || true
          test -d tests

          echo "➡ Checking requirements-dev.txt exists"
          test -f requirements-dev.txt

          echo "✅ Preflight checks passed"
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

          # Install ONLY dev requirements
          pip install -r requirements-dev.txt

          # Install your repo as a package
          pip install -e .
        '''
      }
    }

    stage('Dependency Lock Enforcement') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          echo "➡ Checking requirements-dev.txt is fully pinned (== only)"
          test -f requirements-dev.txt

          # Ignore blanks/comments/options, fail if line is unpinned or uses >= <= ~= !=
          bad=$(grep -nEv '^(\\s*$|\\s*#|\\s*-r\\s+|\\s*-c\\s+|\\s*--|\\s*-f\\s+|\\s*-i\\s+)' requirements-dev.txt \
                | grep -nE '(^[^=<>!~@]+$|>=|<=|~=|!=)' || true)

          if [[ -n "$bad" ]]; then
            echo "❌ Found non-locked dependencies in requirements-dev.txt:"
            echo "$bad"
            exit 1
          fi

          echo "✅ requirements-dev.txt looks locked (pinned)"
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

          # Dependency-Check pip analyzer expects requirements.txt
          cp -f requirements-dev.txt requirements.txt
        '''

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

        // Always SUCCESS (no thresholds)
        dependencyCheckPublisher(
          pattern: '**/dependency-check-report.xml',
          stopBuild: false,
          skipNoReportFiles: true
        )
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

    // ✅ Docker build MUST be inside stages{}
    stage('Build Docker Image') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          GIT_SHA=$(git rev-parse --short HEAD)
          IMAGE_TAG="python-jenkins-demo:${BUILD_NUMBER}-${GIT_SHA}"

          echo "✅ Building Docker image: ${IMAGE_TAG}"

          # docker build builds image from Dockerfile in current directory. [1](https://discuss.python.org/t/announcement-pip-26-0-release/105947)[2](https://pip.pypa.io/en/stable/news/)
          docker build -t "${IMAGE_TAG}" .

          echo "${IMAGE_TAG}" > image_tag.txt
          echo "✅ Image created: ${IMAGE_TAG}"
        '''
      }
    }

    // ✅ Trivy scan MUST be inside stages{}
    stage('Trivy Image Scan') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          IMAGE_TAG=$(cat image_tag.txt)
          echo "🔍 Trivy scanning image: ${IMAGE_TAG}"

          # trivy image scans container image; supports --severity and --exit-code. [3](https://pypi.org/project/pip-tools/)[4](https://discuss.python.org/t/install-prerelease-of-a-project-but-not-of-its-dependencies/49640)
          trivy image --no-progress --severity HIGH,CRITICAL --exit-code 0 "${IMAGE_TAG}" || true

          # Optional JSON report
          trivy image --no-progress --format json --output trivy-image-report.json "${IMAGE_TAG}" || true

          echo "✅ Trivy scan completed (non-blocking)."
        '''
      }
    }

  } // <-- end stages

  post {
    always {
      junit allowEmptyResults: true, testResults: 'report.xml'
      archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
      archiveArtifacts artifacts: 'dist/*', allowEmptyArchive: true
      archiveArtifacts artifacts: 'dependency-check-report.*', allowEmptyArchive: true

      // Trivy artifacts (optional)
      archiveArtifacts artifacts: 'image_tag.txt,trivy-image-report.json', allowEmptyArchive: true
    }
  }
}
