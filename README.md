# Network Automation Lab

A reproducible network automation project that builds and validates a four-router
leaf-spine eBGP fabric with Layer-2 and routed EVPN/VXLAN overlays using Ansible, Jinja2,
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
- Three Linux test hosts across VLANs 10 and 20
- EVPN Type-2 host bindings, Type-3 membership, and Type-5 prefixes
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
Running four-router fabric with three test hosts
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
- All hosts can ping each other and their local gateway through tenant interfaces
- Type-5 prefixes carry the L3 RT and originating VTEP/router MAC
- Tenant VRF, L3 VNI, SVI gateways, MACs and interface memberships are correct
- The remote VLAN 20 prefix is installed in both FRR and the Linux tenant FIB

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

### Single-link resilience validation

Run `make resilience` from the activated `.venv` to build, validate, deploy,
check the baseline, inject a failure, prove degraded service, restore the link,
check full recovery, and destroy the lab after success. Normal `make test` and
`make verify` remain steady-state workflows.

The failure is `docker exec clab-fabric-leaf01 ip link set dev swp1 down`,
affecting only `leaf01:swp1 <-> spine01:swp1`. The test checks both ends leave
Established while every unaffected inventory-defined BGP/EVPN peer stays
Established. Leaf01 must forward to the remote VTEP through spine02 on swp2.
Existing validation checks Type-2/3/5 EVPN state, tenant RIB/FIB state, and
bidirectional host pings, including host01–host02 same-subnet VXLAN and
host01–host03 routed EVPN connectivity, while the link is down.

An Ansible `always` block restores swp1, with bounded retries, even when a
failure-stage assertion fails; the original failure still fails the playbook.
Full baseline validation then proves recovery using bounded convergence polling.
Restoration is best effort: loss of Docker access or interruption of Ansible
can prevent cleanup. Logs identify BASELINE, FAILURE, and RECOVERY evidence.
This tests the usefulness of dual leaf-to-spine paths under a single-link
failure; it does not test uninterrupted packet delivery during convergence.

For troubleshooting against an already deployed lab, retain the containers:

```bash
ansible-playbook -i inventories/lab/hosts.yml playbooks/validate_resilience.yml
```

A failed lifecycle run leaves the lab available for inspection after attempted
link restoration. Use `make destroy` when finished.

### Single-spine resilience validation

Run the opt-in scenario from the activated `.venv`:

```bash
make resilience-spine
```

This uses the same build, validate, deploy, baseline, failure, recovery, and
successful teardown lifecycle as `make resilience`. It isolates all fabric
ports on `clab-fabric-spine01` (`swp1` and `swp2`) with `ip link set ... down`,
then runs `docker pause clab-fabric-spine01`. Both port states and the container
pause state are asserted. Pausing alone leaves Linux forwarding active;
isolating both ports makes the entire spine unavailable to the fabric. Keeping
the container namespace avoids losing Containerlab veth links on stop/start.
Inventory, topology, and routing configuration are unchanged.

During failure, both leaves' spine01 IPv4/EVPN peers must leave Established.
Both leaves' spine02 peers and both leaf peers on spine02 must remain
Established with the expected ASNs. Both leaf VTEP route lookups must use
spine02, and loopback-sourced pings check the surviving underlay. Existing
validation runs on all surviving routers and hosts, retaining Type-2/3/5,
tenant VRF, L3 VNI, required tenant RIB/FIB routes, and all directed host pings.
This includes host01 ↔ host02 same-subnet VXLAN and host01 ↔ host03 routed EVPN
with traffic bound to the tenant interface.

An Ansible `always` block unpauses spine01 when necessary and restores both
ports with bounded retries, including after partial injection or assertion
failure. A nested `always` attempts port restoration even if container
restoration fails. The original test failure still fails the playbook.
Recovery checks running/unpaused container state, both ports, all four
leaf/spine adjacencies, complete underlay routes, EVPN Type-2/3/5 state,
tenant forwarding state, and bidirectional host connectivity using the full
bounded steady-state checks. Both resilience scenarios automatically restore
their failed component; restoration is best effort if Docker access is lost
or Ansible is interrupted. No arbitrary recovery sleep is used.

To retain an already deployed lab for inspection:

```bash
ansible-playbook -i inventories/lab/hosts.yml playbooks/validate_resilience_spine.yml
```

A failed lifecycle leaves the lab after attempted restoration; use
`make destroy` after inspection. These are single-component resilience tests,
not full HA testing, physical power-loss emulation, or production convergence
benchmarks. Simultaneous failures, leaf/host failures, and packet-loss
measurement during convergence remain outside these scenarios.

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
| host03 | 192.168.20.21/24 | 02:00:00:00:20:03 | eth1 to leaf02 swp4 |

`inventories/lab/group_vars/all.yml` defines tenant and segment data. Leaf VTEP
sources reference existing `loopback_ip` values. Host inventory references a
segment and defines its attachment, MAC, and address. The topology is generated
from that inventory, including the unchanged underlay links.

Leaves enable `advertise-all-vni` and share the explicit import/export route
target `65000:10100`. The shared `evpn_rt_admin: 65000` in
`inventories/lab/group_vars/all.yml` supplies the fixed 16-bit administrator;
the VNI supplies the 32-bit assigned number. Thus VNI 101000 produces
`65000:101000`, and the full valid VNI range (1–16777215) remains representable.
This administrator is an RT namespace, not a new router ASN. Route
distinguishers remain FRR-generated; their assigned values are independent of
the VNI. The explicit shared
RT avoids differing leaf ASNs producing different export RTs. Spines preserve
EVPN next hops with `attribute-unchanged next-hop`, so remote traffic goes to
the originating leaf, not a spine. IPv4 next-hop behavior remains unchanged.

