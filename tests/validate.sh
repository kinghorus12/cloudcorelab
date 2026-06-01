#!/bin/bash
# =============================================================================
# CloudCoreLab — Post-Deploy Validation Suite
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
PASS=0; FAIL=0
ok()   { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }

check_service() {
  local name=$1; local type=$2
  $OS service list -f value -c Type | grep -q "^${type}$" && ok "Service registered: $name ($type)" || fail "Service missing: $name"
}

check_vm() {
  local name=$1
  local status
  status=$($OS server show "$name" -f value -c status 2>/dev/null || echo "NOT_FOUND")
  [[ "$status" == "ACTIVE" ]] && ok "VM $name: ACTIVE" || fail "VM $name: $status"
}

check_net() {
  local name=$1
  $OS network list -f value -c Name | grep -q "^${name}$" && ok "Network: $name" || fail "Network missing: $name"
}

check_vol() {
  local name=$1
  local status
  status=$($OS volume show "$name" -f value -c status 2>/dev/null || echo "NOT_FOUND")
  [[ "$status" =~ ^(in-use|available)$ ]] && ok "Volume $name: $status" || fail "Volume $name: $status"
}

echo ""
echo "═══════════════════════════════════════════════"
echo "  CloudCoreLab — Validation Suite"
echo "═══════════════════════════════════════════════"
echo ""

echo "▸ Services"
check_service "Identity"     identity
check_service "Compute"      compute
check_service "Network"      network
check_service "Image"        image
check_service "Volume"       volumev3
check_service "Object Store" object-store
check_service "Orchestration" orchestration

echo ""
echo "▸ Identity"
$OS domain list -f value -c Name | grep -q cloudcorelab && ok "Domain: cloudcorelab" || fail "Domain missing"
for proj in ccl-frontend ccl-backend ccl-database ccl-ops; do
  $OS project list --domain cloudcorelab -f value -c Name | grep -q "^${proj}$" \
    && ok "Project: $proj" || fail "Project missing: $proj"
done

echo ""
echo "▸ Networks"
check_net ccl-public
check_net ccl-frontend-net
check_net ccl-backend-net
ROUTER=$($OS router show ccl-core-router -f value -c status 2>/dev/null || echo "NOT_FOUND")
[[ "$ROUTER" == "ACTIVE" ]] && ok "Router: ccl-core-router ACTIVE" || fail "Router: $ROUTER"

echo ""
echo "▸ Compute"
check_vm ccl-web-01
check_vm ccl-web-02
check_vm ccl-api-01
FIP_COUNT=$($OS floating ip list -f value -c "Fixed IP Address" | grep -vc "None" || true)
[[ $FIP_COUNT -ge 2 ]] && ok "Floating IPs: $FIP_COUNT associated" || fail "Expected 2 FIPs, found $FIP_COUNT"

echo ""
echo "▸ Storage"
check_vol ccl-api-data
check_vol ccl-db-data
for c in ccl-artifacts ccl-backups ccl-logs; do
  $OS container show "$c" &>/dev/null && ok "Container: $c" || fail "Container missing: $c"
done
ARTIFACTS_ACL=$($OS container show ccl-artifacts -f value -c read_acl 2>/dev/null || echo "none")
[[ "$ARTIFACTS_ACL" == *".r:*"* ]] && ok "ccl-artifacts: public read ACL set" || fail "ccl-artifacts: public ACL missing"

echo ""
echo "▸ Orchestration"
STACK=$($OS stack show cloudcorelab-iac -f value -c stack_status 2>/dev/null || echo "NOT_FOUND")
[[ "$STACK" =~ ^(CREATE_COMPLETE|UPDATE_COMPLETE)$ ]] && ok "Heat stack: $STACK" || fail "Heat stack: $STACK"

echo ""
echo "═══════════════════════════════════════════════"
printf "  ${GREEN}%d passed${NC}  ${RED}%d failed${NC}\n" $PASS $FAIL
echo "═══════════════════════════════════════════════"
[[ $FAIL -eq 0 ]] && echo -e "  ${GREEN}All checks passed ✓${NC}" || echo -e "  ${RED}$FAIL check(s) failed — review output above${NC}"
echo ""
exit $FAIL
