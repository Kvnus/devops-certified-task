#cloud-config
# Shared cloud-init template: installs Docker and helper scripts.
package_update: true
packages:
  - docker.io
  - jq
  - curl
%{ for p in extra_packages ~}
  - ${p}
%{ endfor ~}

write_files:
  # Logs Docker in to Yandex Container Registry using the IAM token of the
  # service account attached to this VM (no secrets are stored anywhere).
  - path: /usr/local/bin/yc-registry-login
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail
      TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
        http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
      echo "$TOKEN" | docker login --username iam --password-stdin cr.yandex

runcmd:
  - systemctl enable --now docker
