<!-- Source: docs/SEC-SERVICE-PRINCIPALS.md -->
<!-- Last migrated: 2026-06-30 -->

# Azure Service Principals & OIDC Configuration

**Document ID**: DOC-SERVICE-PRINCIPALS-001  
**Version**: 1.0  
**Status**: ✅ APPROVED  
**Last Updated**: 2026-06-30  
**Owner**: Platform Engineering + Security  
**Review Date**: 2026-12-30

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Service Principal Strategy](#service-principal-strategy)
3. [Three-Tier SP Architecture](#three-tier-sp-architecture)
4. [OIDC Federation (GitHub → Azure)](#oidc-federation-github--azure)
5. [Creation Checklist](#creation-checklist)
6. [RBAC & Least Privilege](#rbac--least-privilege)
7. [GitHub Secrets Setup](#github-secrets-setup)
8. [Testing & Validation](#testing--validation)

---

## Overview

**Goal**: Enable GitHub Actions to deploy infrastructure to Azure WITHOUT storing long-lived credentials.

**Solution**: Use OIDC (OpenID Connect) federation to create a trust relationship between GitHub and Azure. GitHub Actions proves its identity to Azure using short-lived tokens (valid for ~15 minutes).

**Benefits**:
- ✅ No stored secrets (no leaked tokens)
- ✅ Audit trail via Entra logs
- ✅ Token auto-rotates (GitHub handles it)
- ✅ Least-privilege per deployment layer
- ✅ Matches industry best practices (no AWS access keys either)

**Architecture**:
```
GitHub Actions (wants to deploy)
    ↓ (OIDC token signed by GitHub)
Azure Entra ID (verifies signature)
    ↓ (if valid, returns access token)
Service Principal (authorized to deploy infrastructure)
    ↓ (deploys resources)
Azure Subscriptions (resources created/updated)
```

---

## Service Principal Strategy

### Why Three Service Principals?

Following the **principle of least privilege**, we create separate SPs for each deployment layer:

| Deployment Layer | Service Principal | Subscriptions | Purpose | Risk if Compromised |
|------------------|-------------------|---------------|---------|---------------------|
| **Platform** | sp-terraform-platform-prod | Hub, Identity, Mgmt, Security | Deploy shared services | High (affects all workloads) |
| **Workload** | sp-terraform-workload-prod | Workload-Prod | Deploy business apps | Medium (only that app) |
| **Sandbox** | sp-terraform-sandbox-nonprod | Sandbox | Experimentation | Low (dev/test only) |

### Why Separate at All?

**Incident Containment**:
- If workload SP is compromised: Only that workload at risk
- If platform SP is compromised: All subscriptions at risk
- If sandbox SP is compromised: Only dev/test at risk

**Audit Trail**:
- See which SP deployed what
- Track deployments by team
- Compliance: Prove who had access to which resources

**Easy Offboarding**:
- Disable sandbox SP → kills developer access
- Disable workload SP → stops app deployments
- Platform SP remains for shared services

---

## Three-Tier SP Architecture

### 1. sp-terraform-platform-prod

**Purpose**: Deploy platform infrastructure (hub, connectivity, identity, management, security)

**Details**:
```
Name:                 sp-terraform-platform-prod
Entra App ID:         (auto-generated GUID)
Display Name:         Terraform Platform (Prod)
Description:          CI/CD service principal for platform layer deployment
Subscriptions Access: 4 (Hub, Identity, Management, Security)
Role:                 Contributor (scoped to subscriptions only, NOT Owner)
OIDC Subjects:        repo:owner/repo:ref:refs/heads/main
```

**Permissions** (Least Privilege):
```
✅ Contributor on: sub-platform-hub-prod
✅ Contributor on: sub-platform-identity-prod
✅ Contributor on: sub-platform-management-prod
✅ Contributor on: sub-platform-security-prod
❌ NO access to: Workload subscriptions
❌ NO Owner role: Anywhere
```

**Capabilities**:
- Deploy networking (vnets, NSGs, firewall)
- Deploy identity services
- Deploy monitoring/logging infrastructure
- Create/modify security policies

**Restrictions**:
- Cannot delete entire resource groups (containment)
- Cannot modify Entra directory (separate admin)
- Cannot access workload subscriptions (isolation)

---

### 2. sp-terraform-workload-prod

**Purpose**: Deploy business application workloads (first production app)

**Details**:
```
Name:                 sp-terraform-workload-prod
Entra App ID:         (auto-generated GUID)
Display Name:         Terraform Workload (Prod)
Description:          CI/CD service principal for workload (production) deployments
Subscriptions Access: 1 (Workload-Prod)
Role:                 Contributor (scoped to workload subscription only)
OIDC Subjects:        repo:owner/repo:ref:refs/heads/main
```

**Permissions** (Least Privilege):
```
✅ Contributor on: sub-workload-{app}-prod
❌ NO access to: Platform subscriptions
❌ NO access to: Sandbox subscriptions
❌ NO Owner role
```

**Capabilities**:
- Deploy application resources (VMs, App Services, Databases)
- Deploy workload networking (spoke vnet, subnets)
- Deploy application monitoring (Application Insights)
- Deploy workload-specific security (Key Vault, Managed Identity)

**Restrictions**:
- Cannot access platform resources (hub, firewall, etc.)
- Cannot modify core networking
- Cannot see other workloads

---

### 3. sp-terraform-sandbox-nonprod

**Purpose**: Allow developers to experiment in sandbox without approval

**Details**:
```
Name:                 sp-terraform-sandbox-nonprod
Entra App ID:         (auto-generated GUID)
Display Name:         Terraform Sandbox (NonProd)
Description:          CI/CD service principal for developer sandbox experimentation
Subscriptions Access: 1 (Sandbox)
Role:                 Contributor (scoped to sandbox subscription only)
OIDC Subjects:        repo:owner/repo:ref:refs/heads/develop, repo:owner/repo:ref:refs/heads/feature/*
```

**Permissions** (Most Permissive, but contained to dev):
```
✅ Contributor on: sub-sandbox-nonprod
❌ NO access to: Platform subscriptions
❌ NO access to: Workload subscriptions
❌ NO Owner role (even in sandbox)
```

**Capabilities**:
- Deploy any resource type for testing
- Delete/recreate resources freely
- Test new infrastructure patterns
- No approval workflow (self-service)

**Restrictions**:
- Sandbox only (no prod/platform access)
- Auto-shutdown policies enabled on VMs
- 90-day auto-cleanup on old resources
- No backup required

---

## OIDC Federation (GitHub → Azure)

### How OIDC Works (Trust Chain)

```
Step 1: Developer pushes code to GitHub
        ↓
Step 2: GitHub Actions workflow triggers
        ↓
Step 3: GitHub generates OIDC token signed by GitHub's private key
        - Token contains: repo name, branch, commit SHA
        - Valid for ~15 minutes only
        - Contains: iss=https://token.actions.githubusercontent.com
        ↓
Step 4: GitHub Actions sends OIDC token to Azure
        ↓
Step 5: Azure Entra ID validates token signature
        - Verifies: GitHub's signature is valid
        - Verifies: Token not expired
        - Verifies: Subject matches federated credential
        ↓
Step 6: If valid, Azure returns short-lived access token (~1 hour)
        ↓
Step 7: GitHub Actions uses access token to authenticate with Azure
        ↓
Step 8: Terraform CLI calls Azure APIs using access token
        ↓
Step 9: Resources deployed to Azure
        ↓
Step 10: Token expires (can't be reused)
```

### No Stored Secrets

```
❌ OLD (Insecure):
   1. Create SP password/certificate
   2. Store in GitHub Secrets (encrypted)
   3. If GitHub is hacked, password can be stolen
   4. Attacker can impersonate SP indefinitely
   5. Audit trail shows SP, not which GitHub Actions job used it

✅ NEW (Secure - OIDC):
   1. Create SP with NO password
   2. Create federated credential linking GitHub repo to SP
   3. GitHub Actions workflow gets OIDC token from GitHub
   4. Token valid for 15 minutes, GitHub-specific, GitHub-signed
   5. Even if token is stolen, it's immediately invalid
   6. Audit trail shows which GitHub repo, branch, commit used SP
   7. Can rotate by disconnecting federated credential (no password to manage)
```

---

## Creation Checklist

### Prerequisites

Before creating service principals, ensure:
- [ ] You have **Entra ID Global Administrator** role (or delegated)
- [ ] You have **Subscription Owner** role on all platform/workload subscriptions
- [ ] GitHub repo exists and is configured (see Phase 2 docs)
- [ ] Team agrees on naming (use SERVICE-PRINCIPAL naming pattern below)

### Naming Pattern

All service principals follow the naming convention:

```
sp-terraform-{layer}-{environment}

Examples:
  sp-terraform-platform-prod      (Platform services)
  sp-terraform-workload-prod      (Production workloads)
  sp-terraform-sandbox-nonprod    (Sandbox/dev)
```

### Step 1: Create Entra App Registration

**For each service principal, run:**

```bash
# Create Entra app registration (no password)
az ad app create \
  --display-name "Terraform Platform (Prod)" \
  --description "CI/CD service principal for platform layer deployment"

# Record the appId (Application ID)
export APP_ID="12345678-1234-1234-1234-123456789abc"
```

### Step 2: Create Service Principal

```bash
# Create service principal from app registration
az ad sp create --id $APP_ID

# Record the objectId (Service Principal ID)
export SP_ID="87654321-4321-4321-4321-cbad987654321"
```

### Step 3: Assign Subscription-Level RBAC

**For sp-terraform-platform-prod:**

```bash
# Get subscription IDs
export HUB_SUB_ID="sub-id-hub"
export IDENTITY_SUB_ID="sub-id-identity"
export MGMT_SUB_ID="sub-id-mgmt"
export SECURITY_SUB_ID="sub-id-security"

# Assign Contributor role to EACH platform subscription
az role assignment create \
  --role "Contributor" \
  --assignee-object-id $SP_ID \
  --scope "/subscriptions/$HUB_SUB_ID"

az role assignment create \
  --role "Contributor" \
  --assignee-object-id $SP_ID \
  --scope "/subscriptions/$IDENTITY_SUB_ID"

az role assignment create \
  --role "Contributor" \
  --assignee-object-id $SP_ID \
  --scope "/subscriptions/$MGMT_SUB_ID"

az role assignment create \
  --role "Contributor" \
  --assignee-object-id $SP_ID \
  --scope "/subscriptions/$SECURITY_SUB_ID"

# Verify all 4 assignments
az role assignment list --assignee $SP_ID --output table
```

### Step 4: Create Federated Credential (OIDC)

**For GitHub main branch deployment:**

```bash
# Create federated credential linking GitHub to Azure SP
az ad app federated-credential create \
  --id $APP_ID \
  --parameters @- <<EOF
{
  "name": "github-oidc-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:owner/HCW-Demo-LZDeployment:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "OIDC federation for GitHub Actions on main branch"
}
EOF

# Verify credential was created
az ad app federated-credential list --id $APP_ID
```

**Subject Format** (adjust per branch/environment):

```
# Main branch (production deployments)
"subject": "repo:owner/HCW-Demo-LZDeployment:ref:refs/heads/main"

# Feature branches (sandbox/dev)
"subject": "repo:owner/HCW-Demo-LZDeployment:ref:refs/heads/develop"

# Any feature branch (wildcard)
"subject": "repo:owner/HCW-Demo-LZDeployment:ref:refs/heads/feature/*"

# Pull requests (testing)
"subject": "repo:owner/HCW-Demo-LZDeployment:pull_request"
```

### Step 5: Document Service Principal Details

Create entry in SERVICE-PRINCIPALS-INVENTORY.md:

```markdown
| Name | App ID | SP ID | Subscriptions | Subjects | Status |
|------|--------|-------|---------------|----------|--------|
| sp-terraform-platform-prod | 12345678-... | 87654321-... | Hub, Identity, Mgmt, Security | main | ✅ Active |
| sp-terraform-workload-prod | aaaaaaaa-... | bbbbbbbb-... | Workload-Prod | main | ✅ Active |
| sp-terraform-sandbox-nonprod | cccccccc-... | dddddddd-... | Sandbox | develop, feature/* | ✅ Active |
```

---

## RBAC & Least Privilege

### Verification Checklist

After creating all SPs, verify permissions:

```bash
# Check Platform SP permissions
az role assignment list --assignee sp-terraform-platform-prod --output table
# Should show: Contributor on 4 subscriptions (Hub, Identity, Mgmt, Security)

# Check Workload SP permissions
az role assignment list --assignee sp-terraform-workload-prod --output table
# Should show: Contributor on 1 subscription (Workload-Prod only)

# Check Sandbox SP permissions
az role assignment list --assignee sp-terraform-sandbox-nonprod --output table
# Should show: Contributor on 1 subscription (Sandbox only)

# Verify NO Owner roles exist
az role assignment list --role "Owner" --output table
# Should NOT list any service principals
```

### What Each SP CAN Do

**sp-terraform-platform-prod** (High Trust):
```
✅ Create/modify vnets, subnets, NSGs
✅ Deploy Azure Firewall
✅ Create Key Vaults (for platform secrets)
✅ Deploy Log Analytics workspaces
✅ Create and assign Azure Policies
✅ Create automation accounts
❌ Access workload subscriptions
❌ Modify Entra directory (requires separate admin)
❌ Delete subscriptions
```

**sp-terraform-workload-prod** (Medium Trust):
```
✅ Create app service plans, web apps
✅ Deploy VMs and VM scale sets
✅ Create SQL databases
✅ Deploy Key Vault (for app secrets)
✅ Create Application Insights
✅ Create spoke vnets and subnets
❌ Access platform subscriptions
❌ Modify core networking (hub)
❌ Create policies
❌ Access other workloads
```

**sp-terraform-sandbox-nonprod** (Low Trust):
```
✅ Deploy ANY resource (experimentation)
✅ Delete resources freely
✅ Test new patterns
❌ Access production/platform
❌ Affect other users' sandbox resources (via policy)
```

---

## GitHub Secrets Setup

### Add to GitHub Secrets

In GitHub repo: **Settings → Secrets and variables → Actions**

Add these 3 secrets (same for all SPs, different values):

| Secret Name | Value | Source |
|-------------|-------|--------|
| `AZURE_CLIENT_ID` | App ID (from Step 1) | az ad app show --id $APP_ID |
| `AZURE_TENANT_ID` | Directory ID | az account show --query tenantId -o tsv |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | az account show --query id -o tsv |

**Example values** (yours will be different):
```
AZURE_CLIENT_ID=12345678-1234-1234-1234-123456789abc
AZURE_TENANT_ID=87654321-4321-4321-4321-cbad987654321
AZURE_SUBSCRIPTION_ID=ffffffff-ffff-ffff-ffff-ffffffffffff
```

**NO password/certificate needed** (OIDC handles auth)

### Verify Secrets in GitHub

```bash
# List secrets (doesn't show values)
gh secret list --repo owner/HCW-Demo-LZDeployment

# Should output:
# AZURE_CLIENT_ID     (created date)
# AZURE_TENANT_ID     (created date)
# AZURE_SUBSCRIPTION_ID (created date)
```

---

## GitHub Actions Workflow Setup

### Authenticate with OIDC

**In workflow file** (e.g., `.github/workflows/terraform-apply.yml`):

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_USE_OIDC: true  # 🔑 Enable OIDC (no password needed)

permissions:
  id-token: write  # 🔑 Required: Allow workflow to request OIDC token

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd
        with:
          terraform_version: 1.6.x
      
      # 🔑 OIDC magic happens here:
      # 1. GitHub generates OIDC token
      # 2. Terraform Azure provider reads it from env
      # 3. Azure Entra verifies signature
      # 4. Terraform gets access token
      # 5. No explicit login needed!
      
      - run: terraform init -backend-config=terraform/backend.hcl
      
      - run: terraform plan -out=tfplan
      
      - run: terraform apply tfplan
```

**Key Points**:
- `ARM_USE_OIDC: true` tells Terraform to use OIDC
- `permissions: id-token: write` allows GitHub to create OIDC token
- No `AZURE_CLIENT_SECRET` or certificate needed
- No `az login` command needed

---

## Testing & Validation

### Test 1: Verify SP Can Authenticate

```bash
# Simulate what GitHub Actions does
az login \
  --service-principal \
  --username $APP_ID \
  --tenant $TENANT_ID
  # This will fail because SP has no password
  # That's expected! OIDC handles auth instead.
```

### Test 2: Create Test Workflow

Create `.github/workflows/test-oidc.yml`:

```yaml
name: Test OIDC Authentication

on:
  workflow_dispatch  # Manual trigger for testing

env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_USE_OIDC: true

permissions:
  id-token: write

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: azure/login@6c251865b4e6290e7b78be643ea2d005bc51f69a
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Get Azure Context
        run: |
          az account show --output table
          # Should show the correct subscription
      
      - name: List Resources
        run: |
          az resource list --output table
          # Should list resources in the subscription
```

### Test 3: Verify Audit Trail

```bash
# View who deployed what via audit logs
az monitor activity-log list \
  --subscription $SUB_ID \
  --caller "sp-terraform-platform-prod" \
  --output table
```

---

## Troubleshooting

### Issue: "AADSTS650053: Application cannot use Proof-Key for Public Client flow"

**Cause**: Terraform is trying to use password auth instead of OIDC

**Fix**:
```bash
# Verify environment variable is set
echo $ARM_USE_OIDC  # Should output: true

# In Terraform provider:
provider "azurerm" {
  features {}
  
  # OIDC will be auto-detected if ARM_USE_OIDC=true
  # Don't set client_secret or cert_path
}
```

### Issue: "AADSTS50001: The application was not found in the directory"

**Cause**: SP wasn't created, or wrong App ID

**Fix**:
```bash
# Verify SP exists
az ad sp show --id $APP_ID

# Verify federated credential was created
az ad app federated-credential list --id $APP_ID
```

### Issue: "insufficient privileges to complete the operation"

**Cause**: SP doesn't have Contributor role on subscription

**Fix**:
```bash
# Verify role assignment
az role assignment list --assignee-object-id $SP_ID --output table

# Re-assign if needed
az role assignment create \
  --role "Contributor" \
  --assignee-object-id $SP_ID \
  --scope "/subscriptions/$SUB_ID"
```

---

## Service Principal Inventory

**File**: `docs/SERVICE-PRINCIPALS-INVENTORY.md` (to be populated)

```markdown
| Name | App ID | SP ID | Tenant | Subscriptions | OIDC Subjects | Status |
|------|--------|-------|--------|---------------|---------------|--------|
| sp-terraform-platform-prod | TBD | TBD | TBD | Hub, Identity, Mgmt, Security | main | TODO |
| sp-terraform-workload-prod | TBD | TBD | TBD | Workload-Prod | main | TODO |
| sp-terraform-sandbox-nonprod | TBD | TBD | TBD | Sandbox | develop, feature/* | TODO |
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-30 | Platform Engineering | Initial SP + OIDC strategy |

---

## Related Documents

- [SUBSCRIPTIONS.md](SUBSCRIPTIONS.md) - Subscription IDs needed for RBAC
- [RBAC-GROUPS.md](RBAC-GROUPS.md) - User group access (separate from SP access)
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - How to use SPs in Terraform
- [TODO.md](../TODO.md) - Phase 1.3 task details

---

**Questions?** Contact Platform Engineering + Security Team


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

