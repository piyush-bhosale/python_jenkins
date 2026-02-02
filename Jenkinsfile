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

    stage('Init Folders') {
      steps {
        sh '''
          bash <<'BASH'
          set -euo pipefail
          rm -rf logs reports || true
          mkdir -p logs reports
          BASH
        '''
      }
    }

    stage('Setup Python') {
      steps {
        sh '''
          bash <<'BASH'
          set -euo pipefail

          {
            echo "[INFO] Creating venv"
            python3 -m venv .venv
            . .venv/bin/activate

            echo "[INFO] Upgrading pip"
            python -m pip install --upgrade pip

            echo "[INFO] Installing runtime deps (if requirements.txt exists)"
            [ -f requirements.txt ] && pip install -r requirements.txt || true

            echo "[INFO] Installing dev deps (if requirements-dev.txt exists)"
            [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || true

            echo "[INFO] Installing project (editable)"
            pip install -e .

            echo "[INFO] Setup completed"
          } > logs/00_setup_python.log 2>&1

          echo "[INFO] Setup Python done. Log: logs/00_setup_python.log"
          BASH
        '''
      }
    }

    stage('Python Quality Stack') {
      steps {
        sh '''
          bash <<'BASH'
          set -euo pipefail
          . .venv/bin/activate

          run_step () {
            STEP_NAME="$1"
            LOG_FILE="$2"
            shift 2

            echo "[INFO] Running: ${STEP_NAME}"
            # run command silently; store output into log file
            "$@" > "${LOG_FILE}" 2>&1 || {
              echo "[ERROR] ${STEP_NAME} failed. Check ${LOG_FILE}"
              exit 1
            }
            echo "[INFO] ${STEP_NAME} OK. Log: ${LOG_FILE}"
          }

          # 1) Ruff Lint
          run_step "Ruff Lint" "logs/01_ruff_lint.log" \
            python -m ruff check .

          # 2) Ruff Format Check (STRICT - does NOT auto-fix)
          run_step "Ruff Format Check" "logs/02_ruff_format_check.log" \
            python -m ruff format --check .

          # 3) Black Check (optional - keep only if you want Black too)
          run_step "Black Format Check" "logs/03_black_check.log" \
            python -m black --check .

          # 4) Mypy Type Check
          run_step "Mypy Type Check" "logs/04_mypy.log" \
            python -m mypy --ignore-missing-imports .

          # 5) Bandit Security Scan (IMPORTANT: scan only YOUR source folder)
          # Your repo seems to use app/ (app/main.py). If your source folder differs, change app -> src.
          run_step "Bandit Scan" "logs/05_bandit.log" \
            python -m bandit -r app -ll -f json -o reports/bandit.json

          # 6) pip-audit Dependency Scan (JSON report)
          run_step "pip-audit Scan" "logs/06_pip_audit.log" \
            python -m pip_audit -f json -o reports/pip_audit.json

          # 7) Unit Tests + Coverage + JUnit
          run_step "Pytest + Coverage" "logs/07_pytest.log" \
            pytest -q --junitxml=reports/report.xml --cov=. --cov-report=xml:reports/coverage.xml

          echo "[INFO] ✅ All quality checks passed"
          BASH
        '''
      }

      post {
        always {
          // Do not fail the build if report.xml doesn't exist (e.g., earlier step failed)
          junit allowEmptyResults: true, testResults: 'reports/report.xml'

          // Keep everything as build artifacts
          archiveArtifacts artifacts: 'logs/**,reports/**', allowEmptyArchive: true
        }
      }
    }
  }
}
