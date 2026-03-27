#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Terraform & GitHub Actions Azure Setup Script
    
.DESCRIPTION
    Script này giúp setup Service Principal và GitHub Secrets tự động
    
.EXAMPLE
    .\setup.ps1
#>

param(
    [string]$ServicePrincipalName = "terraform-sp",
    [string]$RepositoryUrl = "",
    [string]$RepositoryName = ""
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🚀 Terraform + GitHub Actions + Azure Setup" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow

$requiredTools = @("az", "git", "jq")
$missingTools = @()

foreach ($tool in $requiredTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $missingTools += $tool
        Write-Host "❌ $tool not found" -ForegroundColor Red
    } else {
        Write-Host "✅ $tool installed" -ForegroundColor Green
    }
}

if ($missingTools.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  Please install missing tools: $($missingTools -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Azure Login
Write-Host "🔐 Azure Login" -ForegroundColor Yellow

$currentUser = az account show --query user.name -o tsv 2>/dev/null

if ($currentUser) {
    Write-Host "✅ Already logged in as: $currentUser" -ForegroundColor Green
} else {
    Write-Host "Logging in to Azure..." -ForegroundColor Cyan
    az login
}

Write-Host ""

# Step 3: Get Subscription Info
Write-Host "📊 Getting subscription information..." -ForegroundColor Yellow

$subscriptionId = az account show --query id -o tsv
$subscriptionName = az account show --query name -o tsv
$tenantId = az account show --query tenantId -o tsv

Write-Host "Subscription ID: $subscriptionId" -ForegroundColor Cyan
Write-Host "Subscription Name: $subscriptionName" -ForegroundColor Cyan
Write-Host "Tenant ID: $tenantId" -ForegroundColor Cyan

Write-Host ""

# Step 4: Create Service Principal
Write-Host "🔑 Creating Service Principal..." -ForegroundColor Yellow
Write-Host "Name: $ServicePrincipalName" -ForegroundColor Cyan

try {
    # Check if SP already exists
    $existingSp = az ad sp list --display-name $ServicePrincipalName --query "[0].appId" -o tsv 2>/dev/null
    
    if ($existingSp) {
        Write-Host "⚠️  Service Principal '$ServicePrincipalName' already exists" -ForegroundColor Yellow
        $useExisting = Read-Host "Do you want to use existing SP? (y/n)"
        
        if ($useExisting -ne "y") {
            Write-Host "Creating new Service Principal with different name..." -ForegroundColor Cyan
            $ServicePrincipalName = "$ServicePrincipalName-$(Get-Date -Format 'yyyyMMddHHmmss')"
        } else {
            Write-Host "Using existing Service Principal: $existingSp" -ForegroundColor Green
        }
    }
    
    if (-not $existingSp) {
        $spOutput = az ad sp create-for-rbac `
            --name $ServicePrincipalName `
            --role "Contributor" `
            --scopes "/subscriptions/$subscriptionId" `
            --output json | ConvertFrom-Json
    } else {
        # Get existing SP details
        $spOutput = az ad sp show --id $existingSp --output json | ConvertFrom-Json
        $spOutput | Add-Member -MemberType NoteProperty -Name "password" -Value "(existing credential)" -Force
        $spOutput | Add-Member -MemberType NoteProperty -Name "appId" -Value $existingSp -Force
    }
    
    $clientId = $spOutput.appId
    $clientSecret = $spOutput.password
    
    Write-Host "✅ Service Principal created successfully" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Write-Host "❌ Error creating Service Principal: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Create AZURE_CREDENTIALS
Write-Host "📝 Creating AZURE_CREDENTIALS JSON..." -ForegroundColor Yellow

try {
    # Try to get SDK auth format (newer versions of Azure CLI)
    $azureCredentials = az ad sp create-for-rbac `
        --name $ServicePrincipalName `
        --role "Contributor" `
        --scopes "/subscriptions/$subscriptionId" `
        --sdk-auth 2>/dev/null | ConvertFrom-Json
    
    if (-not $azureCredentials) {
        # Fallback to manual JSON creation
        $azureCredentials = @{
            clientId       = $clientId
            clientSecret   = $clientSecret
            subscriptionId = $subscriptionId
            tenantId       = $tenantId
            activeDirectoryEndpointUrl = "https://login.microsoftonline.com"
            resourceManagerEndpointUrl = "https://management.azure.com/"
            activeDirectoryGraphResourceId = "https://graph.windows.net/"
            sqlManagementEndpointUrl = "https://management.core.windows.net:8443/"
            galleryEndpointUrl = "https://gallery.azure.com/"
            managementEndpointUrl = "https://management.core.windows.net/"
        } | ConvertTo-Json
    }
    
    Write-Host "✅ AZURE_CREDENTIALS JSON created" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Write-Host "⚠️  Could not create AZURE_CREDENTIALS JSON: $_" -ForegroundColor Yellow
}

# Step 6: Display Secrets
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "🔐 GitHub Secrets to Add" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "1. ARM_CLIENT_ID" -ForegroundColor Cyan
Write-Host "   Value: $clientId" -ForegroundColor White
Write-Host ""

Write-Host "2. ARM_CLIENT_SECRET" -ForegroundColor Cyan
if ($clientSecret -and $clientSecret -ne "(existing credential)") {
    Write-Host "   Value: $clientSecret" -ForegroundColor White
} else {
    Write-Host "   Value: (Please get from Azure Portal)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "3. ARM_SUBSCRIPTION_ID" -ForegroundColor Cyan
Write-Host "   Value: $subscriptionId" -ForegroundColor White
Write-Host ""

Write-Host "4. ARM_TENANT_ID" -ForegroundColor Cyan
Write-Host "   Value: $tenantId" -ForegroundColor White
Write-Host ""

Write-Host "5. AZURE_CREDENTIALS" -ForegroundColor Cyan
Write-Host "   Value: (JSON object - see below)" -ForegroundColor White
Write-Host ""

if ($azureCredentials) {
    Write-Host "AZURE_CREDENTIALS JSON:" -ForegroundColor Cyan
    Write-Host ($azureCredentials | ConvertTo-Json -Depth 10) -ForegroundColor White
}

Write-Host ""

# Step 7: GitHub Setup Instructions
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "📚 Next Steps" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "1. Go to GitHub Repository Settings:" -ForegroundColor Cyan
Write-Host "   → Settings → Secrets and variables → Actions" -ForegroundColor White
Write-Host ""

Write-Host "2. Add the 5 secrets listed above:" -ForegroundColor Cyan
Write-Host "   → Click 'New repository secret'" -ForegroundColor White
Write-Host "   → Add each secret (Name and Value)" -ForegroundColor White
Write-Host ""

Write-Host "3. Test deployment:" -ForegroundColor Cyan
Write-Host "   → Push changes to 'main' branch" -ForegroundColor White
Write-Host "   → Check GitHub Actions workflow" -ForegroundColor White
Write-Host ""

Write-Host "4. View workflow results:" -ForegroundColor Cyan
Write-Host "   → GitHub → Actions tab" -ForegroundColor White
Write-Host "   → Check 'Terraform Plan and Apply with Checkov'" -ForegroundColor White
Write-Host ""

# Step 8: Copy to Clipboard (Windows)
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($PSVersionTable.Platform -eq "Win32NT") {
    Write-Host "💾 Copying secrets to clipboard..." -ForegroundColor Yellow
    
    $secretsText = @"
ARM_CLIENT_ID: $clientId
ARM_CLIENT_SECRET: $clientSecret
ARM_SUBSCRIPTION_ID: $subscriptionId
ARM_TENANT_ID: $tenantId
AZURE_CREDENTIALS:
$($azureCredentials | ConvertTo-Json -Depth 10)
"@
    
    $secretsText | Set-Clipboard
    Write-Host "✅ Secrets copied to clipboard!" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Setup completed successfully!" -ForegroundColor Green
Write-Host ""

# Verification
Write-Host "🔍 Verifying Service Principal permissions..." -ForegroundColor Yellow

try {
    az login `
        --service-principal `
        -u $clientId `
        -p $clientSecret `
        --tenant $tenantId | Out-Null
    
    Write-Host "✅ Service Principal login successful!" -ForegroundColor Green
    Write-Host ""
    
    # Show role assignments
    $roleAssignments = az role assignment list `
        --assignee $clientId `
        --output json | ConvertFrom-Json
    
    Write-Host "Role Assignments:" -ForegroundColor Cyan
    foreach ($assignment in $roleAssignments) {
        Write-Host "  - Role: $($assignment.roleDefinitionName)" -ForegroundColor Green
        Write-Host "    Scope: $($assignment.scope)" -ForegroundColor Green
    }
    
} catch {
    Write-Host "⚠️  Could not verify Service Principal: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📖 Documentation Files:" -ForegroundColor Cyan
Write-Host "   - README.md               (Main documentation)" -ForegroundColor White
Write-Host "   - GITHUB_SECRETS_SETUP.md (GitHub secrets guide)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
