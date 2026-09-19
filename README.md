# Network Automation Lab

A hands-on network automation project that builds and validates a four-node
leaf-spine eBGP fabric using Ansible, Jinja2, FRRouting, Containerlab, Docker,
Git, and GitHub Actions.

## Project Overview

This lab uses a YAML-based source of truth to define a small data-centre
network. Ansible and Jinja2 generate FRR router configurations, Containerlab
deploys the virtual topology, and automated validation checks both the
configuration data and the running network.

The lab currently consists of:

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

- Two BGP sessions are established on each router
- All four loopback prefixes are present in each BGP table
- End-to-end loopback reachability succeeds

## Prerequisites

- Python 3.12  with virtual environment support
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

A Makefile provides a simple workflow for building, validating, deploying, testing, and destroying the lab.

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
and ping validation. After a successful run, it destroys the lab. If a validation
stage fails, Make stops and leaves the lab running so it can be troubleshot.

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

## Current Status

The project can currently generate, validate, deploy, test, and destroy a four-node eBGP leaf-spine fabric using a repeatable automation workflow.
