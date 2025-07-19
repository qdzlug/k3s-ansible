# Makefile for k3s-ansible Infra/Deployment
#
SHELL = /bin/bash


project_name := $(shell grep '^project_name' infra/oxide/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')
vpc_name       := $(shell grep '^vpc_name' infra/oxide/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')
instance_count := $(shell grep '^instance_count' infra/oxide/terraform.tfvars | sed 's/.*= *\([0-9]*\).*/\1/')
k3s_version    := $(shell grep '^k3s_version' infra/oxide/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')
ansible_user   := $(shell grep '^ansible_user' infra/oxide/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')
k3s_token      := $(shell grep '^k3s_token' infra/oxide/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')


# Default target: show help
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  validate        - Validate Terraform configuration"
	@echo "  show-vars       - Display project variables"
	@echo "  infra-up        - Stand up the infrastructure using Terraform and wait for hosts to respond to ansible-ping"
	@echo "  deploy          - Deploy the environment using Ansible"
	@echo "  fix-kubeconfig  - Fix the kubeconfig file to use external IP"
	@echo "  check           - Run kubectl commands to check the cluster status"
	@echo "  destroy         - Destroy the infrastructure using Terraform"
	@echo "  lint            - Run linting on Terraform and Ansible files"
	@echo "  full-deploy     - Run validate, infra-up, deploy, fix-kubeconfig, and check in order"


venv:
	@test -d $(VENV) || { \
		echo "Creating venv in $(VENV)"; \
		python3 -m venv $(VENV) && \
		$(VENV)/bin/pip install -U pip && \
		$(VENV)/bin/pip install -r requirements.txt && \
		$(VENV)/bin/ansible-galaxy collection install -r collections/requirements.yml || true; \
	}

# Validate Terraform configuration
.PHONY: validate
validate:
	@echo "Validating Terraform configuration in infra/oxide..."
	cd infra/oxide && tofu validate

# Show project variables (customize as needed)
.PHONY: show-vars
show-vars:
	@set +H; \
	echo "Project Variables:"; \
	echo "  project_name: $(project_name)"; \
	echo "  vpc_name: $(vpc_name)"; \
	echo "  instance_count: $(instance_count)"; \
	echo "  k3s_version: $(k3s_version)"; \
	echo "  ansible_user: $(ansible_user)"; \
	echo "  k3s_token: $(k3s_token)"; \

# Stand up the infrastructure with Terraform and wait for ansible-ping to succeed
.PHONY: infra-up
infra-up:
	@echo "Initializing and applying Terraform configuration..."
	cd infra/oxide && tofu init && tofu apply -auto-approve
	@echo "Waiting for all hosts to respond to ansible-ping..."
	@until ansible all -m ping -i inventory.yml; do \
	  echo "Hosts not reachable yet, waiting 10 seconds..."; \
	  sleep 10; \
	done
	@echo "All hosts are reachable."

# Deploy the environment using Ansible
.PHONY: deploy
deploy:
	@echo "Deploying environment with Ansible..."
	ansible-playbook playbooks/site.yml -i inventory.yml

# Fix the kubeconfig file to use external IP for remote access
.PHONY: fix-kubeconfig
fix-kubeconfig:
	@echo "Fixing kubeconfig to use external IP..."
	ansible-playbook infra/oxide/fix-kubeconfig.yml -i inventory.yml

# Check that the infrastructure is up using kubectl commands
.PHONY: longhorn
longhorn:
	@echo "Deploying Longhorn..."
	$(ANSIBLE) playbooks/longhorn.yml -i inventory.yml

.PHONY: check
check:
	@echo "Checking cluster nodes..."
	kubectl get nodes
	@echo "Checking pods in all namespaces..."
	kubectl get pods --all-namespaces

# Destroy the infrastructure using Terraform
.PHONY: destroy
destroy:
	@echo "Destroying infrastructure with Terraform..."
	cd infra/oxide && tofu destroy -auto-approve

# Lint Terraform and Ansible files
.PHONY: lint
lint:
	@echo "Formatting Terraform files..."
	cd infra/oxide && tofu fmt -recursive
	@echo "Checking Terraform file formatting..."
	tofu fmt -check -recursive infra/oxide
	@echo "Linting Ansible playbooks..."
	ansible-lint playbooks/

# Full deployment: validate, infra-up, deploy, fix-kubeconfig, and check (in order)
full-deploy: validate infra-up deploy fix-kubeconfig check
	@echo "Full deployment complete!"
