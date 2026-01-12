pipeline {
    agent any

    parameters {
        choice(
            name: 'RELEASE_TYPE',
            choices: ['beta', 'latest'],
            description: 'beta = Build from source (new untested), latest = Promote current beta to latest (no rebuild)'
        )
    }

    environment {
        APP_NAME = 'stackwatch'
        ARTIFACT_SERVER = 'artifact.stackwatch.io'
        ARTIFACT_USER = 'deploy'
        ARTIFACT_BASE_PATH = '/var/www/artifacts/stackwatch/build'
        GITLAB_REPO = 'ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git'
        CRED_ID = 'stackwatch-deploy'
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    // Get current date for folder structure
                    env.BUILD_YEAR = sh(script: 'date +%Y', returnStdout: true).trim()
                    env.BUILD_MONTH = sh(script: 'date +%m', returnStdout: true).trim()
                    env.BUILD_DATE = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    env.YEAR_MONTH_PATH = "${env.ARTIFACT_BASE_PATH}/${env.BUILD_YEAR}/${env.BUILD_MONTH}"

                    echo "=========================================="
                    echo "Release Type: ${params.RELEASE_TYPE}"
                    echo "Year/Month: ${env.BUILD_YEAR}/${env.BUILD_MONTH}"
                    echo "=========================================="
                }
            }
        }

        //=====================================================
        // BETA: Build from source and deploy to beta folder
        //=====================================================
        stage('Checkout') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                checkout scm
                script {
                    // Get version from package.json
                    env.APP_VERSION = sh(script: "jq -r '.version' package.json", returnStdout: true).trim()
                    env.FINAL_VERSION = "${env.APP_VERSION}-${env.BUILD_DATE}"
                    echo "Building version: ${env.FINAL_VERSION}"
                }
            }
        }

        stage('Install Dependencies') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                sh 'npm ci || npm install'
            }
        }

        stage('Build Frontend') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                sh 'npm run build'
            }
        }

        stage('Create Package') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                sh '''
                    echo "Creating build package..."

                    # Clean old artifacts
                    rm -f stackwatch-*.tar.gz || true

                    # Create package
                    chmod +x scripts/create-prebuilt-package.sh
                    VERSION="${FINAL_VERSION}" ./scripts/create-prebuilt-package.sh

                    # Rename to standard format
                    PACKAGE_FILE=$(ls stackwatch-*.tar.gz | head -n1)
                    if [ "$PACKAGE_FILE" != "stackwatch-${FINAL_VERSION}.tar.gz" ]; then
                        mv "$PACKAGE_FILE" "stackwatch-${FINAL_VERSION}.tar.gz"
                    fi

                    echo "Package created: stackwatch-${FINAL_VERSION}.tar.gz"
                '''
            }
        }

        stage('Archive Artifact') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                archiveArtifacts artifacts: "stackwatch-${FINAL_VERSION}.tar.gz", fingerprint: true
            }
        }

        stage('Deploy Beta') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                sshagent(credentials: ["${CRED_ID}"]) {
                    sh '''
                        echo "=========================================="
                        echo "Deploying BETA build to Artifact Server"
                        echo "=========================================="

                        TARGET_PATH="${YEAR_MONTH_PATH}/beta"

                        # Create directory
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "mkdir -p ${TARGET_PATH}"

                        # Upload package
                        echo "Uploading package..."
                        scp -o StrictHostKeyChecking=no stackwatch-${FINAL_VERSION}.tar.gz ${ARTIFACT_USER}@${ARTIFACT_SERVER}:${TARGET_PATH}/

                        # Create metadata JSON locally first
                        echo "{\"version\": \"${FINAL_VERSION}\", \"release_type\": \"beta\", \"build_date\": \"${BUILD_DATE}\", \"year\": \"${BUILD_YEAR}\", \"month\": \"${BUILD_MONTH}\"}" > metadata.json
                        echo "${FINAL_VERSION}" > version.txt
                        echo "${BUILD_DATE}" > build-date.txt

                        # Create symlink and upload metadata
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "
                            cd ${TARGET_PATH}
                            rm -f stackwatch-beta.tar.gz
                            ln -sf stackwatch-${FINAL_VERSION}.tar.gz stackwatch-beta.tar.gz
                        "

                        # Upload metadata files
                        scp -o StrictHostKeyChecking=no metadata.json version.txt build-date.txt ${ARTIFACT_USER}@${ARTIFACT_SERVER}:${TARGET_PATH}/

                        echo "Beta deployment complete!"

                        echo ""
                        echo "Beta Download URL: https://${ARTIFACT_SERVER}/stackwatch/build/${BUILD_YEAR}/${BUILD_MONTH}/beta/stackwatch-beta.tar.gz"
                    '''
                }
            }
        }

        //=====================================================
        // LATEST: Promote current beta to latest (no rebuild)
        //=====================================================
        stage('Promote Beta to Latest') {
            when {
                expression { params.RELEASE_TYPE == 'latest' }
            }
            steps {
                sshagent(credentials: ["${CRED_ID}"]) {
                    sh '''
                        echo "=========================================="
                        echo "Promoting BETA to LATEST"
                        echo "=========================================="

                        BETA_PATH="${YEAR_MONTH_PATH}/beta"
                        LATEST_PATH="${YEAR_MONTH_PATH}/latest"
                        ARCHIVE_PATH="${YEAR_MONTH_PATH}/archive"

                        # Check if beta exists
                        echo "Checking for beta version..."
                        BETA_EXISTS=$(ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "test -f ${BETA_PATH}/stackwatch-beta.tar.gz && echo 'yes' || echo 'no'")

                        if [ "${BETA_EXISTS}" != "yes" ]; then
                            echo "ERROR: No beta version found at ${BETA_PATH}/"
                            echo "Please run a beta build first before promoting to latest."
                            exit 1
                        fi

                        # Get beta version
                        BETA_VERSION=$(ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "cat ${BETA_PATH}/version.txt 2>/dev/null || echo 'unknown'")
                        echo "Beta version to promote: ${BETA_VERSION}"

                        # Create directories
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "mkdir -p ${LATEST_PATH} ${ARCHIVE_PATH}"

                        # Archive current latest if exists
                        echo "Checking for existing latest version..."
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} '
                            LATEST_PATH="'"${LATEST_PATH}"'"
                            ARCHIVE_PATH="'"${ARCHIVE_PATH}"'"

                            if [ -f "${LATEST_PATH}/stackwatch-latest.tar.gz" ]; then
                                OLD_VERSION=$(cat "${LATEST_PATH}/version.txt" 2>/dev/null || echo "unknown")
                                ACTUAL_FILE=$(readlink -f "${LATEST_PATH}/stackwatch-latest.tar.gz")

                                if [ -f "${ACTUAL_FILE}" ]; then
                                    echo "Archiving current latest: ${OLD_VERSION}"
                                    cp "${ACTUAL_FILE}" "${ARCHIVE_PATH}/stackwatch-${OLD_VERSION}.tar.gz"
                                    echo "Archived to: ${ARCHIVE_PATH}/stackwatch-${OLD_VERSION}.tar.gz"
                                fi
                            else
                                echo "No existing latest version to archive"
                            fi
                        '

                        # Copy beta to latest
                        echo "Copying beta to latest..."
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} '
                            BETA_PATH="'"${BETA_PATH}"'"
                            LATEST_PATH="'"${LATEST_PATH}"'"
                            BETA_VERSION="'"${BETA_VERSION}"'"

                            # Get actual beta file
                            BETA_FILE=$(readlink -f "${BETA_PATH}/stackwatch-beta.tar.gz")

                            # Copy to latest
                            cp "${BETA_FILE}" "${LATEST_PATH}/stackwatch-${BETA_VERSION}.tar.gz"

                            # Update symlink
                            cd "${LATEST_PATH}"
                            rm -f stackwatch-latest.tar.gz
                            ln -sf "stackwatch-${BETA_VERSION}.tar.gz" stackwatch-latest.tar.gz

                            # Copy metadata and update release_type
                            cp "${BETA_PATH}/version.txt" "${LATEST_PATH}/version.txt"
                            cp "${BETA_PATH}/build-date.txt" "${LATEST_PATH}/build-date.txt"
                            sed "s/\"release_type\": \"beta\"/\"release_type\": \"latest\"/" "${BETA_PATH}/metadata.json" > "${LATEST_PATH}/metadata.json"

                            echo "Promotion complete!"
                        '

                        echo ""
                        echo "=========================================="
                        echo "SUCCESS: Beta ${BETA_VERSION} promoted to Latest"
                        echo "=========================================="
                        echo "Latest Download URL: https://${ARTIFACT_SERVER}/stackwatch/build/${BUILD_YEAR}/${BUILD_MONTH}/latest/stackwatch-latest.tar.gz"
                    '''
                }
            }
        }

        stage('Git Tag') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                sh '''
                    git config user.name "jenkins"
                    git config user.email "jenkins@stackwatch"

                    TAG_NAME="beta-${FINAL_VERSION}"

                    git tag -a "${TAG_NAME}" -m "Beta release ${TAG_NAME}"
                    git push origin "${TAG_NAME}" || echo "Tag push failed (may already exist)"
                '''
            }
        }
    }

    post {
        success {
            script {
                if (params.RELEASE_TYPE == 'beta') {
                    echo """
========================================
BETA BUILD SUCCESSFUL
========================================
Version: ${env.FINAL_VERSION}
Download: https://${env.ARTIFACT_SERVER}/stackwatch/build/${env.BUILD_YEAR}/${env.BUILD_MONTH}/beta/stackwatch-beta.tar.gz

Next step: Test this beta, then run pipeline with 'latest' to promote
========================================
                    """
                } else {
                    echo """
========================================
PROMOTION SUCCESSFUL
========================================
Beta has been promoted to Latest
Download: https://${env.ARTIFACT_SERVER}/stackwatch/build/${env.BUILD_YEAR}/${env.BUILD_MONTH}/latest/stackwatch-latest.tar.gz
========================================
                    """
                }
            }
        }
        failure {
            echo "Pipeline FAILED - Check logs for details"
        }
        always {
            cleanWs()
        }
    }
}