### Linux implementation

`make deploy` runs `playbooks/configure_overlay.yml` after Containerlab:

- Each leaf gets one traditional, VLAN-unaware bridge `br10` representing the
  VLAN 10 access broadcast domain, with untagged `swp3` attached. Phase 2
  adds `br20` / `vxlan10200` and untagged `swp4` on leaf02.
- `vxlan10100` joins that bridge, uses the leaf loopback as its local address,
  and encapsulates with UDP port 4789. No static remote VTEP is configured.
- VXLAN learning and bridge-port learning on the VXLAN port are disabled;
  FRR/Zebra installs remote MACs and VTEP membership learned through EVPN.
  Host-facing MAC learning remains enabled. ARP suppression is enabled on the
  VXLAN bridge port.
- Phase 1 used unnumbered bridges with routing disabled. Phase 2 places the
  L2 bridges in `tenant-a`, assigns gateways, and enables IPv4 forwarding.
  IPv6 remains disabled. `arp_accept=1` retains gratuitous ARP host learning.
- Hosts receive deterministic MAC/IP addresses. `make test` sends gratuitous
  ARP before checking Type-2 IP bindings and pinging in both directions.

This follows FRR's [traditional bridge/VXLAN integration model](https://docs.frrouting.org/en/stable-10.7/evpn.html).
There are no 802.1Q trunks: VLAN 10 is represented by its dedicated bridge.
FRR may report the bridge's internal/default VLAN as `1`; this is not a second
tenant or the configured VNI. Phase 2 retains a separate traditional bridge for each local segment. The host MTU is 1500; the existing Containerlab underlay
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
Phase 2 adds the routed overlay below.

## Phase 2 routed EVPN/VXLAN

One tenant, `tenant-a`, uses Linux VRF table 10000 and **L3 VNI 10000**.

| Segment | L2 VNI | Subnet | Gateway | Leaves | RT |
| --- | --- | --- | --- | --- | --- |
| VLAN 10 | 10100 | 192.168.10.0/24 | 192.168.10.1/24 | Both | 65000:10100 |
| VLAN 20 | 10200 | 192.168.20.0/24 | 192.168.20.1/24 | leaf02 | 65000:10200 |

The L3 import/export RT is `65000:10000`: L2 RTs select Ethernet broadcast
domains, while this RT selects tenant IP routes. All use the existing fixed
16-bit RT administrator and support the full valid VNI range. FRR generates
unique per-VTEP/per-instance RDs independently of VNI values.

`make deploy` creates kernel interfaces; FRR discovers them through Netlink.
Each local L2 bridge acts as its segment SVI and belongs to `tenant-a`.
The SVI gateway MAC `02:00:00:00:00:01` is defined once and shared: VLAN 10
hosts resolve the same default gateway IP/MAC on either leaf, allowing local
routing. Gateway bindings are not advertised with `advertise-svi-ip`.
`br10000` also belongs to the VRF, remains unnumbered, and holds `vxlan10000`.
Its router MAC is unique per leaf, distinct from the shared gateway MAC.
VXLAN uses loopback sources, UDP 4789, disabled dynamic tunnel learning,
and Zebra-programmed remote forwarding state. IPv4 forwarding is enabled;
IPv6 and reverse-path filtering on tenant SVIs are disabled.

FRR associates the VRF with L3 VNI 10000 and runs a tenant BGP instance.
Explicit `network` statements originate only locally connected segment
prefixes; `advertise ipv4 unicast` exports them as genuine **Type-5** routes.
There are no extra BGP sessions: the original eBGP EVPN sessions and spines
carry them with their originating leaf next hops. No tenants leak routes.

Same-subnet host01 ↔ host02 traffic remains bridged through L2 VNI 10100.
For host01 → host03, leaf01 routes at its local gateway, looks up the tenant
route, and sends a routed Ethernet frame to leaf02 through L3 VNI 10000.
Leaf02 routes again into VLAN 20. These two tenant routing lookups are
**symmetric IRB**. EVPN Type-2 imported /32 host routes can take precedence in
either direction through the L3 VNI; Type-5 supplies installed /24 subnet
reachability rather than replacing Type-2 host routing.

VLAN 20 is deliberately instantiated only on leaf02. Leaf01 therefore has no
connected VLAN 20 route or L2 VNI 10200, making its remote /24 installation
and host03 traffic evidence of routed EVPN. VLAN 10 is distributed on both
leaves; its shared /24 remains connected on each leaf, so the remote Type-5
copy is visible in EVPN but cannot displace that connected route.

`make test` retains underlay, Type-2/Type-3, VLAN 10 MAC/neighbor, and both
same-subnet ping checks. It adds prefix/VTEP/router-MAC/L3-RT assertions,
VRF/L3-VNI/SVI checks, FRR and kernel remote-prefix installation, gateway
pings, and all directed host pairs (including host01 ↔ host03). Host pings
use `eth1` and full 1500-byte IP packets; convergence retries are bounded.
The former Phase 1 assertions that routing was disabled, bridges were
unnumbered, and no Type-5 existed are replaced by the corresponding Phase 2
routing assertions. All Phase 1 traffic and control-plane checks remain.

While deployed, inspect the routed overlay with:

```bash
docker exec clab-fabric-leaf01 vtysh -c "show evpn vni 10000 json"
docker exec clab-fabric-leaf01 vtysh -c "show bgp l2vpn evpn route type prefix json"
docker exec clab-fabric-leaf01 vtysh -c "show ip route vrf tenant-a json"
docker exec clab-fabric-leaf01 ip -j route show vrf tenant-a
docker exec clab-fabric-host01 ping -I eth1 -c 3 192.168.20.21
docker exec clab-fabric-host03 ping -I eth1 -c 3 192.168.10.11
```

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
