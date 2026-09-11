.PHONY: build validate deploy test destroy verify

build:
	ansible-playbook -i inventories/lab/hosts.yml playbooks/build_configs.yml

validate:
	ansible-playbook -i inventories/lab/hosts.yml playbooks/validate_topology.yml

deploy:
	containerlab deploy -t lab/fabric.clab.yml --reconfigure

test:
	ansible-playbook playbooks/validate_runtime.yml

destroy:
	containerlab destroy -t lab/fabric.clab.yml

verify:
	$(MAKE) build
	$(MAKE) validate
	$(MAKE) deploy
	$(MAKE) test
	$(MAKE) destroy
