// ReadAloud CI/CD pipeline (declarative). Lives in the DevOps repo and builds
// the app repo, which it checks out into ./app.
// Stages 1-5 of the course list: Lint, Test, SAST, Security, Build + push.
// Deploy (Helm), Verify (Newman) and Monitor come next.
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 60, unit: 'MINUTES')
  }

  parameters {
    string(name: 'APP_REPO', defaultValue: 'https://github.com/Matan-Abir/readaloud-app.git',
           description: 'App repository to build')
    string(name: 'APP_BRANCH', defaultValue: 'master', description: 'App branch to build')
    booleanParam(name: 'PUSH_IMAGES', defaultValue: false,
                 description: 'Push images to GHCR (needs the ghcr credential with a real token)')
  }

  environment {
    REGISTRY = 'ghcr.io/matan-abir'
  }

  stages {
    stage('Checkout') {
      steps {
        dir('app') {
          git url: params.APP_REPO, branch: params.APP_BRANCH
        }
        script {
          env.IMAGE_TAG = sh(script: 'git -C app rev-parse --short HEAD', returnStdout: true).trim()
          currentBuild.description = "${params.APP_BRANCH} @ ${env.IMAGE_TAG}"
        }
      }
    }

    stage('1 Lint') {
      parallel {
        stage('flake8') {
          agent { docker { image 'python:3.12.16-slim-trixie'; reuseNode true } }
          steps {
            dir('app/backend') {
              sh 'pip install --quiet --no-cache-dir flake8==7.1.1 && python -m flake8 .'
            }
          }
        }
        stage('Hadolint') {
          agent { docker { image 'hadolint/hadolint:v2.15.1-debian'; args '--entrypoint='; reuseNode true } }
          steps {
            sh 'hadolint app/backend/Dockerfile app/mobile/Dockerfile'
          }
        }
      }
    }

    stage('2 Test') {
      agent { docker { image 'python:3.12.16-slim-trixie'; reuseNode true } }
      steps {
        dir('app/backend') {
          sh '''
            pip install --quiet --no-cache-dir -r requirements-dev.txt
            python -m pytest --junitxml=test-results.xml \
              --cov=app --cov-report=xml:coverage.xml --cov-report=term
          '''
        }
      }
      post {
        always {
          junit 'app/backend/test-results.xml'
          recordCoverage(tools: [[parser: 'COBERTURA', pattern: 'app/backend/coverage.xml']],
                         sourceDirectories: [[path: 'app/backend']])
        }
      }
    }

    stage('3 SAST (SonarQube)') {
      agent {
        docker {
          image 'sonarsource/sonar-scanner-cli:12.3.0.4285_8.1.0'
          // Joins the CI network so http://sonarqube:9000 resolves.
          args '--entrypoint= --network ci'
          reuseNode true
        }
      }
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          dir('app') {
            // qualitygate.wait makes the scanner fail when the quality gate fails.
            sh '''
              sonar-scanner \
                -Dsonar.host.url=http://sonarqube:9000 \
                -Dsonar.token="$SONAR_TOKEN" \
                -Dsonar.qualitygate.wait=true \
                -Dsonar.qualitygate.timeout=300
            '''
          }
        }
      }
    }

    stage('4 Security') {
      parallel {
        stage('GitLeaks') {
          agent { docker { image 'zricethezav/gitleaks:v8.30.1'; args '--entrypoint='; reuseNode true } }
          steps {
            sh 'gitleaks detect --source app --redact --verbose'
          }
        }
        stage('Trivy (dependencies)') {
          agent {
            docker {
              image 'aquasec/trivy:0.76.1'
              // Docker socket for image scans; the vulnerability DB is cached in a volume.
              args '--entrypoint= -v trivy-cache:/root/.cache -v /var/run/docker.sock:/var/run/docker.sock'
              reuseNode true
            }
          }
          steps {
            sh 'trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress app'
          }
        }
      }
    }

    stage('5 Build + push') {
      stages {
        stage('Build images') {
          steps {
            sh '''
              docker build -t "$REGISTRY/readaloud-backend:$IMAGE_TAG" app/backend
              docker build -t "$REGISTRY/readaloud-web:$IMAGE_TAG" app/mobile
            '''
          }
        }
        stage('Trivy (images)') {
          agent {
            docker {
              image 'aquasec/trivy:0.76.1'
              // Docker socket for image scans; the vulnerability DB is cached in a volume.
              args '--entrypoint= -v trivy-cache:/root/.cache -v /var/run/docker.sock:/var/run/docker.sock'
              reuseNode true
            }
          }
          steps {
            sh '''
              for name in readaloud-backend readaloud-web; do
                trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress \
                  "$REGISTRY/$name:$IMAGE_TAG"
              done
            '''
          }
        }
        stage('Push') {
          when { expression { params.PUSH_IMAGES } }
          steps {
            withCredentials([usernamePassword(credentialsId: 'ghcr',
                usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
              sh '''
                echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
                for name in readaloud-backend readaloud-web; do
                  docker tag "$REGISTRY/$name:$IMAGE_TAG" "$REGISTRY/$name:latest"
                  docker push "$REGISTRY/$name:$IMAGE_TAG"
                  docker push "$REGISTRY/$name:latest"
                done
              '''
            }
          }
        }
      }
    }
  }

  post {
    success {
      echo "Images: $REGISTRY/readaloud-backend:$IMAGE_TAG and $REGISTRY/readaloud-web:$IMAGE_TAG"
    }
    always {
      sh 'docker logout ghcr.io || true'
    }
  }
}
