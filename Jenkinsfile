pipeline {
    agent any

    environment {
        // just for clarity; you can reuse later
        APP_NAME = 'stackwatch'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install dependencies') {
            steps {
                sh '''
                  npm ci || npm install
                '''
            }
        }

        stage('Build frontend') {
            steps {
                sh '''
                  npm run build
                '''
            }
        }

        stage('Create prebuilt package') {
            steps {
                sh '''
                  # ensure script is executable
                  chmod +x scripts/create-prebuilt-package.sh

                  # run your existing packaging script
                  ./scripts/create-prebuilt-package.sh
                '''
            }
        }

        stage('Archive package artifact') {
            steps {
                // archive any prebuilt tarballs from your script
                archiveArtifacts artifacts: 'stackwatch-prebuilt-*.tar.gz', fingerprint: true
            }
        }
    }
}
