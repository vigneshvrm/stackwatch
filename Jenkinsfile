pipeline {
  agent any

  parameters {
    booleanParam(name: 'DEPLOY_TO_PROD', defaultValue: false, description: 'If true, promote this build to production')
  }

  environment {
    APP_NAME = 'stackwatch'
    TEST_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git"
    PROD_REPO_SSH = "ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch-prod.git"
    CRED_ID = 'gitlab-stackwatch'   // Jenkins SSH credential ID
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Install dependencies') {
      steps {
        sh 'npm ci || npm install'
      }
    }

    stage('Build') {
      steps {
        sh 'npm run build'
      }
    }

    stage('Create package') {
      steps {
        sh '''
          echo "Cleaning old artifacts..."
          rm -f stackwatch-prebuilt-*.tar.gz || true

          chmod +x scripts/create-prebuilt-package.sh
          ./scripts/create-prebuilt-package.sh
        '''
      }
    }

    stage('Archive') {
      steps {
        archiveArtifacts artifacts: 'stackwatch-prebuilt-*.tar.gz', fingerprint: true
      }
    }

    stage('Tag test build') {
      steps {
        sh '''
          VERSION=$(jq -r '.version' package.json)
          DATE=$(date +%Y%m%d-%H%M%S)
          TEST_TAG="test-${VERSION}-${DATE}"
          echo "TEST_TAG=${TEST_TAG}" > test_tag.env

          git config user.name "jenkins"
          git config user.email "jenkins@stackwatch"

          git tag -a "${TEST_TAG}" -m "Automated test build ${TEST_TAG}"
          git push origin "${TEST_TAG}"
        '''
        // Save tag for later stages
        script {
          env.TEST_TAG = readFile('test_tag.env').trim().split('=')[1]
        }
      }
    }

    stage('Promote to production') {
      when { expression { return params.DEPLOY_TO_PROD == true } }
      steps {
        sshagent(credentials: [env.CRED_ID]) {
          sh '''
            # find artifact name (the only stackwatch-prebuilt-*.tar.gz in workspace)
            ART=$(ls -1 stackwatch-prebuilt-*.tar.gz | head -n1)
            echo "Artifact: $ART"

            # generate checksum and run promotion script (will clone prod and push)
            ./scripts/promote-to-prod.sh "${PROD_REPO_SSH}" "$ART" "${TEST_TAG}"
          '''
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline success"
    }
    failure {
      echo "Pipeline failed"
    }
  }
}
