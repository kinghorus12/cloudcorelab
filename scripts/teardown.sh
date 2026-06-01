#!/bin/bash
# =============================================================================
# CloudCoreLab — Teardown
# Removes all CloudCoreLab resources cleanly.
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }

read -p "This will DELETE all CloudCoreLab resources. Type 'yes' to confirm: " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "Aborted."; exit 0; }

# Heat stack (removes most resources)
echo "Deleting Heat stack..."
$OS stack delete cloudcorelab-iac --wait 2>/dev/null && log "Heat stack deleted." || warn "No Heat stack found."

# Manual resources (created outside Heat)
echo "Deleting manual resources..."
for vm in ccl-web-01 ccl-web-02 ccl-api-01; do
  $OS server delete "$vm" 2>/dev/null && log "Deleted VM: $vm" || true
done

for fip in $($OS floating ip list -f value -c ID 2>/dev/null); do
  $OS floating ip delete "$fip" 2>/dev/null && log "Released floating IP: $fip" || true
done

for vol in ccl-api-data ccl-db-data ccl-api-restore; do
  $OS volume delete "$vol" 2>/dev/null && log "Deleted volume: $vol" || true
done

for snap in ccl-api-snap; do
  $OS volume snapshot delete "$snap" 2>/dev/null && log "Deleted snapshot: $snap" || true
done

for img in ccl-golden-image ccl-base; do
  $OS image delete "$img" 2>/dev/null && log "Deleted image: $img" || true
done

for container in ccl-artifacts ccl-backups ccl-logs; do
  $OS container delete "$container" --recursive 2>/dev/null && log "Deleted container: $container" || true
done

for sg in ccl-web-sg ccl-api-sg ccl-db-sg; do
  $OS security group delete "$sg" 2>/dev/null && log "Deleted SG: $sg" || true
done

$OS router remove subnet ccl-core-router ccl-frontend-subnet 2>/dev/null || true
$OS router remove subnet ccl-core-router ccl-backend-subnet  2>/dev/null || true
$OS router delete ccl-core-router 2>/dev/null && log "Deleted router." || true

for net in ccl-frontend-net ccl-backend-net ccl-public; do
  $OS network delete "$net" 2>/dev/null && log "Deleted network: $net" || true
done

for kp in ccl-deploy-key; do
  $OS keypair delete "$kp" 2>/dev/null && log "Deleted keypair: $kp" || true
done

for flavor in ccl.micro ccl.small ccl.medium ccl.large; do
  $OS flavor delete "$flavor" 2>/dev/null && log "Deleted flavor: $flavor" || true
done

for sg in ccl-web-group; do
  $OS server group delete "$sg" 2>/dev/null && log "Deleted server group: $sg" || true
done

echo ""
echo -e "${GREEN}Teardown complete.${NC}"
