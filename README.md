# Network Automation Lab

A reproducible network automation project that builds and validates a four-router
leaf-spine eBGP fabric with a Layer-2 EVPN/VXLAN overlay using Ansible, Jinja2,
FRRouting, Containerlab, Docker, Git, and GitHub Actions.

## Project Overview

This lab uses a YAML-based source of truth to define a small data-centre
network. Ansible and Jinja2 generate FRR router configurations, Containerlab
deploys the virtual topology, and automated validation checks both the
configuration data and the running network.

The lab consists of:

- 2 leaf switches
- 2 spine switches
- eBGP underlay routing
- /31 point-to-point links
- /32 loopback advertisements
- Two Linux test hosts on VLAN 10 / VNI 10100
- EVPN Type-2 host bindings and Type-3 VTEP membership
- Automated topology validation
- Automated BGP and reachability testing
- GitHub-based change control and CI

## Architecture

```text
              spine01
              AS 65001
             /       \
            /         \
       leaf01         leaf02
       AS 65101       AS 65102
            \         /
             \       /
              spine02
              AS 65002
```

## Design Rationale

The four-node topology is the smallest leaf-spine fabric that demonstrates
redundant paths and consistent automation across both network roles. Each
router has its own ASN to model a straightforward eBGP underlay, while /31
prefixes avoid wasting addresses on point-to-point links. Stable /32 loopbacks
provide router IDs and the endpoints used to validate routed reachability.

The generated FRR configuration intentionally includes
`no bgp ebgp-requires-policy` so this isolated lab can exchange routes without
a production import/export policy framework. This is a lab simplification, not
a recommendation for a production fabric, where explicit routing policy should
be defined and reviewed.

## Automation Workflow

```text
YAML source of truth
        ↓
Ansible
        ↓
Jinja2 templates
        ↓
Generated FRR configurations and Containerlab topology
        ↓
Containerlab / Docker
        ↓
Running four-router fabric with two test hosts
        ↓
Automated runtime validation
```

## Validation

The project performs two levels of validation.

### Pre-deployment validation

Ansible checks the source-of-truth data for issues such as:

- Incorrect underlay interface counts
- Duplicate loopback addresses
- Duplicate underlay addresses
- Invalid tenant VLAN/VNI, host addresses or duplicate host identities
- Incorrect VTEP sources or host attachments that overlap underlay ports

### Runtime validation

After the virtual fabric is deployed, Ansible verifies:

- The exact inventory-defined BGP neighbors are established with the expected
  remote ASNs
- All four loopback prefixes are present in each BGP table
- Remote loopbacks are installed in each router's Linux routing table
- Loopback-sourced reachability succeeds between peer-role nodes
- EVPN neighbors establish and Type-3 routes retain the leaf VTEP next hops
- Type-2 MAC/IP bindings exist for both hosts on every router
- Leaf VNI, bridge, access port and externally learned neighbor state is correct
- Both hosts can ping each other through their tenant interfaces

## Prerequisites

- Python 3.12 with virtual environment support
- Docker installed and running
- Containerlab installed with permission to deploy and destroy labs
- GNU Make

Activate the project's `.venv` before running the workflow so the expected
Python/Ansible environment is used.
Your user must be able to run Docker commands.

## Setup

1. Clone the repository and open its directory (or open your existing checkout):

   ```bash
   git clone https://github.com/brendanharry/network-automation-lab.git
   cd network-automation-lab
   ```

2. Create `.venv` if needed, activate it, and install the project Python tools:

   ```bash
   python3.12 -m venv .venv
   source .venv/bin/activate
   python -m pip install -r requirements.txt
   ```

3. Verify the required tools from the activated environment:

   ```bash
   python --version
   ansible-playbook --version
   docker info
   containerlab version
   make --version
   ```

## Tested Environment

The current dependency pins and workflow were tested with:

- Ubuntu 24.04.1 LTS running under WSL2
- Python 3.12.3
- Ansible Core 2.21.3
- yamllint 1.38.0
- Docker 29.1.3
- Containerlab 0.77.0
- FRRouting container image `quay.io/frrouting/frr:10.7.0`
- Test host image `alpine:3.22.5`

Python dependencies are installed from `requirements.txt`. Docker and
Containerlab remain host-level prerequisites and are not installed by pip.

## Running the Lab

A Makefile provides the build, validation, deployment, test, and cleanup
workflow. Run `make help` for a summary of the available targets.

Generate router configurations and the Containerlab topology:

