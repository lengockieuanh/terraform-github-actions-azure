#!/bin/bash

###############################################################################
# Terraform & GitHub Actions Azure Setup Script
# 
# Usage: chmod +x setup.sh && ./setup.sh
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SERVICE_PRINCIPAL_NAME="${1:-terraform-sp}"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🚀 Terraform + GitHub Actions + Azure Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

REQUIRED_TOOLS=("az" "git" "jq")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
        echo -e "${RED}❌ $tool not found${NC}"
    else
        echo -e "${GREEN}✅ $tool installed${NC}"
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}⚠️  Please install missing tools: ${MISSING_TOOLS[*]}${NC}"
    exit 1
fi

echo ""

# Step 2: Azure Login
echo -e "${YELLOW}🔐 Azure Login${NC}"

CURRENT_USER=$(az account show --query user.name -o tsv 2>/dev/null || echo "")

if [ -n "$CURRENT_USER" ]; then
    echo -e "${GREEN}✅ Already logged in as: $CURRENT_USER${NC}"
else
    echo -e "${CYAN}Logging in to Azure...${NC}"
    az login
fi

echo ""

# Step 3: Get Subscription Info
echo -e "${YELLOW}📊 Getting subscription information...${NC}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo -e "${CYAN}Subscription ID: $SUBSCRIPTION_ID${NC}"
echo -e "${CYAN}Subscription Name: $SUBSCRIPTION_NAME${NC}"
echo -e "${CYAN}Tenant ID: $TENANT_ID${NC}"

echo ""

# Step 4: Create Service Principal
echo -e "${YELLOW}🔑 Creating Service Principal...${NC}"
echo -e "${CYAN}Name: $SERVICE_PRINCIPAL_NAME${NC}"

# Check if SP already exists
EXISTING_SP=$(az ad sp list --display-name "$SERVICE_PRINCIPAL_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_SP" ]; then
    echo -e "${YELLOW}⚠️  Service Principal '$SERVICE_PRINCIPAL_NAME' already exists${NC}"
    read -p "Do you want to use existing SP? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        SERVICE_PRINCIPAL_NAME="$SERVICE_PRINCIPAL_NAME-$(date +%s)"
        echo -e "${CYAN}Creating new Service Principal: $SERVICE_PRINCIPAL_NAME${NC}"
    else
        echo -e "${GREEN}Using existing Service Principal: $EXISTING_SP${NC}"
    fi
else
    echo -e "${CYAN}Creating new Service Principal...${NC}"
fi

if [ -z "$EXISTING_SP" ]; then
    SP_OUTPUT=$(az ad sp create-for-rbac \
        --name "$SERVICE_PRINCIPAL_NAME" \
        --role "Contributor" \
        --scopes "/subscriptions/$SUBSCRIPTION_ID" \
        --output json)
else
    SP_OUTPUT=$(az ad sp show --id "$EXISTING_SP" --output json)
fi

CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId // .clientId')
CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password // "N/A"')

echo -e "${GREEN}✅ Service Principal created/retrieved successfully${NC}"
echo ""

# Step 5: Create AZURE_CREDENTIALS
echo -e "${YELLOW}📝 Creating AZURE_CREDENTIALS JSON...${NC}"

AZURE_CREDENTIALS=$(az ad sp create-for-rbac \
    --name "$SERVICE_PRINCIPAL_NAME" \
    --role "Contributor" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --sdk-auth 2>/dev/null || cat <<EOF
{
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOF
)

echo -e "${GREEN}✅ AZURE_CREDENTIALS JSON created${NC}"
echo ""

# Step 6: Display Secrets
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🔐 GitHub Secrets to Add${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}1. ARM_CLIENT_ID${NC}"
echo "   Value: $CLIENT_ID"
echo ""

echo -e "${CYAN}2. ARM_CLIENT_SECRET${NC}"
echo "   Value: $CLIENT_SECRET"
echo ""

echo -e "${CYAN}3. ARM_SUBSCRIPTION_ID${NC}"
echo "   Value: $SUBSCRIPTION_ID"
echo ""

echo -e "${CYAN}4. ARM_TENANT_ID${NC}"
echo "   Value: $TENANT_ID"
echo ""

echo -e "${CYAN}5. AZURE_CREDENTIALS${NC}"
echo "   Value: (JSON object - see below)"
echo ""

echo "AZURE_CREDENTIALS JSON:"
echo "$AZURE_CREDENTIALS" | jq '.'
echo ""

# Step 7: Save to file
SECRETS_FILE="github-secrets.env"
cat > "$SECRETS_FILE" <<EOF
# GitHub Secrets
ARM_CLIENT_ID=$CLIENT_ID
ARM_CLIENT_SECRET=$CLIENT_SECRET
ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
ARM_TENANT_ID=$TENANT_ID

# AZURE_CREDENTIALS (full JSON)
AZURE_CREDENTIALS=$(echo "$AZURE_CREDENTIALS" | jq -c '.')
EOF

echo -e "${GREEN}✅ Secrets saved to: $SECRETS_FILE${NC}"
echo ""

# Step 8: GitHub Setup Instructions
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📚 Next Steps${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}1. Go to GitHub Repository Settings:${NC}"
echo "   → Settings → Secrets and variables → Actions"
echo ""

echo -e "${CYAN}2. Add the 5 secrets listed above:${NC}"
echo "   → Click 'New repository secret'"
echo "   → Add each secret (Name and Value)"
echo ""

echo -e "${CYAN}3. Test deployment:${NC}"
echo "   → Push changes to 'main' branch"
echo "   → Check GitHub Actions workflow"
echo ""

echo -e "${CYAN}4. View workflow results:${NC}"
echo "   → GitHub → Actions tab"
echo "   → Check 'Terraform Plan and Apply with Checkov'"
echo ""

# Verification
echo -e "${YELLOW}🔍 Verifying Service Principal permissions...${NC}"

if az login \
    --service-principal \
    -u "$CLIENT_ID" \
    -p "$CLIENT_SECRET" \
    --tenant "$TENANT_ID" &>/dev/null; then
    
    echo -e "${GREEN}✅ Service Principal login successful!${NC}"
    echo ""
    
    # Show role assignments
    echo "Role Assignments:"
    az role assignment list \
        --assignee "$CLIENT_ID" \
        --output table | grep -E "Contributor|Role"
else
    echo -e "${YELLOW}⚠️  Could not verify Service Principal${NC}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📖 Documentation Files:${NC}"
echo -e "   - README.md               (Main documentation)"
echo -e "   - GITHUB_SECRETS_SETUP.md (GitHub secrets guide)"
echo -e "   - github-secrets.env      (Secrets backup file)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}✅ Setup completed successfully!${NC}"
