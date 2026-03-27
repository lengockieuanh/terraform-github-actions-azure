# Azure Infrastructure with Terraform & GitHub Actions

Triển khai hạ tầng Azure tự động hóa bằng Terraform và GitHub Actions, kèm theo kiểm tra bảo mật với Checkov.

## 📋 Yêu cầu

- Azure subscription
- GitHub repository
- Azure CLI (`az` command)
- Git

## 🏗️ Cấu trúc hạ tầng

```
VNet (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24)
│   ├── Linux VM (Ubuntu 20.04)
│   └── Public IP
├── Private Subnet (10.0.2.0/24)
│   └── NAT Gateway (kết nối Internet)
├── Route Tables
│   ├── Public Route Table (Internet Gateway)
│   └── Private Route Table (NAT Gateway)
└── Network Security Group (NSG)
    ├── Allow SSH (port 22)
    ├── Allow HTTP (port 80)
    ├── Allow HTTPS (port 443)
    └── Deny all other inbound
```

## 🔐 Setup Service Principal

### Bước 1: Tạo Service Principal

```bash
# Lấy subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Tạo Service Principal
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID"
```

Output sẽ trả về:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "terraform-sp",
  "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### Bước 2: Thêm GitHub Secrets

Vào **Settings → Secrets and variables → Actions** của repository, thêm các secret:

| Secret Name | Value |
|---|---|
| `ARM_CLIENT_ID` | appId từ output trên |
| `ARM_CLIENT_SECRET` | password từ output trên |
| `ARM_SUBSCRIPTION_ID` | Subscription ID |
| `ARM_TENANT_ID` | tenant từ output trên |
| `AZURE_CREDENTIALS` | JSON object của Service Principal (xem bước 3) |

### Bước 3: Format AZURE_CREDENTIALS

Chạy lệnh sau để lấy JSON format:

```bash
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --json-auth
```

Copy toàn bộ JSON output và dán vào GitHub secret `AZURE_CREDENTIALS`.

## 📁 Cấu trúc Terraform

```
terraform/
├── provider.tf       # Azure provider configuration
├── variables.tf      # Input variables
├── main.tf          # Main infrastructure resources
├── outputs.tf       # Output values
└── terraform.tfvars # Variable values
```

## 🔒 Security Features

### 1. Checkov Integration
- Quét tự động lỗi bảo mật trong code Terraform
- Dừng deployment nếu có HIGH/CRITICAL issues
- Kiểm tra:
  - NSG rules không quá mở
  - VM sử dụng SSH key
  - Storage encryption
  - Network configuration
  - và nhiều hơn nữa

### 2. Network Security Group
- SSH (port 22): Mở cho tất cả (có thể giới hạn)
- HTTP (port 80): Mở cho tất cả
- HTTPS (port 443): Mở cho tất cả
- Các port khác: Từ chối (Deny)

### 3. SSH Key Security
- SSH key được tạo tự động bằng RSA 4096-bit
- Private key được lưu trữ an toàn (sensitive output)
- Export từ Terraform output để kết nối VM

## 🚀 Deployment Process

### Local Testing

```bash
# Khởi tạo Terraform
cd terraform
terraform init

# Kiểm tra syntax
terraform validate

# Format code
terraform fmt -recursive

# Plan deployment
terraform plan

# Apply (nếu plan OK)
terraform apply
```

### GitHub Actions Workflow

1. **Push code lên branch main** → Tự động trigger workflow
2. **Checkov Security Scan** → Kiểm tra lỗi bảo mật
   - Nếu có HIGH/CRITICAL → ❌ Workflow fail, không apply
   - Nếu OK → ✅ Tiếp tục
3. **Terraform Init** → Khởi tạo backend
4. **Terraform Validate** → Kiểm tra syntax
5. **Terraform Plan** → Tạo plan
6. **Terraform Apply** → Apply changes (chỉ khi push vào main)

## 📊 Lấy Outputs

### Sau khi deployment thành công:

```bash
cd terraform

# Xem tất cả outputs
terraform output

# Xem output cụ thể
terraform output vm_public_ip
terraform output ssh_private_key

# Format JSON
terraform output -json
```

### SSH vào VM

```bash
# Lấy public IP
PUBLIC_IP=$(terraform output -raw vm_public_ip)

# Lấy private key
terraform output -raw ssh_private_key > ~/.ssh/azure_vm.pem
chmod 600 ~/.ssh/azure_vm.pem

# SSH vào VM
ssh -i ~/.ssh/azure_vm.pem azureuser@$PUBLIC_IP
```

## 🔄 Update Infrastructure

1. Sửa file Terraform (e.g., `main.tf`, `variables.tf`)
2. Push lên GitHub
3. Workflow tự động chạy
4. Review plan trong GitHub Actions output
5. Nếu OK, apply sẽ tự động chạy trên main branch

## ⚙️ Customize Variables

Sửa `terraform/terraform.tfvars`:

```hcl
azure_region       = "Southeast Asia"  # Thay đổi region
environment        = "dev"              # dev, staging, prod
project_name       = "terraform-demo"   # Tên project
vm_size            = "Standard_B2s"     # VM size
admin_username     = "azureuser"        # Username
enable_nat_gateway = true              # Enable/disable NAT Gateway
```

## 📝 NSG Rules Customization

Để thêm hoặc sửa NSG rules, edit file `terraform/main.tf` section `azurerm_network_security_group`:

```hcl
security_rule {
  name                       = "AllowCustom"
  priority                   = 130
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "8080"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}
```

## 🐛 Troubleshooting

### 1. Checkov fails with HIGH severity issues

**Lỗi**: Workflow dừng ở Checkov scan
**Giải pháp**: 
- Xem chi tiết trong GitHub Actions logs
- Fix các issue được liệt kê
- Thử chạy Checkov locally: `checkov -d terraform --framework terraform`

### 2. Service Principal không có quyền

**Lỗi**: "Authorization failed" hoặc "Insufficient privileges"
**Giải pháp**:
- Check Service Principal role: `az role assignment list --assignee <appId>`
- Cấp thêm quyền nếu cần

### 3. Terraform state conflict

**Lỗi**: "Error acquiring the state lock"
**Giải pháp**:
- Xóa lock file: `terraform force-unlock <LOCK_ID>`
- Hoặc thử lại workflow sau vài phút

## 🧹 Cleanup

### Xóa infrastructure:

```bash
cd terraform
terraform destroy
# Hoặc auto-approve
terraform destroy -auto-approve
```

## 📚 Tài liệu tham khảo

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure NAT Gateway](https://learn.microsoft.com/en-us/azure/virtual-network/nat-gateway/nat-overview)
- [Checkov Azure Checks](https://www.checkov.io/cloud/azure)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)

---

**Created by**: Terraform GitHub Actions Automation
**Last updated**: 2026-03-25
