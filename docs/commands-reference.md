# OpenStack CLI Quick Reference

## Session Setup
```bash
source /var/snap/microstack/common/etc/microstack.rc
alias os='microstack.openstack'
```

## Identity
```bash
os project list --domain cloudcorelab
os user list --domain cloudcorelab
os role assignment list --project ccl-frontend --names
os quota show ccl-frontend
```

## Compute
```bash
os server list --long
os server show ccl-web-01 -c status -c addresses -c flavor
os console log show ccl-web-01 --lines 30
os console url show ccl-web-01 --novnc
os server image create ccl-web-01 --name my-snapshot --wait
os server resize ccl-web-01 --flavor ccl.medium --wait
os server resize confirm ccl-web-01
```

## Networking
```bash
os network list
os router show ccl-core-router -c external_gateway_info
os router port list ccl-core-router
os floating ip list
os port list --server ccl-web-01
```

## Storage
```bash
os volume list
os volume show ccl-api-data -c attachments -c status
os volume snapshot list
os container list
os container show ccl-artifacts
os object list ccl-artifacts
```

## Orchestration
```bash
os orchestration template validate -t heat-templates/cloudcorelab-full.yaml
os stack create cloudcorelab-iac -t heat-templates/cloudcorelab-full.yaml --wait
os stack show cloudcorelab-iac -c stack_status
os stack resource list cloudcorelab-iac
os stack output list cloudcorelab-iac
os stack event list cloudcorelab-iac
```
