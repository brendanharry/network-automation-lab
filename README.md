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

Run the complete workflow end-to-end:

```bash
make verify
```

`make verify` performs configuration generation, topology validation, lab deployment, runtime testing, and clean teardown.

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
└── README.md
```

## Current Status

The project can currently generate, validate, deploy, test, and destroy a four-node eBGP leaf-spine fabric using a repeatable automation workflow.
