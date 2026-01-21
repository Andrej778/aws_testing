# Terraform deployment script for Windows PowerShell

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("init", "plan", "apply", "destroy", "fmt", "validate", "clean")]
    [string]$Command = "help"
)

function Show-Help {
    Write-Host "Terraform Deployment Script" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 -Command <command>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available commands:"
    Write-Host "  init     - Initialize Terraform"
    Write-Host "  plan     - Show Terraform plan"
    Write-Host "  apply    - Apply Terraform configuration"
    Write-Host "  destroy  - Destroy Terraform resources"
    Write-Host "  fmt      - Format Terraform files"
    Write-Host "  validate - Validate Terraform configuration"
    Write-Host "  clean    - Clean Terraform files and cache"
}

function Invoke-TerraformCommand {
    param([string]$TfCommand)
    
    Push-Location ".\terraform"
    try {
        switch ($TfCommand) {
            "init" {
                Write-Host "Initializing Terraform..." -ForegroundColor Cyan
                terraform init
            }
            "plan" {
                Write-Host "Creating Terraform plan..." -ForegroundColor Cyan
                terraform plan -out=tfplan
            }
            "apply" {
                Write-Host "Applying Terraform configuration..." -ForegroundColor Cyan
                terraform apply tfplan
            }
            "destroy" {
                Write-Host "Destroying Terraform resources..." -ForegroundColor Cyan
                terraform destroy
            }
            "fmt" {
                Write-Host "Formatting Terraform files..." -ForegroundColor Cyan
                terraform fmt -recursive
            }
            "validate" {
                Write-Host "Validating Terraform configuration..." -ForegroundColor Cyan
                terraform validate
            }
            "clean" {
                Write-Host "Cleaning Terraform files..." -ForegroundColor Cyan
                Remove-Item -Path ".terraform" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path ".terraform.lock.hcl" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "tfplan" -Force -ErrorAction SilentlyContinue
                Write-Host "Clean complete" -ForegroundColor Green
            }
        }
    }
    finally {
        Pop-Location
    }
}

if ($Command -eq "help") {
    Show-Help
} else {
    Invoke-TerraformCommand -TfCommand $Command
}
