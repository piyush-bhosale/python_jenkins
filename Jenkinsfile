pipeline {
  agent { label 'myagent' }

  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  environment {
    // SonarQube token credential ID in Jenkins
    SONAR_TOKEN = credentials('SonarQube2')
  }

  stages {

    stage('Preflight Validation') {
      steps {
        sh '''
          set -euxo pipefail

          echo "➡ Validating Python Environment"
          python3 --version
          pip3 --version

          echo "➡ Checking required project files"
          test -f pyproject.toml || test -f setup.py

          echo "➡ Checking required directories"
          test -d app
          test -d tests

          echo "➡ Checking requirements syntax (if exists)"
          if [[ -f requirements.txt ]]; then
            pip3 install -r requirements.txt --dry-run
          fi

          echo "✅ Preflight checks passed"
        '''
      }
    }

    stage('Checkout Code') {
      steps {
        checkout scm
      }
    }

    stage('Setup Python') {
      steps {
        sh '''#!/usr/bin/env bash
          set -euxo pipefail

          python3 -m venv .venv
          source .venv/bin/activate

          python -m pip install --upgrade pip wheel setuptools

          # Install dependencies if present
          [[ -f requirements.txt ]] && pip install -r requirements.txt || true
          [[ -f requirements-dev.txt ]] && pip install -r requirements-dev.txt || true

          # Install your repo as a package (requires pyproject.toml or setup.py)
          pip install -e .
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
          echo "2) Ruff Format Check"
          echo "=============================="
          python -m ruff format .
          python -m ruff format --check .

          echo "=============================="
          echo "3) Black Format Check (optional)"
          echo "=============================="
          python -m black --version
          python -m black --check .

          echo "=============================="
          echo "4) Mypy Type Checking (optional)"
          echo "=============================="
          python -m mypy --ignore-missing-imports .

          echo "=============================="
          echo "5) Bandit Security Scan"
          echo "=============================="
          python -m bandit -r app tests -ll

          echo "=============================="
          echo "6) pip-audit (Dependency Scan)"
          echo "=============================="
          python -m pip install -q pip-audit || true
          pip-audit || true

          echo "=============================="
          echo "✅ Quality checks completed"
          echo "=============================="
        '''
      }
    }

    stage('SonarQube Analysis') {
      steps {
        // Uses the SonarQube server configured in Jenkins:
        // Manage Jenkins -> System -> SonarQube servers (Name = SonarQube_Server)
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

          echo "=============================="
          echo "📦 Building package artifacts"
          echo "=============================="

          rm -rf dist/ build/ *.egg-info || true

          python -m pip install --upgrade build
          python -m build

          echo "✅ Built artifacts:"
          ls -lh dist/
        '''
      }
    }
  }

  post {
    always {
      junit allowEmptyResults: true, testResults: 'report.xml'
      archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
      archiveArtifacts artifacts: 'dist/*', allowEmptyArchive: true
    }
  }
}
