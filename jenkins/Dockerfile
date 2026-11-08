# syntax=docker/dockerfile:1
# Jenkins controller for the ReadAloud pipeline: Docker CLI (talks to the host's
# Docker through the mounted socket), plugins, and configuration as code, so the
# job and credentials exist on first start with no clicking.
FROM docker:29.9.2-cli AS docker-cli

FROM jenkins/jenkins:2.580.2-lts-jdk21
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /var/jenkins_conf/casc.yaml
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    CASC_JENKINS_CONFIG=/var/jenkins_conf/casc.yaml
