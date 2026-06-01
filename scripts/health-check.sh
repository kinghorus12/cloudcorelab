#!/bin/bash
# =============================================================================
# CloudCoreLab — Health Check
# Verifies all deployed resources are healthy.
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

ok()   { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
info() { echo -e "\n─── $1 ───"; }

echo ""
echo "═══════════════════════════════════════"
echo "  CloudCoreLab Health Check"
echo "═══════════════════════════════════════"

info "OpenStack services"
SVCCOUNT=$($OS service list -f value -c Type | wc -l)
[[ $SVCCOUNT -ge 6 ]] && ok "$SVCCOUNT services registered" || fail "Expected 6+ services, found $SVCCOUNT"

info "Compute services"
COMPUTE_DOWN=$($OS compute service list -f value -c State | grep -c "down" || true)
[[ $COMPUTE_DOWN -eq 0 ]] && ok "All compute services up" || fail "$COMPUTE_DOWN compute service(s) down"

info "Instances"
for vm in ccl-web-01 ccl-web-02 ccl-api-01; do
  STATUS=$($OS server show "$vm" -f value -c status 2>/dev/null || echo "NOT_FOUND")
  [[ "$STATUS" == "ACTIVE" ]] && ok "$vm: ACTIVE" || fail "$vm: $STATUS"
done

info "Floating IPs"
FIP_COUNT=$($OS floating ip list -f value -c "Fixed IP Address" | grep -vc "None" || true)
[[ $FIP_COUNT -ge 2 ]] && ok "$FIP_COUNT floating IPs associated" || fail "Expected 2+ associated FIPs, found $FIP_COUNT"

info "Networks"
for net in ccl-public ccl-frontend-net ccl-backend-net; do
  STATUS=$($OS network show "$net" -f value -c status 2>/dev/null || echo "NOT_FOUND")
  [[ "$STATUS" == "ACTIVE" ]] && ok "Network $net: ACTIVE" || fail "Network $net: $STATUS"
done

info "Router"
ROUTER_STATUS=$($OS router show ccl-core-router -f value -c status 2>/dev/null || echo "NOT_FOUND")
[[ "$ROUTER_STATUS" == "ACTIVE" ]] && ok "ccl-core-router: ACTIVE" || fail "ccl-core-router: $ROUTER_STATUS"

info "Volumes"
for vol in ccl-api-data ccl-db-data; do
  STATUS=$($OS volume show "$vol" -f value -c status 2>/dev/null || echo "NOT_FOUND")
  [[ "$STATUS" == "in-use" || "$STATUS" == "available" ]] && ok "Volume $vol: $STATUS" || fail "Volume $vol: $STATUS"
done

info "Object storage"
for container in ccl-artifacts ccl-backups ccl-logs; do
  $OS container show "$container" &>/dev/null && ok "Container $container exists" || fail "Container $container missing"
done

info "Heat stack"
STACK_STATUS=$($OS stack show cloudcorelab-iac -f value -c stack_status 2>/dev/null || echo "NOT_FOUND")
[[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]] \
  && ok "Heat stack: $STACK_STATUS" || fail "Heat stack: $STACK_STATUS"

echo ""
echo "═══════════════════════════════════════"
printf "  ${GREEN}%d passed${NC}  ${RED}%d failed${NC}\n" $PASS $FAIL
echo "═══════════════════════════════════════"
[[ $FAIL -eq 0 ]] && echo -e "${GREEN}All checks passed ✓${NC}" || echo -e "${RED}$FAIL check(s) failed${NC}"
echo ""
