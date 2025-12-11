pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'DEPLOY_TO_PROD',
            defaultValue: false,
            description: 'Promote this build to PRODUCTION?'
        )
    }

    environment {
        APP_NAME = 'stackwatch'
        TEST_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git"
        PROD_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch-prod.git"
        CRED_ID = 'stackwatch-testing'   // MUST MATCH JENKINS CREDENTIAL ID
    }

    stages {

        /* --------------------- CHECKOUT ---------------------- */
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        /* --------------------- DEPENDENCIES ------------------ */
        stage('Install dependencies') {
            steps {
                sh 'npm ci || npm install'
            }
        }

        /* --------------------- BUILD FRONTEND --------------- */
        stage('Build frontend') {
            steps {
                sh 'npm run build'
            }
        }

        /* --------------------- CREATE PACKAGE ---------------- */
        stage('Create prebuilt package') {
            steps {
                sh '''
                    echo "Cleaning old artifacts..."
                    rm -f stackwatch-prebuilt-*.tar.gz || true
                    chmod +x scripts/create-prebuilt-package.sh
                    ./scripts/create-prebuilt-package.sh
                '''
            }
        }

        /* --------------------- ARCHIVE PACKAGE --------------- */
        stage('Archive package') {
            steps {
                archiveArtifacts artifacts: 'stackwatch-prebuilt-*.tar.gz',
                                 fingerprint: true
            }
        }

        /* --------------------- CREATE TEST TAG --------------- */
        stage('Create Test Tag') {
            steps {
                sh '''
                    VERSION=$(jq -r '.version' package.json)
                    DATE=$(date +%Y%m%d-%H%M%S)
                    TEST_TAG="test-${VERSION}-${DATE}"

                    echo "$TEST_TAG" > test_tag.txt
                    echo "Generated test tag: $TEST_TAG"

                    git config user.name "jenkins"
                    git config user.email "jenkins@stackwatch"

                    git tag -a "$TEST_TAG" -m "Test build $TEST_TAG"
                    git push origin "$TEST_TAG"
                '''
            }
        }

        /* ---------------- PROMOTION TO PRODUCTION ------------ */
        stage('Promote to Production') {
            when { expression { params.DEPLOY_TO_PROD == true } }

            steps {
                sshagent(credentials: ["${CRED_ID}"]) {
                    sh '''
                        echo "== Downloading latest artifact from Jenkins =="
                        curl -L -o latest.tar.gz "$BUILD_URL/artifact/stackwatch-prebuilt-*.tar.gz"

                        TEST_TAG=$(cat test_tag.txt)

                        echo "Using artifact: latest.tar.gz"
                        echo "Using test tag: $TEST_TAG"

                        chmod +x scripts/promote-to-prod.sh
                        ./scripts/promote-to-prod.sh "${PROD_REPO_SSH}" latest.tar.gz "$TEST_TAG"
                    '''
                }
            }
        }
    }

    /* --------------------- FINAL STATUS --------------------- */
    post {
        success {
            echo "Pipeline completed successfully"
        }
        failure {
            echo "Pipeline failed"
        }
    }
}
