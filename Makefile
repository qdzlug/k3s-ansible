# Makefile for k3s-ansible Infra/Deployment

# Default target: show help
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  validate        - Validate Terraform configuration"
	@echo "  show-vars       - Display project variables"
	@echo "  infra-up        - Stand up the infrastructure using Terraform"
	@echo "  deploy          - Deploy the environment using Ansible"
	@echo "  fix-kubeconfig  - Fix the kubeconfig file to use the external IP"
	@echo "  check           - Run kubectl commands to check the cluster status"
	@echo "  destroy         - Destroy the infrastructure using Terraform"
	@echo "  lint            - (Optional) Run linting on Terraform and Ansible files"
	@echo "  env-check       - (Optional) Validate that necessary env variables are set"
	@echo "  full-deploy     - Run validate, infra-up, deploy, fix-kubeconfig, and check in order"

# Validate that the Terraform configuration is correct
.PHONY: validate
validate:
	@echo "Validating Terraform configuration in infra/oxide..."
	cd infra/oxide && tofu validate

# Show project variables (customize as needed)
.PHONY: show-vars
show-vars:
	@echo "Project Variables:"
	@echo "  project_name: $(project_name)"
	@echo "  vpc_name: $(vpc_name)"
	@echo "  instance_count: $(instance_count)"
	@echo "  k3s_version: $(k3s_version)"
	@echo "  ansible_user: $(ansible_user)"
	@echo "  k3s_token: $(k3s_token)"

# Stand up the infrastructure with Terraform
.PHONY: infra-up
infra-up:
	@echo "Initializing and applying Terraform configuration..."
	cd infra/oxide && tofu init && tofu apply -auto-approve

# Deploy the environment using Ansible
.PHONY: deploy
deploy:
	@echo "Deploying environment with Ansible..."
	ansible-playbook playbooks/site.yml -i inventory.yml

# Fix the kubeconfig file to use external IP
.PHONY: fix-kubeconfig
fix-kubeconfig:
	@echo "Fixing kubeconfig to use external IP..."
	ansible-playbook infra/oxide/fix-kubeconfig.yml -i inventory.yml

# Check that the infrastructure is up using kubectl commands
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

# Optional: Linting for Terraform and Ansible
.PHONY: lint
lint:
	@echo "Formatting Terraform files..."
	cd infra/oxide && tofu fmt -recursive
	@echo "Linting Terraform files..."
	tofu fmt -check -recursive infra/oxide
	@echo "Linting Ansible playbooks..."
	ansible-lint playbooks/

.PHONY: env-check
env-check:
	@echo "Checking environment variables..."
	@if [ -z "$$OXIDE_HOST" ]; then \
		echo "Error: OXIDE_HOST is not set"; exit 1; \
	else \
		echo "OXIDE_HOST: $$OXIDE_HOST"; \
	fi
	@if [ -z "$$OXIDE_TOKEN" ]; then \
		echo "Error: OXIDE_TOKEN is not set"; exit 1; \
	else \
		echo "OXIDE_TOKEN (first 5 chars): $$(echo $$OXIDE_TOKEN | cut -c1-5)"; \
	fi


# Full deployment: validate, infra-up, deploy, fix-kubeconfig, and check in sequence.
.PHONY: full-deploy
full-deploy: validate infra-up deploy fix-kubeconfig check
	@echo "Full deployment complete!"
