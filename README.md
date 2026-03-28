# Azure Infrastructure with Terraform & GitHub Actions

Triển khai hạ tầng Azure tự động hóa bằng Terraform và GitHub Actions, kèm theo kiểm tra bảo mật với Checkov.

## Cấu trúc hạ tầng

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

## 📁 Cấu trúc Terraform

```
terraform/
├── provider.tf      # Azure provider configuration
├── variables.tf     # Input variables
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

## Deployment Process

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

## Lấy Outputs

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

## Cleanup

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

