# Network Automation Lab

A reproducible network automation project that builds and validates a four-node
leaf-spine eBGP fabric using Ansible, Jinja2, FRRouting, Containerlab, Docker,
Git, and GitHub Actions.

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
Generated FRR configurations
        ↓
Containerlab / Docker
        ↓
Running four-node fabric
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

### Runtime validation

After the virtual fabric is deployed, Ansible verifies:

- The exact inventory-defined BGP neighbors are established with the expected
  remote ASNs
- All four loopback prefixes are present in each BGP table
- Remote loopbacks are installed in each router's Linux routing table
- Loopback-sourced reachability succeeds between peer-role nodes

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

Python dependencies are installed from `requirements.txt`. Docker and
Containerlab remain host-level prerequisites and are not installed by pip.

## Running the Lab

A Makefile provides the build, validation, deployment, test, and cleanup
workflow. Run `make help` for a summary of the available targets.

Generate router configurations:

```bash
make build
```

Validate the topology data:

```bash
make validate
```

Deploy the virtual fabric:

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
Linux route, and connectivity validation. After a successful run, it destroys
the lab. If an earlier stage fails, Make stops; if deployment has already
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

Files under `configs/` are generated artifacts derived from the YAML inventory
and `templates/bgp.j2`; they are committed so changes are reviewable. GitHub
Actions regenerates them and fails if the result differs from the committed
files. After changing inventory or templates, run `make build` and include the
resulting configuration changes in the same commit.

## v1.0 Scope

This release deliberately focuses on an IPv4, eBGP-only underlay in a
Containerlab/FRR environment. It does not include an EVPN/VXLAN overlay,
production AAA or secrets handling, or production import/export policy. Runtime
validation is purpose-built for this four-node topology rather than a generic
fabric test framework.

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
├── lab/                     Containerlab and FRR lab files
├── playbooks/               Ansible automation and validation
├── templates/               Jinja2 configuration templates
├── Makefile                 Repeatable lab workflow
├── requirements.txt         Pinned project Python tools
└── README.md
```