```bash
make build
```

Validate the topology data:

```bash
make validate
```

Deploy the virtual fabric and configure Linux overlay interfaces with Ansible:

```bash
make deploy
```

Run live network validation:

```bash
make test
```

Destroy the lab:

```bash
make destroy
```

## Verification

Run the complete workflow end-to-end from the activated `.venv`:

```bash
make verify
```

`make verify` generates FRR configurations, validates the topology data,
deploys the fabric with Containerlab, and runs live BGP session, loopback route,
Linux route, EVPN/VXLAN, and bidirectional host connectivity validation. After
a successful run, it destroys the lab. If an earlier stage fails, Make stops; if deployment has already
occurred, the lab may remain running for inspection. Run `make destroy` after
troubleshooting to clean it up.

### Expected Result

A successful run ends with an Ansible recap showing `failed=0`, followed by
Containerlab teardown. Example (abridged):

```text
PLAY RECAP
localhost : ok=6 changed=0 unreachable=0 failed=0
...
Destroying lab: fabric
...
Successfully destroyed lab fabric
```

## Troubleshooting

Use `make validate` to isolate source-of-truth errors, `make deploy` to create
or reconfigure the fabric, and `make test` to rerun runtime checks without
rebuilding the lab. Useful first checks for a deployed fabric are:

```bash
docker ps
containerlab inspect -t lab/fabric.clab.yml
docker exec clab-fabric-leaf01 vtysh -c "show bgp summary"
```

The Ansible assertion output identifies the affected router and includes FRR
JSON output for failed BGP checks. Use `make destroy` for manual cleanup when
investigation is complete.

## Generated Configurations

Files under `configs/` and `lab/fabric.clab.yml` are generated artifacts derived
from the YAML inventory and Jinja2 templates; they are committed so changes are
reviewable. GitHub Actions regenerates them and fails if the result differs from the committed
files. After changing inventory or templates, run `make build` and include the
resulting configuration changes in the same commit.

## v1.0 Scope

The original v1.0.0 release established the IPv4 eBGP underlay. Phase 1 adds
the L2 overlay below while retaining its addressing, ASNs, loopbacks, and
runtime validation. Production AAA, secrets handling, and production routing
policy remain outside the lab scope. Validation is purpose-built for this
topology rather than a generic fabric test framework.

## Phase 1 EVPN/VXLAN overlay

The IPv4 **underlay** routes between loopbacks across the original /31 links.
The **overlay** carries tenant Ethernet frames inside VXLAN between the two
leaf loopbacks. The existing eBGP sessions carry both IPv4 unicast and L2VPN
EVPN; no additional BGP sessions or ASNs are introduced.

| Router | ASN | Loopback | Overlay role |
| --- | --- | --- | --- |
| leaf01 | 65101 | 10.255.0.11 | VTEP |
| leaf02 | 65102 | 10.255.0.12 | VTEP |
| spine01 | 65001 | 10.255.0.21 | EVPN route exchange only |
| spine02 | 65002 | 10.255.0.22 | EVPN route exchange only |

| Host | Tenant IP | MAC | Attachment |
| --- | --- | --- | --- |
| host01 | 192.168.10.11/24 | 02:00:00:00:10:01 | eth1 to leaf01 swp3 |
| host02 | 192.168.10.12/24 | 02:00:00:00:10:02 | eth1 to leaf02 swp3 |

`inventories/lab/group_vars/all.yml` defines the single segment: **VLAN 10 →
VNI 10100**, subnet `192.168.10.0/24`, and tenant MTU 1500. Leaf VTEP sources
reference existing `loopback_ip` values. Host inventory defines attachments and
addresses; the prefix length comes from the tenant subnet. The topology is
now generated from the same inventory, including the unchanged underlay links.

Leaves enable `advertise-all-vni` and share the explicit import/export route
target `65000:10100`. The shared `evpn_rt_admin: 65000` in
`inventories/lab/group_vars/all.yml` supplies the fixed 16-bit administrator;
the VNI supplies the 32-bit assigned number. Thus VNI 101000 produces
`65000:101000`, and the full valid VNI range (1–16777215) remains representable.
This administrator is an RT namespace, not a new router ASN. Route
distinguishers remain FRR-generated (observed as `10.255.0.11:2` and
`10.255.0.12:2`); their assigned values are independent of the VNI. The explicit shared
RT avoids differing leaf ASNs producing different export RTs. Spines preserve
EVPN next hops with `attribute-unchanged next-hop`, so remote traffic goes to
the originating leaf, not a spine. IPv4 next-hop behavior remains unchanged.

