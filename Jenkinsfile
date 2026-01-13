pipeline {
    agent any

    parameters {
        choice(
            name: 'RELEASE_TYPE',
            choices: ['beta', 'latest'],
            description: 'beta = Build from source (new untested), latest = Promote selected beta to latest (no rebuild)'
        )
        string(
            name: 'BETA_VERSION_TO_PROMOTE',
            defaultValue: '',
            description: 'For LATEST only: Specify beta version to promote (e.g., 1.0.0-20260113-143022). Leave empty to see available versions.'
        )
        booleanParam(
            name: 'LIST_AVAILABLE_BETAS',
            defaultValue: false,
            description: 'List all available beta versions without promoting'
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

                        # Upload versioned package (keeps all beta versions)
                        echo "Uploading versioned package..."
                        scp -o StrictHostKeyChecking=no stackwatch-${FINAL_VERSION}.tar.gz ${ARTIFACT_USER}@${ARTIFACT_SERVER}:${TARGET_PATH}/

                        # Create metadata JSON for this version
                        cat > metadata-${FINAL_VERSION}.json << METADATA_EOF
{"version": "${FINAL_VERSION}", "release_type": "beta", "build_date": "${BUILD_DATE}", "year": "${BUILD_YEAR}", "month": "${BUILD_MONTH}", "status": "untested"}
METADATA_EOF

                        # Upload version-specific metadata
                        scp -o StrictHostKeyChecking=no metadata-${FINAL_VERSION}.json ${ARTIFACT_USER}@${ARTIFACT_SERVER}:${TARGET_PATH}/

                        # Update latest beta symlink (points to most recent build)
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "
                            cd ${TARGET_PATH}
                            rm -f stackwatch-beta.tar.gz
                            ln -sf stackwatch-${FINAL_VERSION}.tar.gz stackwatch-beta.tar.gz
                            echo '${FINAL_VERSION}' > latest-beta-version.txt
                        "

                        echo ""
                        echo "=========================================="
                        echo "Beta deployment complete!"
                        echo "=========================================="
                        echo "Version: ${FINAL_VERSION}"
                        echo ""
                        echo "Download URLs:"
                        echo "  Specific: https://${ARTIFACT_SERVER}/stackwatch/build/${BUILD_YEAR}/${BUILD_MONTH}/beta/stackwatch-${FINAL_VERSION}.tar.gz"
                        echo "  Latest:   https://${ARTIFACT_SERVER}/stackwatch/build/${BUILD_YEAR}/${BUILD_MONTH}/beta/stackwatch-beta.tar.gz"
                        echo ""
                        echo "To promote this version to latest, run pipeline with:"
                        echo "  RELEASE_TYPE=latest"
                        echo "  BETA_VERSION_TO_PROMOTE=${FINAL_VERSION}"
                    '''
                }
            }
        }

        //=====================================================
        // LATEST: List available betas or promote selected version
        //=====================================================
        stage('List Available Betas') {
            when {
                expression { params.RELEASE_TYPE == 'latest' && (params.LIST_AVAILABLE_BETAS || params.BETA_VERSION_TO_PROMOTE == '') }
            }
            steps {
                sshagent(credentials: ["${CRED_ID}"]) {
                    sh '''
                        echo "=========================================="
                        echo "Available Beta Versions"
                        echo "=========================================="

                        BETA_PATH="${YEAR_MONTH_PATH}/beta"

                        # List all beta versions
                        echo ""
                        echo "Beta versions in ${BUILD_YEAR}/${BUILD_MONTH}:"
                        echo "-------------------------------------------"

                        VERSIONS=$(ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "
                            cd ${BETA_PATH} 2>/dev/null || exit 0
                            ls -1t stackwatch-*.tar.gz 2>/dev/null | grep -v 'stackwatch-beta.tar.gz' | sed 's/stackwatch-//;s/.tar.gz//' || echo 'No versions found'
                        ")

                        if [ -z "${VERSIONS}" ] || [ "${VERSIONS}" = "No versions found" ]; then
                            echo "No beta versions found!"
                            echo "Please run a beta build first."
                            exit 1
                        fi

                        echo "${VERSIONS}" | while read version; do
                            # Get metadata for each version
                            META=$(ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "cat ${BETA_PATH}/metadata-${version}.json 2>/dev/null || echo '{}'")
                            STATUS=$(echo "${META}" | grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
                            echo "  - ${version} [${STATUS}]"
                        done

                        echo ""
                        echo "-------------------------------------------"
                        echo "To promote a specific version, run pipeline with:"
                        echo "  RELEASE_TYPE=latest"
                        echo "  BETA_VERSION_TO_PROMOTE=<version>"
                        echo "=========================================="
                    '''
                }
                script {
                    if (params.LIST_AVAILABLE_BETAS) {
                        currentBuild.result = 'SUCCESS'
                        currentBuild.description = 'Listed available beta versions'
                    } else {
                        error("No BETA_VERSION_TO_PROMOTE specified. See available versions above.")
                    }
                }
            }
        }

        stage('Promote Beta to Latest') {
            when {
                expression { params.RELEASE_TYPE == 'latest' && !params.LIST_AVAILABLE_BETAS && params.BETA_VERSION_TO_PROMOTE != '' }
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
                        SELECTED_VERSION="${BETA_VERSION_TO_PROMOTE}"

                        echo "Selected version to promote: ${SELECTED_VERSION}"

                        # Check if selected beta version exists
                        echo "Checking for beta version..."
                        BETA_EXISTS=$(ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "test -f ${BETA_PATH}/stackwatch-${SELECTED_VERSION}.tar.gz && echo 'yes' || echo 'no'")

                        if [ "${BETA_EXISTS}" != "yes" ]; then
                            echo "ERROR: Beta version ${SELECTED_VERSION} not found!"
                            echo ""
                            echo "Available versions:"
                            ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} "
                                cd ${BETA_PATH} 2>/dev/null || exit 0
                                ls -1t stackwatch-*.tar.gz 2>/dev/null | grep -v 'stackwatch-beta.tar.gz' | sed 's/stackwatch-//;s/.tar.gz//'
                            "
                            exit 1
                        fi

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

                        # Copy selected beta to latest
                        echo "Promoting ${SELECTED_VERSION} to latest..."
                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} '
                            BETA_PATH="'"${BETA_PATH}"'"
                            LATEST_PATH="'"${LATEST_PATH}"'"
                            SELECTED_VERSION="'"${SELECTED_VERSION}"'"

                            # Copy versioned file to latest
                            cp "${BETA_PATH}/stackwatch-${SELECTED_VERSION}.tar.gz" "${LATEST_PATH}/stackwatch-${SELECTED_VERSION}.tar.gz"

                            # Update symlink
                            cd "${LATEST_PATH}"
                            rm -f stackwatch-latest.tar.gz
                            ln -sf "stackwatch-${SELECTED_VERSION}.tar.gz" stackwatch-latest.tar.gz

                            # Update version info
                            echo "${SELECTED_VERSION}" > version.txt

                            # Copy and update metadata
                            if [ -f "${BETA_PATH}/metadata-${SELECTED_VERSION}.json" ]; then
                                sed "s/\"release_type\": \"beta\"/\"release_type\": \"latest\"/;s/\"status\": \"untested\"/\"status\": \"promoted\"/" \
                                    "${BETA_PATH}/metadata-${SELECTED_VERSION}.json" > "${LATEST_PATH}/metadata.json"
                            fi

                            # Mark beta as promoted
                            if [ -f "${BETA_PATH}/metadata-${SELECTED_VERSION}.json" ]; then
                                sed -i "s/\"status\": \"untested\"/\"status\": \"promoted\"/" "${BETA_PATH}/metadata-${SELECTED_VERSION}.json"
                            fi

                            echo "Promotion complete!"
                        '

                        echo ""
                        echo "=========================================="
                        echo "SUCCESS: Beta ${SELECTED_VERSION} promoted to Latest"
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

        stage('Cleanup Old Betas') {
            when {
                expression { params.RELEASE_TYPE == 'beta' }
            }
            steps {
                sshagent(credentials: ["${CRED_ID}"]) {
                    sh '''
                        echo "Cleaning up old beta versions (keeping last 5)..."

                        BETA_PATH="${YEAR_MONTH_PATH}/beta"

                        ssh -o StrictHostKeyChecking=no ${ARTIFACT_USER}@${ARTIFACT_SERVER} '
                            BETA_PATH="'"${BETA_PATH}"'"
                            cd "${BETA_PATH}" 2>/dev/null || exit 0

                            # Get list of versioned files (excluding symlink), sorted by date (newest first)
                            FILES=$(ls -1t stackwatch-*.tar.gz 2>/dev/null | grep -v "stackwatch-beta.tar.gz" || true)
                            COUNT=$(echo "${FILES}" | grep -c . || echo 0)

                            if [ "${COUNT}" -gt 5 ]; then
                                echo "Found ${COUNT} beta versions, removing old ones..."
                                # Keep first 5, delete the rest
                                echo "${FILES}" | tail -n +6 | while read file; do
                                    VERSION=$(echo "${file}" | sed "s/stackwatch-//;s/.tar.gz//")
                                    echo "  Removing old beta: ${VERSION}"
                                    rm -f "${file}"
                                    rm -f "metadata-${VERSION}.json"
                                done
                            else
                                echo "Only ${COUNT} beta versions, no cleanup needed"
                            fi
                        '
                    '''
                }
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
Download URLs:
  Specific: https://${env.ARTIFACT_SERVER}/stackwatch/build/${env.BUILD_YEAR}/${env.BUILD_MONTH}/beta/stackwatch-${env.FINAL_VERSION}.tar.gz
  Latest:   https://${env.ARTIFACT_SERVER}/stackwatch/build/${env.BUILD_YEAR}/${env.BUILD_MONTH}/beta/stackwatch-beta.tar.gz

To promote this version:
  RELEASE_TYPE=latest
  BETA_VERSION_TO_PROMOTE=${env.FINAL_VERSION}
========================================
                    """
                } else if (params.LIST_AVAILABLE_BETAS) {
                    echo "Listed available beta versions"
                } else {
                    echo """
========================================
PROMOTION SUCCESSFUL
========================================
Version ${params.BETA_VERSION_TO_PROMOTE} promoted to Latest
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
