#!/bin/bash
# =============================================================================
# CloudCoreLab — Phase 2: Identity Infrastructure (Keystone)
# Author: Horus Sielatshom
# Usage:  bash scripts/02-identity.sh
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

# Helper: create only if not exists
create_if_absent() {
  local type=$1; shift
  local name=$1; shift
  if ! $OS $type list -f value -c Name 2>/dev/null | grep -q "^${name}$"; then
    $OS $type create "$name" "$@"
    log "Created $type: $name"
  else
    warn "$type '$name' already exists — skipping."
  fi
}

step "Domain"
create_if_absent domain cloudcorelab --description "CloudCoreLab private cloud"

step "Projects"
for proj in ccl-frontend ccl-backend ccl-database ccl-ops; do
  if ! $OS project list --domain cloudcorelab -f value -c Name | grep -q "^${proj}$"; then
    $OS project create "$proj" --domain cloudcorelab
    log "Created project: $proj"
  else
    warn "Project '$proj' already exists."
  fi
done

step "Users"
declare -A USERS=(
  [ccl-webadmin]="WebAdmin2024!"
  [ccl-apidev]="ApiDev2024!"
  [ccl-dba]="DbAdmin2024!"
  [ccl-ops]="Ops2024!"
)
for user in "${!USERS[@]}"; do
  if ! $OS user list --domain cloudcorelab -f value -c Name | grep -q "^${user}$"; then
    $OS user create "$user" --domain cloudcorelab --password "${USERS[$user]}"
    log "Created user: $user"
  else
    warn "User '$user' already exists."
  fi
done

step "Groups"
for group in ccl-web-team ccl-api-team ccl-ops-team; do
  if ! $OS group list --domain cloudcorelab -f value -c Name | grep -q "^${group}$"; then
    $OS group create "$group" --domain cloudcorelab
    log "Created group: $group"
  fi
done

$OS group add user ccl-web-team ccl-webadmin --group-domain cloudcorelab --user-domain cloudcorelab 2>/dev/null || true
$OS group add user ccl-api-team ccl-apidev   --group-domain cloudcorelab --user-domain cloudcorelab 2>/dev/null || true
$OS group add user ccl-ops-team ccl-ops      --group-domain cloudcorelab --user-domain cloudcorelab 2>/dev/null || true
log "Group memberships set."

step "Role assignments"
$OS role add --project ccl-frontend --project-domain cloudcorelab \
  --group ccl-web-team --group-domain cloudcorelab member 2>/dev/null || true
$OS role add --project ccl-backend --project-domain cloudcorelab \
  --group ccl-api-team --group-domain cloudcorelab member 2>/dev/null || true
$OS role add --project ccl-ops --project-domain cloudcorelab \
  --group ccl-ops-team --group-domain cloudcorelab admin 2>/dev/null || true
$OS role add --project ccl-database --project-domain cloudcorelab \
  --user ccl-dba --user-domain cloudcorelab member 2>/dev/null || true
log "Roles assigned."

step "Quotas"
$OS quota set ccl-frontend --instances 5 --cores 10 --ram 10240 --volumes 5
$OS quota set ccl-backend  --instances 5 --cores 10 --ram 10240 --volumes 10
$OS quota set ccl-database --instances 3 --cores 6  --ram 8192  --volumes 10 --gigabytes 200
$OS quota set ccl-ops      --instances 10 --cores 20 --ram 20480
log "Quotas configured."

step "Verification"
echo ""
$OS project list --domain cloudcorelab
echo ""
$OS role assignment list --domain cloudcorelab --names
echo ""
echo -e "${GREEN}Phase 2 complete — Identity layer ready.${NC}"
echo "Next: bash scripts/03-network.sh"
