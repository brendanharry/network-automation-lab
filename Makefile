.PHONY: help build validate deploy test destroy verify

help:
	@echo "Available targets:"
	@echo "  build     Generate FRR configurations and topology from inventory"
	@echo "  validate  Validate topology and addressing data"
	@echo "  deploy    Deploy or reconfigure the Containerlab fabric"
	@echo "  test      Validate the running fabric"
	@echo "  destroy   Destroy the Containerlab fabric"
	@echo "  verify    Run build, validate, deploy, test, and destroy"

build:
	ansible-playbook -i inventories/lab/hosts.yml playbooks/build_configs.yml

validate:
	ansible-playbook -i inventories/lab/hosts.yml playbooks/validate_topology.yml

deploy:
	containerlab deploy -t lab/fabric.clab.yml --reconfigure
	ansible-playbook -i inventories/lab/hosts.yml playbooks/configure_overlay.yml

test:
	ansible-playbook -i inventories/lab/hosts.yml playbooks/validate_runtime.yml
	ansible-playbook -i inventories/lab/hosts.yml playbooks/validate_overlay.yml

destroy:
	containerlab destroy -t lab/fabric.clab.yml

verify:
	$(MAKE) build
	$(MAKE) validate
	$(MAKE) deploy
	$(MAKE) test
	$(MAKE) destroy
