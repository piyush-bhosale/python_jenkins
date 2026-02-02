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
        sh '''#!/usr/bin/env bash
set -euo pipefail

rm -rf logs reports || true
mkdir -p logs reports
echo "[INFO] logs/ and reports/ prepared"
'''
      }
    }

    stage('Setup Python') {
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail

{
  echo "[INFO] Creating venv"
  python3 -m venv .venv
  source .venv/bin/activate

  echo "[INFO] Upgrading pip"
  python -m pip install --upgrade pip

  echo "[INFO] Installing runtime deps if present"
  [[ -f requirements.txt ]] && pip install -r requirements.txt || true

  echo "[INFO] Installing dev deps if present"
  [[ -f requirements-dev.txt ]] && pip install -r requirements-dev.txt || true

  echo "[INFO] Installing project (editable)"
  pip install -e .

  echo "[INFO] Setup Python completed"
} > logs/00_setup_python.log 2>&1

echo "[INFO] Setup log saved: logs/00_setup_python.log"
'''
      }
    }

    stage('Python Quality Stack') {
      steps {
        sh '''#!/usr/bin/env bash
set -euo pipefail
source .venv/bin/activate

run_step () {
  local name="$1"
  local logfile="$2"
  shift 2

  echo "[INFO] Running: ${name}"
  "$@" > "${logfile}" 2>&1 || {
    echo "[ERROR] ${name} failed. See ${logfile}"
    exit 1
  }
  echo "[INFO] ${name} OK. Log: ${logfile}"
}

# 1) Ruff Lint
run_step "Ruff Lint" "logs/01_ruff_lint.log" \
  python -m ruff check .

# 2) Ruff Format Check (STRICT)
run_step "Ruff Format Check" "logs/02_ruff_format_check.log" \
  python -m ruff format --check .

# 3) Black Format Check (optional)
run_step "Black Check" "logs/03_black_check.log" \
  python -m black --check .

# 4) Mypy Type Check
run_step "Mypy Type Check" "logs/04_mypy.log" \
  python -m mypy --ignore-missing-imports .

# 5) Bandit (scan only your source folder)
# Your repo earlier showed app/main.py, so app is correct.
run_step "Bandit Scan" "logs/05_bandit.log" \
  python -m bandit -r app -ll -f json -o reports/bandit.json

# 6) pip-audit (dependency vulnerabilities)
run_step "pip-audit Scan" "logs/06_pip_audit.log" \
  python -m pip_audit -f json -o reports/pip_audit.json

# 7) Pytest + coverage + JUnit
run_step "Pytest + Coverage" "logs/07_pytest.log" \
  pytest -q --junitxml=reports/report.xml --cov=. --cov-report=xml:reports/coverage.xml

echo "[INFO] ✅ All quality checks passed"
'''
      }

      post {
        always {
          junit allowEmptyResults: true, testResults: 'reports/report.xml'
          archiveArtifacts artifacts: 'logs/**,reports/**', allowEmptyArchive: true
        }
      }
    }
  }
}
