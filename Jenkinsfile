pipeline {
  agent { label 'myagent' }

  options {
    timestamps()
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
          set -euo pipefail

          python3 -m venv .venv
          . .venv/bin/activate

          python -m pip install --upgrade pip

          # Install runtime deps if file exists
          [ -f requirements.txt ] && pip install -r requirements.txt || true

          # Install dev/CI tools if file exists
          [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || true

          # Install your project (editable)
          pip install -e .
        '''
      }
    }

    stage('Python Quality Stack') {
      steps {
        sh '''
          set -euo pipefail
          . .venv/bin/activate

          # Fresh folders for this run
          rm -rf logs reports || true
          mkdir -p logs reports

          run_step () {
            STEP_NAME="$1"
            LOG_FILE="$2"
            shift 2

            echo "[INFO] Running: ${STEP_NAME}"
            # Run command, capture all output to file (no console spam)
            "$@" > "${LOG_FILE}" 2>&1 || {
              echo "[ERROR] ${STEP_NAME} failed. See ${LOG_FILE}"
              exit 1
            }
            echo "[INFO] ${STEP_NAME} completed. Log: ${LOG_FILE}"
          }

          # 1) Ruff Lint
          run_step "Ruff Lint" "logs/01_ruff_lint.log" \
            python -m ruff check .

          # 2) Ruff Format Check (STRICT)
          run_step "Ruff Format Check" "logs/02_ruff_format_check.log" \
            python -m ruff format --check .

          # 3) Black Format Check (OPTIONAL - keep only if you want both)
          run_step "Black Format Check" "logs/03_black_check.log" \
            python -m black --check .

          # 4) Mypy Type Check
          run_step "Mypy Type Check" "logs/04_mypy.log" \
            python -m mypy --ignore-missing-imports .

          # 5) Bandit Security Scan (scan ONLY your source; adjust if your source dir differs)
          # If your source folder is not "app", change "app" -> "src" or your folder name.
          run_step "Bandit Scan" "logs/05_bandit.log" \
            python -m bandit -r app -ll -f json -o reports/bandit.json

          # 6) pip-audit Dependency Vulnerabilities
          run_step "pip-audit Scan" "logs/06_pip_audit.log" \
            python -m pip_audit -f json -o reports/pip_audit.json

          # 7) Pytest + Coverage + JUnit
          # report.xml and coverage.xml are created even though output is redirected.
          run_step "Pytest + Coverage" "logs/07_pytest.log" \
            pytest -q --junitxml=reports/report.xml --cov=. --cov-report=xml:reports/coverage.xml

          echo "[INFO] ✅ All Python quality checks passed."
        '''
      }

      post {
        always {
          // Publish junit if present; do not fail if missing
          junit allowEmptyResults: true, testResults: 'reports/report.xml'

          // Archive all logs and reports for download
          archiveArtifacts artifacts: 'logs/**,reports/**', allowEmptyArchive: true
        }
      }
    }
  }
}
