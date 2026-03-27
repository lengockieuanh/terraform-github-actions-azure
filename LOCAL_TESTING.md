# 🧪 Local Testing Guide

Hướng dẫn test Terraform trước khi deploy lên GitHub Actions.

## 📋 Yêu cầu

- Terraform >= 1.0
- Azure CLI (`az` command)
- Valid Azure subscription
- Azure credentials configured

## 🔧 Setup Azure Credentials Locally

### Cách 1: Azure CLI (Recommended)

```bash
# Login to Azure
az login

# Set default subscription (optional)
az account set --subscription "Subscription Name"

# Verify
az account show
```

### Cách 2: Service Principal (CI/CD)

```bash
# Set environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Verify
az login \
  --service-principal \
  -u $ARM_CLIENT_ID \
  -p $ARM_CLIENT_SECRET \
  --tenant $ARM_TENANT_ID

az account show
```

## 🚀 Local Terraform Workflow

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

**Output:**
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully configured!
```

### Step 2: Format Check

```bash
terraform fmt -check -recursive
```

Hoặc auto-format:
```bash
terraform fmt -recursive
```

### Step 3: Validate

```bash
terraform validate
```

**Output:**
```
Success! The configuration is valid.
```

### Step 4: Run Checkov Security Scan

```bash
# Install Checkov (if not installed)
pip install checkov

# Run security scan
checkov -d . --framework terraform

# Generate report
checkov -d . \
  --framework terraform \
  --output cli \
  --output junitxml=checkov-report.xml
```

**Fix Checkov Issues (nếu có):**
- Xem chi tiết trong report
- Edit `main.tf` để fix issues
- Chạy lại Checkov

### Step 5: Plan Deployment

```bash
terraform plan -out=tfplan
```

**Output sẽ show:**
- Resources to create
- Resource properties
- Variable values

Kiểm tra kỹ plan trước khi apply!

### Step 6: Review Plan

```bash
# Show plan in readable format
terraform show tfplan

# Show in JSON format
terraform show -json tfplan > tfplan.json
```

### Step 7: Apply (Only if plan looks good!)

```bash
# Option 1: Apply with auto-approve (development only)
terraform apply -auto-approve tfplan

# Option 2: Interactive apply
terraform apply tfplan
```

**Lưu ý**: Lệnh này sẽ tạo resources trên Azure!

### Step 8: Get Outputs

```bash
# List all outputs
terraform output

# Get specific output
terraform output vm_public_ip
terraform output vm_private_ip
terraform output -raw ssh_private_key

# JSON format
terraform output -json
```

## 🖥️ SSH vào VM

### Step 1: Save SSH Private Key

```bash
# Extract private key
terraform output -raw ssh_private_key > ~/.ssh/azure_vm.pem
chmod 600 ~/.ssh/azure_vm.pem
```

### Step 2: Get VM IP

```bash
PUBLIC_IP=$(terraform output -raw vm_public_ip)
echo "VM IP: $PUBLIC_IP"
```

### Step 3: SSH Connect

```bash
ssh -i ~/.ssh/azure_vm.pem azureuser@$PUBLIC_IP
```

**Lần đầu connect:**
- Accept host key khi được hỏi
- Password: không cần (SSH key auth)

### Step 4: Kiểm tra trên VM

```bash
# Check public IP
curl -s https://ifconfig.me

# Check NAT Gateway IP (nếu VM ở Private Subnet)
curl -s https://ifconfig.me

# Check network interfaces
ip addr show

# Check DNS
cat /etc/resolv.conf
```

## 🔄 Update Infrastructure

### Thay đổi Variables

```bash
# Edit terraform.tfvars
nano terraform.tfvars

# Thay đổi giá trị (e.g., VM size)
vm_size = "Standard_B4ms"

# Save và plan lại
terraform plan
terraform apply
```

### Thay đổi Resources

```bash
# Edit main.tf (e.g., thêm security rule)
nano main.tf

# Validate & plan
terraform validate
terraform plan

# Apply changes
terraform apply
```

## 🐛 Troubleshooting

### 1. "Authorization failed" hoặc "Insufficient privileges"

**Giải pháp:**
```bash
# Check current user
az account show

# Check role assignments
az role assignment list --assignee "<your-object-id>"

# Login lại
az login
```

### 2. "Resource already exists"

**Giải pháp:**
```bash
# Import existing resource
terraform import azurerm_resource_group.main "/subscriptions/SUB_ID/resourceGroups/RG_NAME"

# Hoặc delete resource trước
terraform destroy -target=azurerm_resource_group.main
```

### 3. "Error acquiring the state lock"

**Giải pháp:**
```bash
# Xem lock details
terraform state list

# Force unlock (hẻo dùng!)
terraform force-unlock LOCK_ID
```

### 4. Checkov fails

**Giải pháp:**
```bash
# Skip specific check
checkov -d . \
  --framework terraform \
  --skip-check CKV_AZURE_XX

# Hoặc fix security issues trong code
# Xem GITHUB_SECRETS_SETUP.md hoặc README.md
```

## 🧹 Cleanup Local

### Destroy Infrastructure

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=azurerm_linux_virtual_machine.main
```

### Clean State Files

```bash
# Remove local state
rm -rf .terraform/

# Remove lock file
rm .terraform.lock.hcl

# Remove backup
rm *.tfstate*
```

## 📊 Check Azure Resources

### List Resources Created

```bash
# Via Terraform
terraform show

# Via Azure CLI
az resource list --resource-group "terraform-demo-dev-rg"

# Via Azure Portal
# https://portal.azure.com → Resource Groups → terraform-demo-dev-rg
```

## 🔍 Advanced: Debug Mode

### Enable Debug Logging

```bash
# Linux/Mac
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
terraform plan

# Windows (PowerShell)
$env:TF_LOG = "DEBUG"
$env:TF_LOG_PATH = ".\terraform.log"
terraform plan

# View logs
cat terraform.log | tail -100
```

### Dry Run without Changes

```bash
# Just validate
terraform validate

# Plan without applying
terraform plan -out=tfplan
terraform show tfplan
```

## ✅ Pre-Deployment Checklist

- [ ] Azure CLI logged in
- [ ] Correct subscription selected
- [ ] `terraform validate` passed
- [ ] `terraform fmt -check` passed
- [ ] Checkov scan passed (no HIGH issues)
- [ ] `terraform plan` reviewed
- [ ] SSH key backed up (if first deploy)
- [ ] Resource costs estimated (optional)

## 📚 Useful Commands Reference

```bash
# Status
terraform state list          # Show all resources
terraform state show RESOURCE # Show specific resource details
terraform output             # Show all outputs

# Debug
terraform console            # Interactive console
terraform graph              # Show dependency graph

# Format
terraform fmt -recursive      # Format all files
terraform validate           # Check syntax

# Backup
terraform state pull > backup.tfstate  # Backup state
terraform state push backup.tfstate    # Restore state

# Remote operations (if using remote backend)
terraform state lock         # Lock state
terraform state unlock       # Unlock state
```

---

**Last Updated**: 2026-03-25
