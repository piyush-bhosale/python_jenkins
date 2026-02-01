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
                echo "Activating Python virtual environment"
                source /home/jenkins/pyenv/bin/activate

                echo "Installing requirements"
                pip install --upgrade pip
                pip install -r requirement.txt || true
                pip install -r requirements-dev.txt || true

                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                echo "Running unit tests"
                source /home/jenkins/pyenv/bin/activate
                pytest
                '''
            }
        }

        stage('Run App') {
            steps {
                sh '''
                echo "Running Python App"
                source /home/jenkins/pyenv/bin/activate
                python3 app/main.py
                '''
            }
        }
    }
}
