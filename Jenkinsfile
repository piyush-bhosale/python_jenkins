pipeline {
  agent { label 'myagent' }

  options {
    timestamps()
    ansiColor('xterm')
  }

  stages {
    stage('Checkout Code') {
      steps {
        checkout scm
      }
    }

    stage('Setup Python') {
      steps {
        sh '''
          set -euxo pipefail

          python3 -m venv .venv
          . .venv/bin/activate

          python -m pip install --upgrade pip wheel setuptools

          # Install dependencies if present
          [ -f requirements.txt ] && pip install -r requirements.txt || true
          [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || true

          # IMPORTANT: install your repo as a package (needs pyproject.toml or setup.py)
          pip install -e .
        '''
      }
    }

    stage('Run Tests') {
      steps {
        sh '''
          set -euxo pipefail
          . .venv/bin/activate

          # Create reports even if failures happen later
          pytest -q --junitxml=report.xml --cov=. --cov-report=xml
        '''
      }
    }

    stage('Python Quality Stack') {
      steps {
        sh '''
          set -euxo pipefail
          . .venv/bin/activate

          echo "=============================="
          echo "1) Ruff Lint"
          echo "=============================="
          python -m ruff --version
          python -m ruff check .

          echo "=============================="
          echo "2) Ruff Format Check (recommended)"
          echo "=============================="
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
          echo "5) Bandit Security Scan (Python SAST)"
          echo "=============================="
          python -m bandit -r . -ll

          echo "=============================="
          echo "6) pip-audit (Dependency Vulnerability Scan)"
          echo "=============================="
          # Ensure pip-audit is installed (commonly in dev requirements)
          python -m pip install -q pip-audit || true
          pip-audit || true

          echo "=============================="
          echo "✅ All Python quality checks completed"
          echo "=============================="
        '''
      }
    }
  }

  post {
    always {
      // Publish JUnit even if tests fail
      junit allowEmptyResults: true, testResults: 'report.xml'

      // Archive coverage for later use (SonarQube can consume coverage.xml too)
      archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
    }
  }
}
