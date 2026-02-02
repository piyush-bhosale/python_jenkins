pipeline {
  agent { label 'myagent' }

  stages {

    stage('Checkout Code') {
      steps {
        checkout scm
      }
    }

    stage('Setup Python') {
      steps {
        sh '''
          set -eux
          python3 -m venv .venv
          . .venv/bin/activate

          python -m pip install --upgrade pip

          # Install runtime deps if file exists
          [ -f requirements.txt ] && pip install -r requirements.txt || true

          # Install dev/CI deps if file exists
          [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || true

          # Install your repo as a package (works because you have pyproject.toml)
          pip install -e .
        '''
      }
    }

    stage('Python Quality Stack') {
      steps {
        sh '''
          set -eux
          . .venv/bin/activate

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
          python -m bandit -r . -x .venv,tests -ll

          echo "=============================="
          echo "6) pip-audit (Dependency Vulnerabilities)"
          echo "=============================="
          python -m pip_audit

          echo "=============================="
          echo "7) Unit Tests + Coverage + JUnit"
          echo "=============================="
          pytest -q --junitxml=report.xml --cov=. --cov-report=xml

          echo "=============================="
          echo "✅ All Python quality checks passed"
          echo "=============================="
        '''
      }

      post {
        always {
          junit 'report.xml'
          archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
        }
      }
    }

  }
}
