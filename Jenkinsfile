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
          . /home/jenkins/pyenv/bin/activate
          python --version
          pip --version
          pip install -U pip

          # install dependencies if files exist
          [ -f requirement.txt ] && pip install -r requirement.txt || true
          [ -f requirements-dev.txt ] && pip install -r requirements-dev.txt || true
        '''
      }
    }

    stage('Run Tests') {
      steps {
        sh '''
          set -eux
          . /home/jenkins/pyenv/bin/activate
          pytest -q
        '''
      }
    }
  }
}
