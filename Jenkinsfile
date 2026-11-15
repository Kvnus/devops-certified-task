pipeline {
    agent any   // built-in agent; tools are preinstalled in the jenkins/ image

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(name: 'DESTROY', defaultValue: false,
                     description: 'Destroy the infrastructure instead of deploying')
    }

    environment {
        TF_DIR            = "${WORKSPACE}/terraform"
        TF_IN_AUTOMATION  = 'true'
        ANSIBLE_FORCE_COLOR = 'true'
        IMAGE_TAG         = "${env.BUILD_NUMBER}"
        // terraform.tfvars is gitignored, so it is read from the project mounted at /project
        // key paths inside the container are fixed by the mounts in jenkins/docker-compose.yml
        // and passed to terraform with -var, so tfvars may name the keys differently
        TFVARS_FILE       = "${env.TFVARS_FILE ?: '/project/terraform/terraform.tfvars'}"
    }

    stages {
        stage('Prepare sources') {
            // Copy the project folder into the workspace. Terraform state and plugins
            // (terraform/.terraform, *.tfstate*) stay in the workspace between builds.
            steps {
                sh '''
                    tar -C /project \
                        --exclude='./.git' --exclude='./jenkins' --exclude='./docs' --exclude='./target' \
                        --exclude='./terraform/.terraform' --exclude='./terraform/.terraform.lock.hcl' \
                        --exclude='./terraform/*.tfstate*' \
                        -cf - . | tar -C "$WORKSPACE" -xf -
                '''
            }
        }

        stage('Terraform: init & validate') {
            steps {
                dir('terraform') {
                    sh 'terraform init -input=false && terraform validate'
                }
            }
        }

        stage('Terraform: apply') {
            when { expression { !params.DESTROY } }
            steps {
                dir('terraform') {
                    sh '''
                        terraform apply -input=false -auto-approve -var-file="$TFVARS_FILE" \\
                          -var "sa_key_file=$HOME/.yc/key.json" \\
                          -var "ssh_public_key_path=$HOME/.ssh/id_ed25519.pub" \\
                          -var "ssh_private_key_path=$HOME/.ssh/id_ed25519"
                        terraform output -json > "$WORKSPACE/tf-output.json"
                    '''
                }
            }
        }

        stage('Ansible: inventory') {
            when { expression { !params.DESTROY } }
            steps {
                sh '''
                    out=tf-output.json
                    cat > ansible/inventory/hosts.ini <<INV
[build]
build-vm ansible_host=$(jq -r .build_public_ip.value $out)

[stage]
stage-vm ansible_host=$(jq -r .stage_public_ip.value $out)

[all:vars]
ansible_user=$(jq -r .ssh_user.value $out)
ansible_ssh_private_key_file=$HOME/.ssh/id_ed25519
INV
                    jq -r '"registry_repo: " + .registry_repo.value, "app_port: " + (.app_port.value|tostring)' $out \
                      > ansible/extra_vars.yml
                    echo "image_tag: \\"$IMAGE_TAG\\"" >> ansible/extra_vars.yml
                    echo "project_dir: $WORKSPACE" >> ansible/extra_vars.yml
                '''
            }
        }

        stage('Ansible: build image') {
            when { expression { !params.DESTROY } }
            steps {
                dir('ansible') {
                    sh 'ansible-playbook build.yml -e @extra_vars.yml'
                }
            }
        }

        stage('Ansible: deploy to stage') {
            when { expression { !params.DESTROY } }
            steps {
                dir('ansible') {
                    sh 'ansible-playbook deploy.yml -e @extra_vars.yml'
                }
            }
        }

        stage('Smoke test') {
            when { expression { !params.DESTROY } }
            steps {
                sh 'curl -sf --retry 5 --retry-delay 3 "$(jq -r .app_url.value tf-output.json)"'
            }
        }

        stage('Terraform: destroy') {
            when { expression { params.DESTROY } }
            steps {
                dir('terraform') {
                    sh '''
                        terraform destroy -input=false -auto-approve -var-file="$TFVARS_FILE" \\
                          -var "sa_key_file=$HOME/.yc/key.json" \\
                          -var "ssh_public_key_path=$HOME/.ssh/id_ed25519.pub" \\
                          -var "ssh_private_key_path=$HOME/.ssh/id_ed25519"
                    '''
                }
            }
        }
    }

    post {
        success { script { if (!params.DESTROY) echo "Stage: ${sh(script: 'jq -r .app_url.value tf-output.json', returnStdout: true).trim()}" } }
        always  { sh 'rm -f ansible/inventory/hosts.ini ansible/extra_vars.yml' }
    }
}
