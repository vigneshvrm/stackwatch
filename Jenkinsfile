pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'DEPLOY_TO_PROD',
            defaultValue: false,
            description: 'Promote this build to production?'
        )
    }

    environment {
        APP_NAME = 'stackwatch'
        TEST_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git"
        PROD_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch-prod.git"
        CRED_ID = 'stackwatch-testing'   // <-- MUST MATCH YOUR JENKINS CREDENTIAL ID
    }

    stages {

        /* -------------------------------
         *  CHECKOUT
         * ------------------------------- */
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        /* -------------------------------
         *  NODE MODULE INSTALL
         * ------------------------------- */
        stage('Install dependencies') {
            steps {
                sh 'npm ci || npm install'
            }
        }

        /* -------------------------------
         *  FRONTEND BUILD
         * ------------------------------- */
        stage('Build frontend') {
            steps {
                sh 'npm run build'
            }
        }

        /* -------------------------------
         *  CREATE PREBUILT PACKAGE
         * ------------------------------- */
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

        /* -------------------------------
         *  ARCHIVE ARTIFACT FOR DOWNLOAD
         * ------------------------------- */
        stage('Archive package') {
            steps {
                archiveArtifacts artifacts: 'stackwatch-prebuilt-*.tar.gz', fingerprint: true
            }
        }

        /* -------------------------------
         *  CREATE TEST TAG IN GITLAB
         * ------------------------------- */
        stage('Create Test Tag') {
            steps {
                sh '''
                    VERSION=$(jq -r '.version' package.json)
                    DATE=$(date +%Y%m%d-%H%M%S)
                    TEST_TAG="test-${VERSION}-${DATE}"

                    echo "${TEST_TAG}" > test_tag.txt

                    git config user.name "jenkins"
                    git config user.email "jenkins@stackwatch"

                    git tag -a "${TEST_TAG}" -m "Test build ${TEST_TAG}"
                    git push origin "${TEST_TAG}"
                '''
            }
        }

        /* -------------------------------
         *  PROMOTE ARTIFACT TO PRODUCTION
         * ------------------------------- */
        stage('Promote to Production') {
            when { expression { params.DEPLOY_TO_PROD == true } }

            steps {
                sshagent(credentials: ["${CRED_ID}"]) {

                    sh '''
                        echo "== Locating artifact inside Jenkins =="

                        # 1. GET EXACT ARTIFACT NAME FROM BUILD PAGE (since wildcard won't work)
                        ARTIFACT=$(curl -s "$BUILD_URL/artifact/" \
                            | grep -oP 'stackwatch-prebuilt-[^"]+\\.tar\\.gz' \
                            | head -n1)

                        if [ -z "$ARTIFACT" ]; then
                            echo "ERROR: Artifact not found in Jenkins!"
                            exit 1
                        fi

                        echo "Found artifact name: $ARTIFACT"

                        # 2. DOWNLOAD EXACT ARTIFACT
                        echo "Downloading artifact..."
                        curl -L -o latest.tar.gz "$BUILD_URL/artifact/$ARTIFACT"

                        if [ ! -f latest.tar.gz ]; then
                            echo "ERROR: Artifact download failed!"
                            exit 1
                        fi

                        TEST_TAG=$(cat test_tag.txt)

                        echo "Promoting artifact: latest.tar.gz"
                        echo "Using test tag: $TEST_TAG"

                        chmod +x scripts/promote-to-prod.sh

                        # Run promotion script
                        ./scripts/promote-to-prod.sh "${PROD_REPO_SSH}" latest.tar.gz "$TEST_TAG"
                    '''
                }
            }
        }

    }  // end stages

    post {
        success {
            echo "Pipeline completed successfully"
        }
        failure {
            echo "Pipeline failed"
        }
    }
}
