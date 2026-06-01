#!/bin/bash
# =============================================================================
# CloudCoreLab — Phase 6: Heat Orchestration
# Author: Horus Sielatshom
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

TEMPLATE="heat-templates/cloudcorelab-full.yaml"
STACK_NAME="cloudcorelab-iac"

step "Template validation"
$OS orchestration template validate -t "$TEMPLATE" && log "Template valid." || { echo "Template invalid — check YAML."; exit 1; }

step "Stack deploy"
if $OS stack list -f value -c "Stack Name" | grep -q "^${STACK_NAME}$"; then
  warn "Stack '$STACK_NAME' already exists — updating..."
  $OS stack update "$STACK_NAME" -t "$TEMPLATE" --wait
else
  log "Deploying stack '$STACK_NAME'..."
  $OS stack create "$STACK_NAME" -t "$TEMPLATE" --wait
fi

step "Stack status"
$OS stack show "$STACK_NAME" -c stack_status -c stack_status_reason

step "Stack resources"
$OS stack resource list "$STACK_NAME"

step "Stack outputs"
$OS stack output list "$STACK_NAME"
echo ""
$OS stack output show "$STACK_NAME" web_public_ip
$OS stack output show "$STACK_NAME" api_private_ip
$OS stack output show "$STACK_NAME" stack_summary

echo ""
echo -e "${GREEN}Phase 6 complete — Heat stack deployed.${NC}"
echo "Next: bash tests/validate.sh"
