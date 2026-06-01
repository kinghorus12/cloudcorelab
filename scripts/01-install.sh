#!/bin/bash
# =============================================================================
# CloudCoreLab — Phase 1: MicroStack Installation
# Author: Horus Sielatshom
# Usage:  sudo bash scripts/01-install.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

[[ $EUID -ne 0 ]] && err "Run as root: sudo bash $0"

step "System update"
apt-get update -qq && apt-get upgrade -y -qq
log "System updated."

step "snapd"
apt-get install -y snapd -qq
snap install core && snap refresh core
log "snapd ready."

step "MicroStack install"
if snap list microstack &>/dev/null; then
  warn "MicroStack already installed — skipping snap install."
else
  snap install microstack --channel 2024/stable
  log "MicroStack snap installed."
fi

step "MicroStack initialisation"
if microstack.openstack service list &>/dev/null 2>&1; then
  warn "MicroStack already initialised — skipping init."
else
  log "Initialising MicroStack (this takes 5–15 minutes)..."
  microstack init --auto --control
  log "MicroStack initialised."
fi

step "Sourcing credentials"
RC=/var/snap/microstack/common/etc/microstack.rc
[[ -f "$RC" ]] && source "$RC" || err "RC file not found at $RC"

ADMIN_PASS=$(snap get microstack config.credentials.keystone-password)
log "Admin credentials loaded."

step "Service verification"
log "OpenStack services:"
microstack.openstack service list

log "Compute services:"
microstack.openstack compute service list

log "Network agents:"
microstack.openstack network agent list

step "Base image upload"
IMAGE_FILE="/tmp/cirros-0.6.2-x86_64-disk.img"
if ! microstack.openstack image list -f value -c Name | grep -q "^ccl-base$"; then
  if [[ ! -f "$IMAGE_FILE" ]]; then
    log "Downloading CirrOS base image..."
    wget -q -O "$IMAGE_FILE" \
      http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
  fi
  microstack.openstack image create ccl-base \
    --disk-format qcow2 --container-format bare \
    --file "$IMAGE_FILE" --public \
    --property project=cloudcorelab \
    --property os_type=linux \
    --tag cloudcorelab
  log "Base image 'ccl-base' uploaded."
else
  warn "Image 'ccl-base' already exists — skipping."
fi

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Phase 1 complete — MicroStack ready"
echo "══════════════════════════════════════════════════════"
echo "  Horizon dashboard : http://10.20.20.1"
echo "  Admin user        : admin"
echo "  Admin password    : $ADMIN_PASS"
echo ""
echo "  Next: bash scripts/02-identity.sh"
echo "══════════════════════════════════════════════════════"
