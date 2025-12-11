pipeline {
    agent any

    parameters {
        booleanParam(name: 'DEPLOY_TO_PROD', defaultValue: false, description: 'Promote this build to PRODUCTION?')
    }

    environment {
        APP_NAME = 'stackwatch'
        TEST_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git"
        PROD_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch-prod.git"
        CRED_ID = 'stackwatch-testing'
    }

    stages {
        stage('Checkout') { steps { checkout scm } }

        stage('Install dependencies') { steps { sh 'npm ci || npm install' } }

        stage('Build frontend') { steps { sh 'npm run build' } }

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

        stage('Archive package') {
            steps { archiveArtifacts artifacts: 'stackwatch-prebuilt-*.tar.gz', fingerprint: true }
        }

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

        stage('Promote to Production') {
            when { expression { params.DEPLOY_TO_PROD == true } }
            steps {
                sshagent(credentials: ["${CRED_ID}"]) {
                    sh '''
                        echo "== Locate artifact in workspace =="
                        ARTIFACT=$(ls $WORKSPACE/stackwatch-prebuilt-*.tar.gz | head -n1)
                        if [ -z "$ARTIFACT" ]; then
                          echo "ERROR: artifact not found: $WORKSPACE"
                          exit 1
                        fi
                        cp "$ARTIFACT" latest.tar.gz
                        TEST_TAG=$(cat test_tag.txt)
                        echo "Promoting latest.tar.gz using test tag: $TEST_TAG"
                        chmod +x scripts/promote-to-prod.sh
                        ./scripts/promote-to-prod.sh "${PROD_REPO_SSH}" "${WORKSPACE}/latest.tar.gz" "$TEST_TAG"
                    '''
                }
            }
        }
    }

    post {
        success { echo "Pipeline OK" }
        failure { echo "Pipeline FAILED" }
    }
}
