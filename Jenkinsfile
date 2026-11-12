// ReadAloud CI/CD pipeline (declarative). Lives in the DevOps repo and builds
// the app repo, which it checks out into ./app.
// The eight stages of the course list: 1 Lint, 2 Test, 3 SAST, 4 Security,
// 5 Build + push, 6 Deploy (Helm: dev, staging, prod after approval), 7 Verify (health checks
// and Newman API tests), 8 Monitor (Prometheus targets, alerts, Grafana, Loki).
//
// Stages 6-8 talk to the Minikube cluster made by terraform/platform. Jenkins
// runs in Docker next to it, reaches the cluster over Minikube's Docker network
// (named after the profile, "readaloud") and loads the images it just built
// straight into the node, so no registry is needed. Untick DEPLOY to stop
// after stage 5. The shell steps live in scripts/ so they can be run by hand.
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 60, unit: 'MINUTES')
  }

  // Continuous integration: every 2 minutes Jenkins checks both repos (this one
  // and the app repo checked out below) and starts a build when either has a new
  // commit. The trigger is registered on the first run of this Jenkinsfile.
  triggers {
    pollSCM('H/2 * * * *')
  }

  parameters {
    string(name: 'APP_REPO', defaultValue: 'https://github.com/Matan-Abir/readaloud-app.git',
           description: 'App repository to build')
    string(name: 'APP_BRANCH', defaultValue: 'master', description: 'App branch to build')
    booleanParam(name: 'PUSH_IMAGES', defaultValue: false,
                 description: 'Push images to GHCR (needs the ghcr credential with a real token)')
    booleanParam(name: 'DEPLOY', defaultValue: true,
                 description: 'Stages 6-8: deploy to Minikube, run the API tests, check monitoring')
    booleanParam(name: 'PROMOTE_TO_STAGING', defaultValue: true,
                 description: 'After dev passes its tests, deploy the same images to staging')
    booleanParam(name: 'PROMOTE_TO_PROD', defaultValue: false,
                 description: 'After staging passes, ask for approval and deploy to prod (needs terraform workspace prod; ~1.5 GB more memory)')
    booleanParam(name: 'DEPLOY_AWS', defaultValue: true,
                 description: 'After the Minikube stages pass, roll the AWS (k3s) prod release to this commit\'s GHCR images. Skipped when the aws-kubeconfig credential does not exist (docs/CLOUD.md part 8)')
    string(name: 'CLUSTER', defaultValue: 'readaloud', description: 'Minikube profile name')
  }

  environment {
    REGISTRY = 'ghcr.io/matan-abir'
    // Cluster access for stages 6-8, written by scripts/cluster-access.sh.
    KUBECONFIG = "${WORKSPACE}/.kube/config"
    HELM_CACHE_HOME = "${WORKSPACE}/.helm/cache"
    HELM_CONFIG_HOME = "${WORKSPACE}/.helm/config"
    HELM_DATA_HOME = "${WORKSPACE}/.helm/data"
  }

  stages {
    stage('Checkout') {
      steps {
        dir('app') {
          git url: params.APP_REPO, branch: params.APP_BRANCH
        }
        script {
          env.IMAGE_TAG = sh(script: 'git -C app rev-parse --short HEAD', returnStdout: true).trim()
          // GitHub Actions in the app repo tags the GHCR images with the full SHA.
          env.APP_SHA = sh(script: 'git -C app rev-parse HEAD', returnStdout: true).trim()
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

    stage('Cluster access') {
      when { expression { params.DEPLOY } }
      steps {
        sh './scripts/cluster-access.sh'
        script { env.NODE_IP = readFile('.node-ip').trim() }
      }
    }

    stage('6 Deploy: dev') {
      when { expression { params.DEPLOY } }
      agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
      steps {
        withCredentials([string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')]) {
          sh 'DEPLOY_ENV=dev ./scripts/deploy.sh'
        }
      }
    }

    stage('7 Verify: dev') {
      when { expression { params.DEPLOY } }
      stages {
        stage('dev: health checks') {
          agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
          steps {
            sh 'DEPLOY_ENV=dev ./scripts/health-check.sh'
          }
        }
        stage('dev: API tests (Newman)') {
          agent { docker { image 'postman/newman:6.1.3-alpine'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
          steps {
            sh 'DEPLOY_ENV=dev HOSTNAME_UNDER_TEST=readaloud.local ./scripts/api-tests.sh'
          }
          post { always { junit 'newman-dev.xml' } }
        }
      }
    }

    stage('6 Deploy: staging') {
      when { expression { params.DEPLOY && params.PROMOTE_TO_STAGING } }
      agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
      steps {
        withCredentials([string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')]) {
          sh 'DEPLOY_ENV=staging ./scripts/deploy.sh'
        }
      }
    }

    stage('7 Verify: staging') {
      when { expression { params.DEPLOY && params.PROMOTE_TO_STAGING } }
      stages {
        stage('staging: health checks') {
          agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
          steps {
            sh 'DEPLOY_ENV=staging ./scripts/health-check.sh'
          }
        }
        stage('staging: API tests (Newman)') {
          agent { docker { image 'postman/newman:6.1.3-alpine'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
          steps {
            sh 'DEPLOY_ENV=staging HOSTNAME_UNDER_TEST=staging.readaloud.local ./scripts/api-tests.sh'
          }
          post { always { junit 'newman-staging.xml' } }
        }
      }
    }

    stage('6 Deploy: prod') {
      when { expression { params.DEPLOY && params.PROMOTE_TO_STAGING && params.PROMOTE_TO_PROD } }
      stages {
        stage('prod: approval') {
          steps {
            // A person signs off before production; nobody answers in 30 min = abort.
            timeout(time: 30, unit: 'MINUTES') {
              input message: "Deploy ${env.IMAGE_TAG} to prod? It passed dev and staging.", ok: 'Deploy to prod'
            }
          }
        }
        stage('prod: helm upgrade') {
          agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
          steps {
            withCredentials([string(credentialsId: 'gemini-api-key', variable: 'GEMINI_API_KEY')]) {
              sh 'DEPLOY_ENV=prod ./scripts/deploy.sh'
            }
          }
        }
      }
    }

    stage('7 Verify: prod') {
      when { expression { params.DEPLOY && params.PROMOTE_TO_STAGING && params.PROMOTE_TO_PROD } }
      stages {
        stage('prod: health checks') {
          agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
          steps {
            sh 'DEPLOY_ENV=prod ./scripts/health-check.sh'
          }
        }
        stage('prod: API tests (Newman)') {
          agent { docker { image 'postman/newman:6.1.3-alpine'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
          steps {
            sh 'DEPLOY_ENV=prod HOSTNAME_UNDER_TEST=prod.readaloud.local ./scripts/api-tests.sh'
          }
          post { always { junit 'newman-prod.xml' } }
        }
      }
    }

    stage('6 Deploy: AWS') {
      // Continuous deployment to the class demo in AWS. Runs only after every
      // earlier stage passed, so a commit that breaks tests never reaches AWS.
      when { expression { params.DEPLOY_AWS && (params.APP_BRANCH == 'master') } }
      agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args '--entrypoint='; reuseNode true } }
      steps {
        script {
          try {
            withCredentials([file(credentialsId: 'aws-kubeconfig', variable: 'AWS_KUBECONFIG')]) {
              sh 'IMAGE_TAG="$APP_SHA" sh ./scripts/deploy-aws.sh'
            }
          } catch (org.jenkinsci.plugins.credentialsbinding.impl.CredentialNotFoundException e) {
            echo 'No aws-kubeconfig credential in Jenkins: skipping the AWS deploy (docs/CLOUD.md part 8).'
          }
        }
      }
    }

    stage('8 Monitor') {
      when { expression { params.DEPLOY } }
      agent { docker { image 'dtzar/helm-kubectl:4.3.0'; args "--entrypoint= --network ${params.CLUSTER}"; reuseNode true } }
      steps {
        script {
          def envs = 'dev'
          if (params.PROMOTE_TO_STAGING) { envs += ' staging' }
          if (params.PROMOTE_TO_STAGING && params.PROMOTE_TO_PROD) { envs += ' prod' }
          // Exit code 3 = monitoring works but a ReadAloud alert is firing:
          // the build goes yellow (unstable) instead of red.
          def rc = sh(script: "DEPLOY_ENVS='${envs}' ./scripts/monitor-check.sh", returnStatus: true)
          if (rc == 3) {
            unstable('A ReadAloud alert is firing, see the log above')
          } else if (rc != 0) {
            error("Monitoring check failed (exit ${rc})")
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
      sh 'docker logout ghcr.io || true; rm -rf .kube .node-ip'
    }
  }
}
