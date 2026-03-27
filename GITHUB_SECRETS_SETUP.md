# 🔐 GitHub Secrets Setup Guide

Hướng dẫn chi tiết thiết lập Azure Service Principal và GitHub Secrets.

## 📋 Bước 1: Tạo Service Principal trên Azure

### Cách 1: Sử dụng Azure CLI

```bash
# 1. Login vào Azure
az login

# 2. Lấy subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# 3. Tạo Service Principal
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID"
```

**Output:**
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "terraform-sp",
  "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

Lưu lại 4 giá trị này ⚠️

### Cách 2: Sử dụng Azure Portal

1. Vào **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Nhập tên: `terraform-sp`
4. Click **Register**
5. Trong **Overview**, copy **Application (client) ID** và **Directory (tenant) ID**
6. Vào **Certificates & secrets** → **New client secret**
7. Copy **Value** (password)
8. Vào **Subscriptions** → Select subscription
9. Click **Access control (IAM)** → **Add role assignment**
10. Select **Contributor** role → Select Service Principal → Assign

## 📁 Bước 2: Tạo AZURE_CREDENTIALS JSON

Chạy lệnh này để tạo JSON format cho GitHub secret:

```bash
az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth
```

**Output** sẽ giống như:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

## 🔑 Bước 3: Thêm GitHub Secrets

1. Vào GitHub repository của bạn
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** và thêm các secret sau:

### Secret 1: ARM_CLIENT_ID
- **Name**: `ARM_CLIENT_ID`
- **Value**: `appId` từ Service Principal
- **Example**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Secret 2: ARM_CLIENT_SECRET
- **Name**: `ARM_CLIENT_SECRET`
- **Value**: `password` từ Service Principal
- **Example**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Secret 3: ARM_SUBSCRIPTION_ID
- **Name**: `ARM_SUBSCRIPTION_ID`
- **Value**: Subscription ID của bạn
- **Example**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Secret 4: ARM_TENANT_ID
- **Name**: `ARM_TENANT_ID`
- **Value**: `tenant` từ Service Principal
- **Example**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Secret 5: AZURE_CREDENTIALS
- **Name**: `AZURE_CREDENTIALS`
- **Value**: Toàn bộ JSON từ `az ad sp create-for-rbac --sdk-auth`

## ✅ Bước 4: Verify Secrets

Chạy lệnh này để verify Service Principal có đủ quyền:

```bash
# Set environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Test login
az login \
  --service-principal \
  -u $ARM_CLIENT_ID \
  -p $ARM_CLIENT_SECRET \
  --tenant $ARM_TENANT_ID

# Check subscription
az account show
```

**Output thành công:**
```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "isDefault": true,
  "name": "Your Subscription Name",
  "state": "Enabled",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

## 🔄 Refresh Service Principal Password (Optional)

Nếu password hết hạn hoặc muốn thay đổi:

```bash
# List current credentials
az ad sp credential list --id <client-id>

# Create new credential
az ad sp credential reset \
  --id <client-id> \
  --credential-description "Terraform credential"
```

## 🧹 Cleanup (Optional)

Nếu muốn xóa Service Principal:

```bash
# Delete Service Principal
az ad sp delete --id <client-id>

# Hoặc
az ad app delete --id <client-id>
```

## 🚨 Security Best Practices

1. ✅ **Use Service Principal** - Không sử dụng personal access token
2. ✅ **Limit Scope** - Chỉ cấp permissions cần thiết (Resource Group level, không Subscription)
3. ✅ **Rotate Credentials** - Thay đổi password định kỳ (mỗi 90 ngày)
4. ✅ **Use Short-lived Tokens** - Azure CLI tokens tự expire
5. ✅ **Audit Access** - Monitor Service Principal activity trong Azure logs
6. ✅ **Use Managed Identity** - Khi deployed trên Azure (App Service, Functions, VMs)

## 📊 Kiểm tra Service Principal Permissions

```bash
# List all role assignments cho Service Principal
az role assignment list --assignee <client-id>

# Output sẽ show:
# - Principal ID
# - Role Name (e.g., Contributor)
# - Scope (Subscription, Resource Group, Resource)
```

---

**Last Updated**: 2026-03-25
