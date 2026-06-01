# CloudCoreLab — Architecture Notes

## Overview

CloudCoreLab deploys a multi-tier private cloud using Canonical MicroStack — a snap-packaged
OpenStack that self-configures on a single Ubuntu host. The architecture mirrors real production
private cloud patterns at a smaller scale.

## Service Communication

```
Client (openstack CLI / Horizon)
     │
     ▼
Keystone ──── auth token validation ────────────────────────────┐
     │                                                           │
     ├──► Nova API                                               │
     │       ├──► Nova Conductor ──► Nova Compute               │
     │       │         └──► libvirt ──► KVM/QEMU (VM)          │
     │       └──► Neutron API                                    │
     │                 └──► neutron-openvswitch-agent ──► OVS   │
     ├──► Glance API (image store for boot)                      │
     ├──► Cinder API ──► cinder-volume ──► LVM backend          │
     ├──► Swift API ──► swift-proxy ──► object store            │
     └──► Heat API ──── orchestration engine ────────────────────┘
```

## Networking Deep Dive

### Namespace topology
Each Neutron L3 router runs in a dedicated Linux network namespace:
```
qrouter-<uuid>
  ├── qg-xxx  (gateway interface — external network)
  ├── qr-yyy  (internal — frontend subnet)
  └── qr-zzz  (internal — backend subnet)

qdhcp-<uuid>   (one per subnet with DHCP enabled)
```

### Floating IP NAT
```
External: 203.0.113.101
     │
     │  iptables DNAT in qrouter namespace
     ▼
VM fixed IP: 10.10.1.x
```

### OVS Bridge Layout
```
br-int (integration bridge)
  └── patches to br-ex and br-tun

br-ex (external bridge)
  └── physical NIC (for external traffic)

br-tun (tunnel bridge)
  └── VXLAN tunnels (multi-node) or local (single-node)
```

## Nova Compute & KVM

Nova delegates to libvirt for VM lifecycle management:
```bash
# View VMs at hypervisor level
virsh list --all

# View VM XML config
virsh dumpxml <vm_name>

# Inspect VM disk (copy-on-write over base image)
ls /var/snap/microstack/common/lib/nova/instances/
```

## Glance Image Pipeline

```
qcow2 upload → Glance API → /var/snap/microstack/common/lib/images/
                                  │
              Nova boot ──────────┘ (copy-on-write clone per VM)
                                     backing file = Glance image
```

## Snap Service Architecture

MicroStack runs all OpenStack services under the snap:
```bash
snap services microstack
# microstack.nova-compute
# microstack.neutron-openvswitch-agent
# microstack.keystone-uwsgi
# microstack.glance-api
# etc.
```

Services communicate via an internal RabbitMQ message bus and a shared MariaDB database,
both also packaged inside the snap.
