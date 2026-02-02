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
          [ -f requirement.txt ] && pip install -r requirements.txt || true
          [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || t
          # IMPORTANT: install your repo as a package
          pip install -e .
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
    stage('Lint Code') {
      steps {
        sh '''
          set -eux
          . .venv/bin/activate
          echo "Running Ruff Linting..."
          python -m ruff --version
          python -m ruff check
          ruff check .
    '''
  }
  }
    
  }
}
