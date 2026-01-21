.PHONY: help init plan apply destroy fmt validate clean

help:
	@echo "Available commands:"
	@echo "  make init       - Initialize Terraform"
	@echo "  make plan       - Show Terraform plan"
	@echo "  make apply      - Apply Terraform configuration"
	@echo "  make destroy    - Destroy Terraform resources"
	@echo "  make fmt        - Format Terraform files"
	@echo "  make validate   - Validate Terraform configuration"
	@echo "  make clean      - Clean Terraform files and cache"

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan -out=tfplan

apply:
	cd terraform && terraform apply tfplan

destroy:
	cd terraform && terraform destroy

fmt:
	cd terraform && terraform fmt -recursive

validate:
	cd terraform && terraform validate

clean:
	cd terraform && rm -rf .terraform .terraform.lock.hcl tfplan
