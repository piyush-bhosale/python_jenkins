pipeline {
    agent { label 'myagent' }

    options {
        timestamps()
        skipDefaultCheckout(true)
    }

    environment {
        // Optional: If you store token in Jenkins credentials as Secret Text with ID 'sonarqube-token'
        // This makes $SONAR_TOKEN available in the shell.
        SONAR_TOKEN = credentials('SonarQube2')
    }

    stages {
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
                // This uses the SonarQube server configured in Jenkins: Manage Jenkins -> System -> SonarQube servers
                withSonarQubeEnv('SonarQube') {
                    sh '''#!/usr/bin/env bash
                        set -euxo pipefail

                        # If sonar-scanner is installed via Jenkins tool config, it should be on PATH.
                        # Otherwise, you can call it using tool('SonarScanner') approach.
                        sonar-scanner \
                          -Dsonar.projectKey=python_jenkins \
                          -Dsonar.sources=app \
                          -Dsonar.tests=tests \
                          -Dsonar.python.coverage.reportPaths=coverage.xml \
                          -Dsonar.junit.reportPaths=report.xml \
                          -Dsonar.host.url=http://YOUR-SONARQUBE-IP:9000 \
                          -Dsonar.login=${SONAR_TOKEN}
                        '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'report.xml'
            archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
        }
    }
}
