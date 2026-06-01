<div align="center">

# CloudCoreLab

### Multi-Tier Private Cloud on Canonical MicroStack

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![OpenStack](https://img.shields.io/badge/OpenStack-2024.1-ED1944?style=for-the-badge&logo=openstack&logoColor=white)](https://openstack.org)
[![MicroStack](https://img.shields.io/badge/Canonical-MicroStack-772953?style=for-the-badge&logo=canonical&logoColor=white)](https://microstack.run)
[![IaC](https://img.shields.io/badge/IaC-Heat_HOT-orange?style=for-the-badge)](https://docs.openstack.org/heat)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue?style=for-the-badge)](LICENSE)

---

**A production-grade private cloud deployed on Ubuntu Server using Canonical's MicroStack.**  
Full OpenStack lifecycle management across all six service domains — Identity, Compute, Networking, Block Storage, Object Storage, and Orchestration — entirely reproducible via Infrastructure as Code.

[Architecture](#architecture) · [Quickstart](#quickstart) · [Project Phases](#project-phases) · [IaC](#infrastructure-as-code) · [Validation](#validation)

</div>

---

## Why This Project

Private cloud engineering is central to Canonical's product surface — from MicroStack and Charmed OpenStack to MAAS-provisioned bare metal. This project demonstrates hands-on command of the full OpenStack control plane using Canonical's own tooling, on Ubuntu, the way it runs in real customer environments.

Every component is **reproducible from scripts**, **documented with architecture rationale**, and **validated end-to-end** — not just proof-of-concept.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                   Ubuntu 24.04 LTS — Bare Metal                  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    MicroStack (snap)                       │  │
│  │                                                            │  │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐              │  │
│  │  │Keystone  │   │  Nova    │   │ Neutron  │              │  │
│  │  │Identity  │   │KVM/QEMU  │   │OVS + L3  │              │  │
│  │  └──────────┘   └────┬─────┘   └────┬─────┘              │  │
│  │                      │              │                      │  │
│  │  ┌──────────┐   ┌────▼─────────────▼────────────────┐    │  │
│  │  │  Glance  │   │             VMs                    │    │  │
│  │  │  Images  ├──►│  web-01 · web-02 · api-01          │    │  │
│  │  └──────────┘   └────────────────────────────────────┘    │  │
│  │                                                            │  │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐              │  │
│  │  │  Cinder  │   │  Swift   │   │   Heat   │              │  │
│  │  │  Block   │   │  Object  │   │   IaC    │              │  │
│  │  └──────────┘   └──────────┘   └──────────┘              │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Network Topology

```
Internet
    │  Floating IPs (203.0.113.x)
    ▼
┌─────────────────┐
│  ccl-public-net │  External provider (flat/extnet)
│  203.0.113.0/24 │  No DHCP
└────────┬────────┘
         │
    ┌────▼─────────────┐
    │  ccl-core-router  │  Neutron router — NAT, L3 routing
    └──┬────────────┬───┘
       │            │
┌──────▼──┐    ┌────▼────┐
│frontend │    │backend  │  Tenant networks (VXLAN)
│10.10.1  │    │10.10.2  │
│/24      │    │/24      │
└──┬───┬──┘    └────┬────┘
   │   │            │
 web  web         api-01
  01   02       + 50 GB Cinder volume
  (FIP)(FIP)    (internal only)
```

---

## Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| OS | Ubuntu 24.04 LTS | Host |
| Cloud | Canonical MicroStack | Snap-packaged OpenStack |
| Hypervisor | KVM / QEMU via libvirt | Hardware-accelerated VMs |
| Networking | Neutron + Open vSwitch | SDN, VXLAN, L3 routing |
| Storage | Cinder (LVM) + Swift | Block and object |
| Orchestration | Heat HOT | Infrastructure as Code |
| Identity | Keystone | RBAC, projects, domains |
| Scripting | Bash | Idempotent automation |

---

## Repository Structure

```
cloudcorelab/
├── README.md
├── LICENSE
│
├── scripts/
│   ├── 00-preflight.sh          # Requirements check
│   ├── 01-install.sh            # MicroStack install + init
│   ├── 02-identity.sh           # Domains, projects, users, RBAC
│   ├── 03-network.sh            # Networks, router, security groups
│   ├── 04-compute.sh            # Images, flavors, keypairs, VMs
│   ├── 05-storage.sh            # Cinder volumes + Swift containers
│   ├── 06-orchestration.sh      # Heat stack deploy
│   ├── teardown.sh              # Clean removal of all resources
│   └── health-check.sh          # Full environment validation
│
├── heat-templates/
│   ├── cloudcorelab-full.yaml   # Complete multi-tier stack
│   ├── network-only.yaml        # Network topology only
│   └── compute-only.yaml        # Compute tier only
│
├── configs/
│   ├── clouds.yaml              # OpenStack client config
│   └── user-data/
│       ├── web-init.sh          # Web tier cloud-init
│       └── api-init.sh          # API tier cloud-init
│
├── docs/
│   ├── architecture.md          # Deep-dive architecture notes
│   ├── networking.md            # Neutron + OVS internals
│   ├── troubleshooting.md       # Common issues and fixes
│   └── commands-reference.md   # Full CLI reference
│
└── tests/
    └── validate.sh              # Post-deploy validation suite
```

---

## Quickstart

### Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| OS | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| RAM | 8 GB | 16 GB |
| vCPUs | 4 (VT-x enabled) | 8 |
| Disk | 50 GB | 100 GB |

```bash
# Verify hardware virtualisation is enabled
egrep -c "(vmx|svm)" /proc/cpuinfo   # must return > 0
```

### Deploy

```bash
git clone https://github.com/kinghorus12/cloudcorelab.git
cd cloudcorelab

# Check system requirements
bash scripts/00-preflight.sh

# Install and initialise MicroStack (~15 min)
sudo bash scripts/01-install.sh

# Deploy all layers
bash scripts/02-identity.sh
bash scripts/03-network.sh
bash scripts/04-compute.sh
bash scripts/05-storage.sh
bash scripts/06-orchestration.sh

# Validate everything
bash tests/validate.sh
```

Or deploy the entire infrastructure from a single Heat template (after install):

```bash
openstack stack create cloudcorelab \
  -t heat-templates/cloudcorelab-full.yaml \
  --wait
```

---

## Project Phases

### Phase 1 — MicroStack Install

```bash
$ openstack service list
| glance    | image         |
| keystone  | identity      |
| neutron   | network       |
| nova      | compute       |
| cinderv3  | volumev3      |
| swift     | object-store  |
| heat      | orchestration |
```

### Phase 2 — Identity (Keystone)

Multi-project RBAC with group-based role assignments and per-project quotas.

```
Domain: cloudcorelab
├── ccl-frontend  ← ccl-web-team (member)   quota: 5 instances
├── ccl-backend   ← ccl-api-team (member)   quota: 5 instances
├── ccl-database  ← ccl-dba user  (member)  quota: 200 GB volumes
└── ccl-ops       ← ccl-ops-team  (admin)
```

### Phase 3 — Networking (Neutron)

```bash
$ openstack network list
| ccl-public   | 203.0.113.0/24 | external, no DHCP     |
| frontend-net | 10.10.1.0/24   | DNS 8.8.8.8           |
| backend-net  | 10.10.2.0/24   | DNS 8.8.8.8           |

# Security group isolation
ccl-web-sg : 22,80,443,ICMP from 0.0.0.0/0
ccl-api-sg : 8080 from 10.10.1.0/24 only
ccl-db-sg  : 5432 from 10.10.2.0/24 only
```

### Phase 4 — Compute (Nova)

Anti-affinity server groups, cloud-init bootstrapping, snapshot lifecycle.

```bash
$ openstack server list
| ccl-web-01 | ACTIVE | frontend=10.10.1.x, 203.0.113.101 |
| ccl-web-02 | ACTIVE | frontend=10.10.1.x, 203.0.113.102 |
| ccl-api-01 | ACTIVE | backend=10.10.2.x                  |

$ openstack server group show ccl-web-group
| policy  | anti-affinity          |
| members | ccl-web-01, ccl-web-02 |
```

### Phase 5 — Storage

```bash
$ openstack volume list
| ccl-api-data | 50 GB  | in-use | attached to ccl-api-01 |
| ccl-db-data  | 100 GB | in-use | attached to ccl-api-01 |

$ openstack container list
| ccl-artifacts | public (X-Container-Read: .r:*,.rlistings) |
| ccl-backups   | private                                     |
| ccl-logs      | private                                     |
```

### Phase 6 — Orchestration (Heat)

```bash
$ openstack stack show cloudcorelab-iac
| stack_status | CREATE_COMPLETE |

$ openstack stack output list cloudcorelab-iac
| web_public_ip  | 203.0.113.101 |
| api_private_ip | 10.10.2.10    |
```

---

## Infrastructure as Code

`heat-templates/cloudcorelab-full.yaml` reproduces the entire environment:
- Two tenant networks + subnets + DNS
- Core router with external gateway + both subnet interfaces
- Three tiered security groups with network-scoped rules
- Two web-tier instances with anti-affinity policy
- One API-tier instance
- Floating IP on web tier
- Cinder volume attached to API server

```bash
openstack orchestration template validate -t heat-templates/cloudcorelab-full.yaml
openstack stack create cloudcorelab-iac -t heat-templates/cloudcorelab-full.yaml --wait
openstack stack output list cloudcorelab-iac
openstack stack delete cloudcorelab-iac --wait
```

---

## Validation

```bash
$ bash tests/validate.sh

[PASS] MicroStack services healthy
[PASS] Keystone: domain + 4 projects + users + roles verified
[PASS] Neutron: 3 networks, 1 router, gateway set, 3 SGs
[PASS] Nova: 3 instances ACTIVE
[PASS] Floating IPs: 2 assigned to web tier
[PASS] Cinder: volumes in-use and attached
[PASS] Swift: containers exist, artifacts public
[PASS] Heat: stack CREATE_COMPLETE

8/8 checks passed ✓
```

---

## Concepts Demonstrated

| Concept | Implementation |
|---------|---------------|
| Multi-tenant RBAC | Keystone domain, group-based roles, per-project quotas |
| SDN with tenant isolation | Multi-tier Neutron, OVS bridges, VXLAN overlay |
| HA compute placement | Nova server groups with anti-affinity |
| Infrastructure as Code | Parameterised Heat HOT template with outputs |
| Storage lifecycle | Cinder create/attach/extend/snapshot, Swift ACLs |
| Cloud-init | Web + API tier user-data bootstrapping |
| Idempotent automation | All scripts safe to re-run with state checks |

---

## Author

**Horus Sielatshom** — Infrastructure Engineer · DevOps · OpenStack  
Douala, Cameroon · [github.com/kinghorus12](https://github.com/kinghorus12)

---
<sub>Built on Ubuntu · Powered by Canonical MicroStack · Apache 2.0</sub>
