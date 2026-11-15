#!/usr/bin/env bash
# Checks the tools needed by the Jenkins pipeline and installs missing ones.
# Target OS: Ubuntu (20.04+). Needs root or passwordless sudo.
# Required: terraform, ansible, jq, ssh-keygen (openssh-client), tar, curl, unzip.
set -euo pipefail

TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.9.8}"
# Mirror reachable from Russia; override with TERRAFORM_URL if needed.
case "$(uname -m)" in
  x86_64)        TF_ARCH=amd64 ;;
  aarch64|arm64) TF_ARCH=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
TERRAFORM_URL="${TERRAFORM_URL:-https://hashicorp-releases.yandexcloud.net/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip}"

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

have() { command -v "$1" >/dev/null 2>&1; }
log()  { echo "[install-tools] $*"; }

APT_UPDATED=0
apt_install() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    $SUDO apt-get update -y
    APT_UPDATED=1
  fi
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends "$@"
}

# command -> apt package
declare -A APT_PKGS=(
  [curl]=curl
  [unzip]=unzip
  [jq]=jq
  [tar]=tar
  [ssh-keygen]=openssh-client
)
for cmd in "${!APT_PKGS[@]}"; do
  if have "$cmd"; then
    log "$cmd: ok"
  else
    log "$cmd: missing, installing ${APT_PKGS[$cmd]}"
    apt_install "${APT_PKGS[$cmd]}"
  fi
done

if have ansible-playbook; then
  log "ansible: ok ($(ansible --version | head -1))"
else
  log "ansible: missing, installing"
  apt_install ansible
fi

if have terraform; then
  log "terraform: ok ($(terraform version | head -1))"
else
  log "terraform: missing, installing ${TERRAFORM_VERSION}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$TERRAFORM_URL" -o "$tmp/terraform.zip"
  unzip -q "$tmp/terraform.zip" -d "$tmp"
  $SUDO install -m 0755 "$tmp/terraform" /usr/local/bin/terraform
  log "terraform: installed ($(terraform version | head -1))"
fi

# Final check
for cmd in terraform ansible-playbook jq ssh-keygen tar curl; do
  have "$cmd" || { log "ERROR: $cmd is still missing"; exit 1; }
done
log "all tools are present"
