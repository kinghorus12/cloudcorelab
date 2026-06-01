#!/bin/bash
# =============================================================================
# CloudCoreLab — Phase 4: Compute Layer (Nova)
# Author: Horus Sielatshom
# =============================================================================
set -euo pipefail

source /var/snap/microstack/common/etc/microstack.rc
OS="microstack.openstack"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
step() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
vm_exists() { $OS server list -f value -c Name | grep -q "^$1$"; }

step "Flavors"
for spec in "ccl.micro:1:512:5" "ccl.small:1:1024:10" "ccl.medium:2:2048:20" "ccl.large:4:4096:40"; do
  IFS=: read name vcpus ram disk <<< "$spec"
  if ! $OS flavor list -f value -c Name | grep -q "^${name}$"; then
    $OS flavor create "$name" --vcpus "$vcpus" --ram "$ram" --disk "$disk"
    log "Flavor created: $name (${vcpus}vCPU ${ram}MB RAM ${disk}GB)"
  else
    warn "Flavor '$name' exists."
  fi
done

step "SSH keypair"
if ! $OS keypair list -f value -c Name | grep -q "^ccl-deploy-key$"; then
  if [[ ! -f ~/.ssh/id_rsa ]]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
    log "Generated SSH keypair at ~/.ssh/id_rsa"
  fi
  $OS keypair create ccl-deploy-key --public-key ~/.ssh/id_rsa.pub
  log "Keypair 'ccl-deploy-key' registered."
else
  warn "Keypair 'ccl-deploy-key' exists."
fi

step "Web tier cloud-init user data"
mkdir -p /tmp/ccl-userdata
cat > /tmp/ccl-userdata/web-init.sh << 'USERDATA'
#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl enable nginx && systemctl start nginx
echo "<h1>CloudCoreLab Web Tier</h1><p>Host: $(hostname)</p>" > /var/www/html/index.html
USERDATA

step "Anti-affinity server group"
if ! $OS server group list -f value -c Name | grep -q "^ccl-web-group$"; then
  $OS server group create ccl-web-group --policy anti-affinity
  log "Server group 'ccl-web-group' created with anti-affinity policy."
else
  warn "Server group 'ccl-web-group' exists."
fi
WEB_GROUP_ID=$($OS server group show ccl-web-group -f value -c id)

step "Web tier instances"
for vm in ccl-web-01 ccl-web-02; do
  if ! vm_exists "$vm"; then
    $OS server create "$vm" \
      --image ccl-base \
      --flavor ccl.small \
      --network ccl-frontend-net \
      --security-group ccl-web-sg \
      --key-name ccl-deploy-key \
      --hint group="$WEB_GROUP_ID" \
      --user-data /tmp/ccl-userdata/web-init.sh \
      --wait
    log "VM '$vm' launched and ACTIVE."
  else
    warn "VM '$vm' already exists."
  fi
done

step "Floating IPs — web tier"
for vm in ccl-web-01 ccl-web-02; do
  EXISTING_FIP=$($OS floating ip list --server "$vm" -f value -c "Floating IP Address" 2>/dev/null || true)
  if [[ -z "$EXISTING_FIP" ]]; then
    FIP=$($OS floating ip create ccl-public -f value -c floating_ip_address)
    $OS server add floating ip "$vm" "$FIP"
    log "$vm → floating IP: $FIP"
  else
    warn "$vm already has floating IP: $EXISTING_FIP"
  fi
done

step "API tier instance"
if ! vm_exists ccl-api-01; then
  cat > /tmp/ccl-userdata/api-init.sh << 'USERDATA'
#!/bin/bash
apt-get update -y
apt-get install -y python3-flask
mkdir -p /opt/ccl-api
cat > /opt/ccl-api/app.py << 'PYAPP'
from flask import Flask, jsonify
import socket
app = Flask(__name__)
@app.route('/health')
def health():
    return jsonify(status='ok', host=socket.gethostname(), tier='api')
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PYAPP
nohup python3 /opt/ccl-api/app.py > /var/log/ccl-api.log 2>&1 &
USERDATA

  $OS server create ccl-api-01 \
    --image ccl-base \
    --flavor ccl.medium \
    --network ccl-backend-net \
    --security-group ccl-api-sg \
    --key-name ccl-deploy-key \
    --user-data /tmp/ccl-userdata/api-init.sh \
    --wait
  log "VM 'ccl-api-01' launched (internal only — no floating IP)."
else
  warn "VM 'ccl-api-01' already exists."
fi

step "Snapshot web-01 as golden image"
if ! $OS image list -f value -c Name | grep -q "^ccl-golden-image$"; then
  $OS server image create ccl-web-01 --name ccl-golden-image --wait
  log "Snapshot 'ccl-golden-image' created."
else
  warn "'ccl-golden-image' already exists."
fi

step "Verification"
echo ""; $OS server list --long
echo ""
echo -e "${GREEN}Phase 4 complete — Compute layer ready.${NC}"
echo "Next: bash scripts/05-storage.sh"
