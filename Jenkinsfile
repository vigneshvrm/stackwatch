pipeline {
    agent any

    parameters {
        choice(
            name: 'RELEASE_TYPE',
            choices: ['beta', 'latest'],
            description: 'Select release type: beta (new untested) or latest (tested, stable)'
        )
        string(
            name: 'VERSION_TAG',
            defaultValue: '',
            description: 'Optional: Custom version tag (leave empty for auto-generated)'
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
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Get current date for folder structure
                    env.BUILD_YEAR = sh(script: 'date +%Y', returnStdout: true).trim()
                    env.BUILD_MONTH = sh(script: 'date +%m', returnStdout: true).trim()
                    env.BUILD_DATE = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()

                    // Get version from package.json
                    env.APP_VERSION = sh(script: "jq -r '.version' package.json", returnStdout: true).trim()

                    // Set version tag
                    if (params.VERSION_TAG?.trim()) {
                        env.FINAL_VERSION = params.VERSION_TAG
                    } else {
                        env.FINAL_VERSION = "${env.APP_VERSION}-${env.BUILD_DATE}"
                    }

                    echo "Building version: ${env.FINAL_VERSION}"
                    echo "Release type: ${params.RELEASE_TYPE}"
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci || npm install'
            }
        }

        stage('Build Frontend') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Create Package') {
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
            steps {
                archiveArtifacts artifacts: "stackwatch-${FINAL_VERSION}.tar.gz", fingerprint: true
            }
        }

        stage('Deploy to Artifact Server') {
            steps {
                sshagent(credentials: ["${CRED_ID}"]) {
                    sh '''
                        echo "=========================================="
                        echo "Deploying to Artifact Server"
                        echo "=========================================="
                        echo "Server: ${ARTIFACT_SERVER}"
                        echo "Release Type: ${RELEASE_TYPE}"
                        echo "Version: ${FINAL_VERSION}"
                        echo ""

                        # Define paths
                        YEAR_MONTH_PATH="${ARTIFACT_BASE_PATH}/${BUILD_YEAR}/${BUILD_MONTH}"
                        TARGET_PATH="${YEAR_MONTH_PATH}/${RELEASE_TYPE}"
                        ARCHIVE_PATH="${YEAR_MONTH_PATH}/archive"

                        # Create directories on artifact server
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "
                            mkdir -p ${TARGET_PATH}
                            mkdir -p ${ARCHIVE_PATH}
                        "

                        # If deploying to 'latest', archive the current latest first
                        if [ '${RELEASE_TYPE}' = 'latest' ]; then
                            echo "Archiving current latest version..."
                            ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "
                                if [ -L ${TARGET_PATH}/stackwatch-latest.tar.gz ]; then
                                    # Get the actual file the symlink points to
                                    OLD_FILE=\\$(readlink -f ${TARGET_PATH}/stackwatch-latest.tar.gz)
                                    OLD_VERSION=\\$(cat ${TARGET_PATH}/version.txt 2>/dev/null || echo 'unknown')
                                    if [ -f \\\"\\${OLD_FILE}\\\" ]; then
                                        # Move the actual file to archive
                                        mv \\\"\\${OLD_FILE}\\\" ${ARCHIVE_PATH}/stackwatch-\\${OLD_VERSION}.tar.gz 2>/dev/null || true
                                        # Remove the old symlink
                                        rm -f ${TARGET_PATH}/stackwatch-latest.tar.gz
                                        echo 'Archived previous latest: '\\${OLD_VERSION}
                                    fi
                                fi
                            "
                        fi

                        # Upload new package
                        echo "Uploading package..."
                        scp -o StrictHostKeyChecking=no stackwatch-${FINAL_VERSION}.tar.gz ${ARTIFACT_USER}@${ARTIFACT_SERVER}:${TARGET_PATH}/

                        # Create symlink and version file
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "
                            cd ${TARGET_PATH}

                            # Remove old symlink
                            rm -f stackwatch-${RELEASE_TYPE}.tar.gz

                            # Create new symlink
                            ln -sf stackwatch-${FINAL_VERSION}.tar.gz stackwatch-${RELEASE_TYPE}.tar.gz

                            # Save version info
                            echo '${FINAL_VERSION}' > version.txt
                            echo '${BUILD_DATE}' > build-date.txt

                            # Create metadata JSON
                            cat > metadata.json << EOF
{
    \"version\": \"${FINAL_VERSION}\",
    \"release_type\": \"${RELEASE_TYPE}\",
    \"build_date\": \"${BUILD_DATE}\",
    \"year\": \"${BUILD_YEAR}\",
    \"month\": \"${BUILD_MONTH}\"
}
EOF

                            echo 'Deployment complete!'
                            echo 'Download URL: https://${ARTIFACT_SERVER}/stackwatch/build/${BUILD_YEAR}/${BUILD_MONTH}/${RELEASE_TYPE}/stackwatch-${RELEASE_TYPE}.tar.gz'
                        "
                    '''
                }
            }
        }

        stage('Promote Beta to Latest') {
            when {
                expression { params.RELEASE_TYPE == 'latest' }
            }
            steps {
                echo "This build was deployed directly to 'latest' channel."
                echo "Previous latest has been moved to archive."
            }
        }

        stage('Git Tag') {
            steps {
                sh '''
                    git config user.name "jenkins"
                    git config user.email "jenkins@stackwatch"

                    TAG_NAME="${RELEASE_TYPE}-${FINAL_VERSION}"

                    git tag -a "${TAG_NAME}" -m "Release ${TAG_NAME} - ${RELEASE_TYPE} build"
                    git push origin "${TAG_NAME}" || echo "Tag push failed (may already exist)"
                '''
            }
        }
    }

    post {
        success {
            echo """
========================================
BUILD SUCCESSFUL
========================================
Version: ${FINAL_VERSION}
Release Type: ${RELEASE_TYPE}
Download URL: https://${ARTIFACT_SERVER}/stackwatch/build/${BUILD_YEAR}/${BUILD_MONTH}/${RELEASE_TYPE}/stackwatch-${RELEASE_TYPE}.tar.gz
========================================
            """
        }
        failure {
            echo "Pipeline FAILED - Check logs for details"
        }
        always {
            cleanWs()
        }
    }
}
