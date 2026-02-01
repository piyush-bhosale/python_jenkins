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
          [ -f requirement.txt ] && pip install -r requirement.txt || true
          [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || t
        '''
      }
    }

    stage('Run Tests') {
      steps {
        sh '''
          set -eux
          . .venv/bin/activate
          pytest -q
        '''
      }
    }
  }
}
