#!/bin/bash
# =============================================================================
# CloudCoreLab — Phase 3: Network Topology (Neutron)
# Author: Horus Sielatshom
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
net_exists() { $OS network list -f value -c Name | grep -q "^$1$"; }
sg_exists()  { $OS security group list -f value -c Name | grep -q "^$1$"; }

step "External provider network"
if ! net_exists ccl-public; then
  $OS network create ccl-public \
    --external \
    --provider-network-type flat \
    --provider-physical-network extnet
  $OS subnet create ccl-public-subnet \
    --network ccl-public \
    --subnet-range 203.0.113.0/24 \
    --gateway 203.0.113.1 \
    --allocation-pool start=203.0.113.100,end=203.0.113.200 \
    --no-dhcp
  log "External network created: ccl-public"
else
  warn "ccl-public already exists."
fi

step "Frontend network (web tier)"
if ! net_exists ccl-frontend-net; then
  $OS network create ccl-frontend-net
  $OS subnet create ccl-frontend-subnet \
    --network ccl-frontend-net \
    --subnet-range 10.10.1.0/24 \
    --gateway 10.10.1.1 \
    --dns-nameserver 8.8.8.8 \
    --dns-nameserver 8.8.4.4
  log "Frontend network created: 10.10.1.0/24"
else
  warn "ccl-frontend-net already exists."
fi

step "Backend network (API + DB tier)"
if ! net_exists ccl-backend-net; then
  $OS network create ccl-backend-net
  $OS subnet create ccl-backend-subnet \
    --network ccl-backend-net \
    --subnet-range 10.10.2.0/24 \
    --gateway 10.10.2.1 \
    --dns-nameserver 8.8.8.8
  log "Backend network created: 10.10.2.0/24"
else
  warn "ccl-backend-net already exists."
fi

step "Core router"
if ! $OS router list -f value -c Name | grep -q "^ccl-core-router$"; then
  $OS router create ccl-core-router --description "CloudCoreLab core router"
  $OS router set ccl-core-router --external-gateway ccl-public
  $OS router add subnet ccl-core-router ccl-frontend-subnet
  $OS router add subnet ccl-core-router ccl-backend-subnet
  log "Router created and connected to both tenant networks."
else
  warn "ccl-core-router already exists."
fi

step "Security groups"

# Web tier
if ! sg_exists ccl-web-sg; then
  $OS security group create ccl-web-sg --description "Web tier: HTTP/HTTPS/SSH from internet"
  $OS security group rule create ccl-web-sg --protocol tcp  --dst-port 22   --remote-ip 0.0.0.0/0
  $OS security group rule create ccl-web-sg --protocol tcp  --dst-port 80   --remote-ip 0.0.0.0/0
  $OS security group rule create ccl-web-sg --protocol tcp  --dst-port 443  --remote-ip 0.0.0.0/0
  $OS security group rule create ccl-web-sg --protocol icmp                 --remote-ip 0.0.0.0/0
  log "ccl-web-sg created."
else
  warn "ccl-web-sg already exists."
fi

# API tier — internal only
if ! sg_exists ccl-api-sg; then
  $OS security group create ccl-api-sg --description "API tier: port 8080 from web tier only"
  $OS security group rule create ccl-api-sg --protocol tcp --dst-port 8080 --remote-ip 10.10.1.0/24
  $OS security group rule create ccl-api-sg --protocol tcp --dst-port 22   --remote-ip 10.10.1.0/24
  log "ccl-api-sg created."
else
  warn "ccl-api-sg already exists."
fi

# DB tier — postgres from API tier only
if ! sg_exists ccl-db-sg; then
  $OS security group create ccl-db-sg --description "DB tier: PostgreSQL from API tier only"
  $OS security group rule create ccl-db-sg --protocol tcp --dst-port 5432 --remote-ip 10.10.2.0/24
  $OS security group rule create ccl-db-sg --protocol tcp --dst-port 22   --remote-ip 10.10.2.0/24
  log "ccl-db-sg created."
else
  warn "ccl-db-sg already exists."
fi

step "Verification"
echo ""; $OS network list
echo ""; $OS router show ccl-core-router -c external_gateway_info -c status
echo ""; $OS security group list
echo ""
echo -e "${GREEN}Phase 3 complete — Network topology ready.${NC}"
echo "Next: bash scripts/04-compute.sh"
