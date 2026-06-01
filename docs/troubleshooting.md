# Troubleshooting

## VM stuck in BUILD

```bash
openstack server show VM_NAME -c fault -c status
journalctl -u snap.microstack.nova-compute -n 50
# Check image is ACTIVE
openstack image show ccl-base -c status
```

## No internet from VM

```bash
# 1. Floating IP associated?
openstack floating ip list
# 2. Router has external gateway?
openstack router show ccl-core-router -c external_gateway_info
# 3. Router has subnet interface?
openstack router port list ccl-core-router
# 4. Security group allows traffic?
openstack security group rule list ccl-web-sg
```

## Volume won't attach

```bash
# Must be 'available' before attach
openstack volume show ccl-api-data -c status
# If stuck in 'error', reset:
openstack volume set ccl-api-data --state available
```

## Heat stack fails

```bash
# Always validate first
openstack orchestration template validate -t heat-templates/cloudcorelab-full.yaml
# Check events
openstack stack event list cloudcorelab-iac
# Check specific resource
openstack stack resource show cloudcorelab-iac web_server_1
```

## Services down

```bash
snap services microstack                     # list all service states
sudo snap restart microstack.nova-compute    # restart specific service
sudo snap restart microstack                 # restart everything
```

## Reset entirely

```bash
sudo snap remove microstack --purge
sudo snap install microstack --channel 2024/stable
sudo microstack init --auto --control
```
