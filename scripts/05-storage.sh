#!/bin/bash
# =============================================================================
# CloudCoreLab — Phase 5: Storage Layer (Cinder + Swift)
# Author: Horus Sielatshom
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
vol_exists() { $OS volume list -f value -c Name | grep -q "^$1$"; }

step "Cinder: API tier data volume"
if ! vol_exists ccl-api-data; then
  $OS volume create ccl-api-data --size 50 --description "API server persistent data"
  # Wait for available
  for i in $(seq 1 15); do
    STATUS=$($OS volume show ccl-api-data -f value -c status)
    [[ "$STATUS" == "available" ]] && break
    sleep 2
  done
  $OS server add volume ccl-api-01 ccl-api-data
  log "ccl-api-data (50 GB) created and attached to ccl-api-01."
else
  warn "ccl-api-data already exists."
fi

step "Cinder: DB data volume"
if ! vol_exists ccl-db-data; then
  $OS volume create ccl-db-data --size 100 --description "Database storage"
  log "ccl-db-data (100 GB) created."
else
  warn "ccl-db-data already exists."
fi

step "Cinder: Snapshots"
if ! $OS volume snapshot list -f value -c Name | grep -q "^ccl-api-snap$"; then
  $OS volume snapshot create ccl-api-snap \
    --volume ccl-api-data \
    --description "API data — daily backup simulation" \
    --force
  log "Snapshot 'ccl-api-snap' created."
else
  warn "Snapshot 'ccl-api-snap' already exists."
fi

step "Swift: Object storage containers"
for container in ccl-artifacts ccl-backups ccl-logs; do
  if ! $OS container list -f value -c Name | grep -q "^${container}$"; then
    $OS container create "$container"
    log "Container '$container' created."
  else
    warn "Container '$container' already exists."
  fi
done

step "Swift: Upload sample artifacts"
echo "CloudCoreLab v1.0 — $(date)" > /tmp/RELEASE.txt
echo "Deployment: multi-tier OpenStack on MicroStack" >> /tmp/RELEASE.txt
$OS object create ccl-artifacts /tmp/RELEASE.txt --name RELEASE.txt 2>/dev/null || true
log "RELEASE.txt uploaded to ccl-artifacts."

step "Swift: Public ACL on artifacts container"
$OS container set ccl-artifacts \
  --property "X-Container-Read=.r:*,.rlistings"
log "ccl-artifacts set to public read."

step "Swift: Auto-expire on log objects"
echo "Sample log entry — $(date)" > /tmp/sample.log
$OS object create ccl-logs /tmp/sample.log --name sample.log 2>/dev/null || true
$OS object set ccl-logs sample.log --property "X-Delete-After=86400"
log "sample.log in ccl-logs: auto-delete after 24 hours."

step "Verification"
echo ""; $OS volume list
echo ""; $OS volume snapshot list
echo ""; $OS container list
echo ""; $OS container show ccl-artifacts
echo ""
echo -e "${GREEN}Phase 5 complete — Storage layer ready.${NC}"
echo "Next: bash scripts/06-orchestration.sh"
