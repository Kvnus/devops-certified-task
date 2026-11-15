# Local Jenkins with everything the pipeline needs (build context = repo root).
FROM jenkins/jenkins:lts-jdk17

USER root
# Preinstall terraform, ansible, jq, ssh-keygen, tar with the same script the pipeline uses.
COPY scripts/install-tools.sh /tmp/install-tools.sh
RUN /tmp/install-tools.sh && rm -rf /var/lib/apt/lists/* /tmp/install-tools.sh

# Provider mirror for Terraform (Russia)
COPY jenkins/terraformrc /var/jenkins_home/.terraformrc
RUN chown jenkins:jenkins /var/jenkins_home/.terraformrc

USER jenkins
COPY jenkins/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY jenkins/graph-view.groovy /usr/share/jenkins/ref/init.groovy.d/graph-view.groovy
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc/jenkins.yaml \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