### Linux implementation

`make deploy` runs `playbooks/configure_overlay.yml` after Containerlab:

- Each leaf gets one traditional, VLAN-unaware bridge `br10` representing the
  VLAN 10 access broadcast domain, with untagged `swp3` attached.
- `vxlan10100` joins that bridge, uses the leaf loopback as its local address,
  and encapsulates with UDP port 4789. No static remote VTEP is configured.
- VXLAN learning and bridge-port learning on the VXLAN port are disabled;
  FRR/Zebra installs remote MACs and VTEP membership learned through EVPN.
  Host-facing MAC learning remains enabled. ARP suppression is enabled on the
  VXLAN bridge port.
- The bridge has no gateway IP. IPv4/IPv6 forwarding and IPv6 address generation
  are disabled there. `arp_accept=1` lets gratuitous ARP populate dynamic host
  IP/MAC bindings on the unnumbered bridge.
- Hosts receive deterministic MAC/IP addresses. `make test` sends gratuitous
  ARP before checking Type-2 IP bindings and pinging in both directions.

This follows FRR's [traditional bridge/VXLAN integration model](https://docs.frrouting.org/en/stable-10.7/evpn.html).
There are no 802.1Q trunks: VLAN 10 is represented by its dedicated bridge.
FRR may report the bridge's internal/default VLAN as `1`; this is not a second
tenant or the configured VNI. A VLAN-aware bridge would be a separate extension
for multiple VLANs. The host MTU is 1500; the existing Containerlab underlay
links retain their 9500-byte MTU, leaving room for VXLAN overhead.

Linux state is ephemeral and recreated on deployment. The setup playbook can
be rerun for the current inventory, but reports applied settings as changed;
use `make deploy` to recreate interfaces after changing VNI or VTEP data.
Calling Containerlab directly does not run the Ansible setup step.

### Inspecting the overlay

Run `make build`, `make validate`, `make deploy`, then `make test`, or use the
complete `make verify` workflow (which tears down the lab after success).
While deployed:

```bash
docker exec clab-fabric-leaf01 vtysh -c "show bgp l2vpn evpn summary"
docker exec clab-fabric-leaf01 vtysh -c "show bgp l2vpn evpn route"
docker exec clab-fabric-leaf01 vtysh -c "show evpn vni 10100 json"
docker exec clab-fabric-leaf01 vtysh -c "show evpn mac vni 10100 json"
docker exec clab-fabric-leaf01 ip -d -j link show dev vxlan10100
docker exec clab-fabric-leaf01 ip -j neigh show dev br10
docker exec clab-fabric-host01 ping -I eth1 -c 3 192.168.10.12
docker exec clab-fabric-host02 ping -I eth1 -c 3 192.168.10.11
```

Expected EVPN routes after host learning:

- Type-3 IMET: `[3]:[0]:[32]:[10.255.0.11]` and
  `[3]:[0]:[32]:[10.255.0.12]`, advertising both VTEPs' membership.
- Type-2: MAC-only routes for each host, plus
  `[2]:[0]:[48]:[02:00:00:00:10:01]:[32]:[192.168.10.11]` and
  `[2]:[0]:[48]:[02:00:00:00:10:02]:[32]:[192.168.10.12]`.
- Each leaf has both spine paths to remote EVPN routes, with the remote leaf
  loopback as next hop. Each spine exchanges routes without a local VXLAN VNI.

The runtime assertions use FRR and Linux JSON with bounded convergence retries.
Traffic is bound to host `eth1` so management networking cannot satisfy the
connectivity checks. Gratuitous ARP refreshes IP bindings for repeatable tests;
these are dynamically learned entries and can age out in an idle lab.
There is no Type-5 export, L3 VNI, tenant gateway, or inter-VLAN routing.

## Technologies

- Git and GitHub
- GitHub Actions
- YAML
- Ansible
- Jinja2
- Docker
- Containerlab
- FRRouting (FRR)
- eBGP
- Linux

## Repository Structure

```text
.
├── .github/workflows/       GitHub Actions CI
├── configs/                 Generated FRR configurations
├── inventories/lab/         Network source of truth
├── lab/                     Generated Containerlab topology and FRR lab files
├── playbooks/               Ansible automation and validation
├── templates/               Jinja2 configuration templates
├── Makefile                 Repeatable lab workflow
├── requirements.txt         Pinned project Python tools
└── README.md
```
