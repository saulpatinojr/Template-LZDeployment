<!-- Source: docs/PHASE-ROADMAP.md -->
<!-- Last migrated: 2026-06-30 -->

# TODO - Azure Landing Zone Deployment
## Phase-based implementation of Azure platform landing zone

**Created**: June 30, 2026  
**Status**: 🟡 IN PROGRESS - Phase 0 partially complete  
**Baseline**: [Microsoft CAF - Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)  
**Architecture**: [Hub-Spoke with Management Group Hierarchy](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-areas)

---

## 📋 Overview: Azure Landing Zone Phases

The Azure Landing Zone deployment follows **four phases** aligned with the [Azure Landing Zones IaC Accelerator](https://aka.ms/alz/accelerator) approach:

| Phase | Name | Duration | Status | Purpose |
|-------|------|----------|--------|---------|
| **Phase 0** | Planning | Week 1 | 🟡 PARTIAL | Decision: IaC language, VCS, naming/tagging standards |
| **Phase 1** | Prerequisites | Week 1-2 | ⚪ BLOCKED | Credentials, subscriptions, service principals, OIDC |
| **Phase 2** | Bootstrap | Week 2-3 | 🟢 STARTED | GitHub repo, CI/CD pipelines, Terraform state backend |
| **Phase 3** | Run | Week 3+ | ⚪ BLOCKED | Deploy platform components via IaC (management groups, policies, hub) |

---

## 🎯 Phase 0: Planning - IaC Decisions & Standards

**Status**: 🟡 **PARTIAL** (Decisions needed on naming/tagging)  
**Effort**: 4 hours  
**Deadline**: Immediate  

### Phase 0.1: IaC Language & VCS Selection

**Status**: ✅ DECIDED
- **IaC Language**: Terraform (vs. Bicep) ✅
- **VCS**: GitHub (vs. Azure DevOps) ✅
- **Deployment Patterns**: Azure Verified Modules (AVM) for Terraform ✅

**Reference**:
- [AVM Terraform Requirements](https://azure.github.io/Azure-Verified-Modules/specs/terraform/)
- [ALZ Accelerator for Terraform](https://aka.ms/alz/acc/tf)

---

### Phase 0.2: Azure Naming Convention

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 2 hours

**Tasks**:
- [ ] Review [CAF naming conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [ ] Define naming pattern for your organization:
  ```
  Format: {resource-type}-{workload}-{environment}-{region}-{instance}
  Example: vnet-lz-prod-eastus-01, rg-hub-platform-eastus-01
  ```
- [ ] Document abbreviations for all resource types you'll use
  - **Platform resources**: hub-vnet, fw, log-ws, keyvault, etc.
  - **Workload resources**: spoke-vnet, vm-app, sql-db, etc.
- [ ] Create `docs/NAMING-CONVENTION.md` with:
  - Naming pattern rules
  - Resource type abbreviations table
  - Example names for platform resources
  - Environment-specific naming (prod/nonprod)
- [ ] Define max length constraints per resource type

**Acceptance Criteria**:
- ✅ Naming pattern documented and agreed
- ✅ All platform resources follow pattern
- ✅ Team can auto-generate compliant names

**Key Naming Principles**:
1. **Lower snake_case** for all resources (AVM requirement: TFNFR4)
2. **Environment suffix**: -prod, -nonprod, -dev, -test
3. **Region identifier**: -eastus, -westus, -northeu, etc.
4. **Workload identifier**: -hub (platform), -spoke (workload), -mgmt (operations)
5. **Instance counter**: -01, -02 for scale scenarios

---

### Phase 0.3: Azure Tagging Strategy

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 2 hours

**Tasks**:
- [ ] Review [CAF tagging strategy](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)
- [ ] Define mandatory tags:
  ```
  - Environment: {prod, nonprod, dev, test}
  - Application: {app-name or "platform" for hub resources}
  - Owner: {team-name or individual email}
  - CostCenter: {cost-code for chargeback}
  - CreatedDate: {YYYY-MM-DD}
  - Terraform: {true/false}
  - ManagedBy: {terraform, manual, script}
  ```
- [ ] Define optional tags (automation, backup schedules, etc.)
- [ ] Create `docs/TAGGING-STRATEGY.md` with:
  - Tag definitions and allowed values
  - Tagging examples for different resource types
  - Enforcement via Azure Policy
- [ ] Plan Azure Policy for mandatory tag enforcement

**Acceptance Criteria**:
- ✅ Tag strategy documented
- ✅ All resources have mandatory tags
- ✅ Automation can apply tags at deploy time

---

## 🔐 Phase 1: Prerequisites - Azure Subscription Setup

**Status**: 🟡 **READY** (Phase 0 complete, Phase 1 docs ready)  
**Effort**: 8-12 hours  
**Deadline**: End of Week 2 (by 2026-07-07)  

### Phase 1.1: Create Platform Subscriptions

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 2 hours

The Azure landing zone requires a hub-spoke topology with dedicated platform subscriptions:

**Subscriptions to Create**:
1. **Platform-Hub** (Connectivity):
   - [ ] Create subscription: `sub-{org}-platform-hub-{env}`
   - [ ] Purpose: Hub vnet, Azure Firewall, Azure VPN/ExpressRoute, DNS
   - [ ] Estimated cost: $500-2,000/month (varies by connectivity choice)

2. **Platform-Identity**:
   - [ ] Create subscription: `sub-{org}-platform-identity-{env}`
   - [ ] Purpose: Entra integration, hybrid identity if needed
   - [ ] Estimated cost: $0-200/month

3. **Platform-Management**:
   - [ ] Create subscription: `sub-{org}-platform-mgmt-{env}`
   - [ ] Purpose: Log Analytics, Automation, monitoring
   - [ ] Estimated cost: $100-500/month

4. **Platform-Security** (optional but recommended):
   - [ ] Create subscription: `sub-{org}-platform-security-{env}`
   - [ ] Purpose: Microsoft Sentinel, security tooling
   - [ ] Estimated cost: $300-1,000/month (if Sentinel enabled)

5. **Workload-Prod** (first application landing zone):
   - [ ] Create subscription: `sub-{org}-workload-prod-{env}`
   - [ ] Purpose: First production workload
   - [ ] Estimated cost: Workload-dependent

6. **Workload-Sandbox**:
   - [ ] Create subscription: `sub-{org}-sandbox-{env}`
   - [ ] Purpose: Dev/test experimentation
   - [ ] Estimated cost: $50-200/month

**References**:
- [Azure subscription design](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-subscriptions)
- [Subscription vending](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/subscription-vending)

**Acceptance Criteria**:
- ✅ All 6 subscriptions created
- ✅ Each subscription has correct owner/billing info
- ✅ Subscription IDs documented in `docs/SUBSCRIPTIONS.md`

---

### Phase 1.2: Configure Azure AD / Entra ID

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 1 hour

**Tasks**:
- [ ] Verify tenant ID: `az account show --query tenantId`
- [ ] Create Entra groups for RBAC:
  - [ ] `Azure-{org}-platform-admins` (Contributor on Platform subscriptions)
  - [ ] `Azure-{org}-platform-readers` (Reader on Platform subscriptions)
  - [ ] `Azure-{org}-workload-admins` (Contributor on Workload subscriptions)
  - [ ] `Azure-{org}-workload-owners` (Contributor on specific workload)
- [ ] Assign users to appropriate groups
- [ ] Document Entra groups in `docs/RBAC-GROUPS.md`

**Acceptance Criteria**:
- ✅ Entra groups created and populated
- ✅ Group membership reflects org structure

---

### Phase 1.3: Create Service Principals for CI/CD

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 2 hours

**Service Principals to Create**:
1. **sp-terraform-platform-{env}**:
   - [ ] Create Entra app registration
   - [ ] Assign Contributor role to: Platform-Hub, Platform-Identity, Platform-Management, Platform-Security subscriptions
   - [ ] Restrict permissions to platform subscriptions ONLY

2. **sp-terraform-workload-{env}**:
   - [ ] Create Entra app registration
   - [ ] Assign Contributor role to: Workload-Prod subscription
   - [ ] Can be limited to specific resource group if needed

3. **sp-terraform-sandbox-{env}**:
   - [ ] Create Entra app registration
   - [ ] Assign Contributor role to: Workload-Sandbox subscription only
   - [ ] Less restrictive for experimentation

**Best Practices** (AVM principle: least privilege):
- [ ] Never assign Owner role to service principals
- [ ] Always scope to subscription level minimum
- [ ] Use separate SPs for each deployment layer (platform vs. workload)
- [ ] Document all SPs in `docs/SERVICE-PRINCIPALS.md`

**References**:
- [Azure Verified Modules - RBAC](https://azure.github.io/Azure-Verified-Modules/specs/terraform/#variable-requirements)
- [Security best practices for service principals](https://learn.microsoft.com/azure/active-directory/develop/security-best-practices-for-app-registration)

**Acceptance Criteria**:
- ✅ All 3 service principals created
- ✅ Permissions scoped correctly
- ✅ No Owner roles assigned

---

### Phase 1.4: Setup OIDC Federation (GitHub → Azure)

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 1 hour

**Tasks**:
- [ ] For each service principal created in Phase 1.3:
  - [ ] Create federated credential:
    - Issuer: `https://token.actions.githubusercontent.com`
    - Subject: `repo:{org}/{repo}:ref:refs/heads/main` (for main branch deployments)
    - Subject: `repo:{org}/{repo}:environment:prod` (for environment-based)
  - [ ] Verify credential via: `az identity federated-credential list --resource-group ... --identity-name ...`

- [ ] Add GitHub secrets (no long-lived secrets stored):
  ```
  AZURE_CLIENT_ID: (from service principal)
  AZURE_TENANT_ID: (from Entra)
  AZURE_SUBSCRIPTION_ID: (subscription to deploy to)
  ```

**Acceptance Criteria**:
- ✅ OIDC federated credentials created for all SPs
- ✅ GitHub Actions can authenticate without stored secrets
- ✅ Tested: GitHub Actions workflow succeeds with OIDC

**Reference**: [GitHub OIDC with Azure](https://learn.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation-create-trust-github)

---

## 🚀 Phase 2: Bootstrap - GitHub + Terraform Setup

**Status**: 🟢 **STARTED** (Repo exists, partial setup)  
**Effort**: 6-8 hours  
**Deadline**: End of Week 2  

### Phase 2.1: Verify Repository Structure

**Status**: 🟡 PARTIAL (Repo exists, structure needs review)  
**Owner**: TBD  
**Effort**: 1 hour

**Expected Structure**:
```
HCW-Demo-LZDeployment/
├── .github/
│   ├── workflows/
│   │   ├── 00-terraform-validate.yml        # Runs on PR
│   │   ├── 10-terraform-plan.yml            # Runs on PR
│   │   ├── 20-terraform-apply.yml           # Runs on merge to main
│   │   └── 99-drift-detection.yml           # Weekly schedule
│   └── CODEOWNERS
├── terraform/
│   ├── modules/                            # AVM-compliant modules
│   │   ├── avm-res-network-virtualnetwork/  # Hub vnet
│   │   ├── avm-res-network-networksecuritygroup/
│   │   ├── avm-res-keyvault/
│   │   ├── avm-res-operationalinsights-workspace/
│   │   └── ...
│   ├── layers/                             # Deployment layers
│   │   ├── 00-platform-identity/
│   │   ├── 01-platform-hub-networking/
│   │   ├── 02-platform-management/
│   │   ├── 03-platform-security/
│   │   └── 04-workload-sandbox/
│   ├── live/                               # Configuration per environment
│   │   ├── prod/
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.hcl
│   │   └── nonprod/
│   │       ├── terraform.tfvars
│   │       └── backend.hcl
│   └── README.md                           # Terraform guide
├── docs/
│   ├── NAMING-CONVENTION.md
│   ├── TAGGING-STRATEGY.md
│   ├── SUBSCRIPTIONS.md
│   ├── SERVICE-PRINCIPALS.md
│   ├── RBAC-GROUPS.md
│   ├── DEPLOYMENT-GUIDE.md
│   └── ARCHITECTURE.md
├── .gitignore
├── CLAUDE.md                               # Project-specific instructions
└── README.md                               # Main project guide
```

**Tasks**:
- [ ] Verify folder structure exists
- [ ] Create any missing directories
- [ ] Review/update `.gitignore` for sensitive files
- [ ] Ensure CODEOWNERS file assigns code review requirements

**Acceptance Criteria**:
- ✅ Folder structure matches above
- ✅ `.gitignore` covers terraform state, .tfvars, secrets
- ✅ CODEOWNERS file present and configured

---

### Phase 2.2: Terraform State Backend (Terraform Cloud)

**Status**: 🟡 PARTIAL (May have been setup in earlier phase)  
**Owner**: TBD  
**Effort**: 1 hour

**Tasks**:
- [ ] Create/verify Terraform Cloud account at https://app.terraform.io
- [ ] Create organization: `{org-name}`
- [ ] Create workspaces:
  - [ ] `platform-identity-prod`
  - [ ] `platform-hub-prod`
  - [ ] `platform-management-prod`
  - [ ] `platform-security-prod`
  - [ ] `workload-sandbox-nonprod`
  - [ ] `workload-prod-prod`

- [ ] Create API token for CI/CD:
  - [ ] Token name: `github-actions-{env}`
  - [ ] Scope: Applicable to all workspaces
  - [ ] Store as GitHub secret: `TF_API_TOKEN`

- [ ] Create `terraform/backend.hcl` template:
  ```hcl
  cloud {
    organization = "{org-name}"
    hostname     = "app.terraform.io"
    
    workspaces {
      name = "platform-identity-prod"
    }
  }
  ```

**Acceptance Criteria**:
- ✅ TFC organization and workspaces created
- ✅ API token generated and stored in GitHub Secrets
- ✅ Local: `terraform init -backend-config=terraform/backend.hcl` succeeds

**References**:
- [Terraform Cloud setup](https://www.terraform.io/docs/cloud/)
- [Terraform Cloud GitHub integration](https://www.terraform.io/cloud-docs/vcs)

---

### Phase 2.3: CI/CD Workflows (GitHub Actions)

**Status**: ⚪ TODO (workflows exist but need verification for proper phases)  
**Owner**: TBD  
**Effort**: 2 hours

**Workflow Files Required**:

**`.github/workflows/00-terraform-validate.yml`** (Runs on every PR)
```yaml
name: 00-Terraform Validate
on:
  pull_request:
    paths:
      - 'terraform/**'
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd
        with:
          terraform_version: 1.6.x
      - run: terraform fmt -check -recursive terraform/
      - run: terraform validate
```

**`.github/workflows/10-terraform-plan.yml`** (Runs on PR with OIDC auth)
```yaml
name: 10-Terraform Plan
on:
  pull_request:
    paths:
      - 'terraform/**'
env:
  TF_VERSION: 1.6.x
permissions:
  id-token: write
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd
      - uses: azure/login@6c251865b4e6290e7b78be643ea2d005bc51f69a
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - run: terraform init -backend-config=terraform/backend.hcl
      - run: terraform plan -out=tfplan
```

**`.github/workflows/20-terraform-apply.yml`** (Runs on merge to main)
```yaml
name: 20-Terraform Apply
on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
env:
  TF_VERSION: 1.6.x
permissions:
  id-token: write
jobs:
  apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd
      - uses: azure/login@6c251865b4e6290e7b78be643ea2d005bc51f69a
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - run: terraform init -backend-config=terraform/backend.hcl
      - run: terraform apply -auto-approve tfplan
```

**`.github/workflows/99-drift-detection.yml`** (Weekly check)
```yaml
name: 99-Drift Detection
on:
  schedule:
    - cron: '0 9 * * 1'  # Monday 9 AM UTC
env:
  TF_VERSION: 1.6.x
permissions:
  id-token: write
jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd
      - uses: azure/login@6c251865b4e6290e7b78be643ea2d005bc51f69a
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - run: terraform init -backend-config=terraform/backend.hcl
      - run: terraform plan -detailed-exitcode || DRIFT_DETECTED=$?
      - name: Report drift
        if: ${{ env.DRIFT_DETECTED == 2 }}
        run: echo "Drift detected - manual review required"
```

**Tasks**:
- [ ] Create/verify all 4 workflow files exist
- [ ] Update actions to use pinned SHA versions (AVM best practice)
- [ ] Configure GitHub Secrets:
  - [ ] AZURE_CLIENT_ID
  - [ ] AZURE_TENANT_ID
  - [ ] AZURE_SUBSCRIPTION_ID
  - [ ] TF_API_TOKEN
- [ ] Test workflow on feature branch PR
- [ ] Verify terraform plan output in PR comments
- [ ] Merge PR and verify apply workflow

**Acceptance Criteria**:
- ✅ All 4 workflows exist and are syntactically valid
- ✅ PR trigger runs validate + plan
- ✅ Merge trigger runs apply
- ✅ No long-lived secrets in code or logs

---

## 🏗️ Phase 3: Run - Deploy Platform Components

**Status**: ⚪ **BLOCKED** (Requires Phase 1 & 2 complete)  
**Effort**: 30+ hours  
**Deadline**: Ongoing (incremental deployment)

### Phase 3 Overview: Deployment Layers

The platform is deployed in **layers** (management groups, policies, networking, management):

| Layer | Module | Purpose | Status | Effort | Cost |
|-------|--------|---------|--------|--------|------|
| **Layer 00** | Management Groups + Policies | Governance hierarchy | ⚪ TODO | 4h | $0 |
| **Layer 01** | Identity Platform | Entra integration | ⚪ TODO | 2h | $0-200 |
| **Layer 02** | Hub Networking | Connectivity core | ⚪ TODO | 6h | $500-2,000 |
| **Layer 03** | Management & Monitoring | Operations tooling | ⚪ TODO | 4h | $100-500 |
| **Layer 04** | Security Baseline | Sentinel, policies | ⚪ TODO | 6h | $300-1,000 |
| **Layer 05** | Sandbox Landing Zone | Developer experimentation | 🟢 PARTIAL | 2h | $50-200 |

---

### Phase 3.0: Management Group Hierarchy (Layer 00)

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 4 hours

**Management Group Structure** (standard ALZ hierarchy):
```
Tenant Root
├── Intermediate Root ({org}-lz)
│   ├── Platform
│   │   ├── Connectivity
│   │   ├── Identity
│   │   ├── Management
│   │   └── Security
│   ├── Landing Zones
│   │   ├── Prod (Corp)
│   │   ├── Nonprod
│   │   └── Sandboxes
│   └── Decommissioned
```

**Tasks**:
- [ ] Create Terraform module: `terraform/modules/avm-management-group-hierarchy/`
- [ ] Deploy management group structure via module
- [ ] Assign subscriptions to correct management groups:
  - Platform-Hub → Platform/Connectivity
  - Platform-Identity → Platform/Identity
  - Platform-Management → Platform/Management
  - Platform-Security → Platform/Security
  - Workload-Prod → Landing Zones/Prod
  - Workload-Sandbox → Landing Zones/Sandboxes

- [ ] Define Azure Policy assignments:
  - Baseline policies at root (compliance, tagging, etc.)
  - Workload policies at Landing Zones level
  - Exemptions for platform resources

**References**:
- [Management Group design](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-management-groups)
- [Policy as Code](https://learn.microsoft.com/azure/governance/policy/overview)

**Acceptance Criteria**:
- ✅ Management group hierarchy created
- ✅ All subscriptions assigned to correct groups
- ✅ Policies assignable at MG level

---

### Phase 3.1: Identity Platform (Layer 01)

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 2 hours

**Tasks**:
- [ ] Create Platform-Identity subscription resources:
  - [ ] Resource group: `rg-platform-identity-prod-eastus-01`
  - [ ] Optional: VM for domain controller (if hybrid identity needed)
  - [ ] Conditional Access policies for Azure
  - [ ] Entra Privileged Identity Management (PIM) setup

**Modules to use**:
- Azure Verified Modules for any resources deployed

**Acceptance Criteria**:
- ✅ Platform-Identity subscription configured
- ✅ Entra groups synchronized (if applicable)

---

### Phase 3.2: Hub Networking (Layer 02)

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 6 hours

**This is the core connectivity platform. Deploy incrementally.**

**Tasks**:

**Subtask 3.2.1: Hub Virtual Network**
- [ ] Create Terraform layer: `terraform/layers/01-platform-hub-networking/`
- [ ] Use AVM module: `avm-res-network-virtualnetwork`
- [ ] Deploy hub vnet:
  - Name: `vnet-hub-platform-prod-{region}-01`
  - Address space: `10.0.0.0/16` (adjust to your IPAM)
  - Region: East US (example)

**Subtask 3.2.2: Hub Subnets**
- [ ] Subnet: GatewaySubnet (10.0.0.0/24) - for VPN/ExpressRoute
- [ ] Subnet: AzureFirewallSubnet (10.0.1.0/24) - for Azure Firewall
- [ ] Subnet: Management (10.0.2.0/24) - for ops/monitoring
- [ ] Subnet: Azure Bastion (10.0.3.0/24) - for secure access (optional)

**Subtask 3.2.3: Azure Firewall**
- [ ] Use AVM module: `avm-res-network-azurefirewall`
- [ ] Deploy Azure Firewall Standard or Premium
- [ ] Configure basic firewall rules (allow/deny defaults)
- [ ] Enable diagnostics to Log Analytics (from Layer 03)

**Subtask 3.2.4: VPN/ExpressRoute Gateway**
- [ ] Use AVM module: `avm-res-network-vpngateway` or `avm-res-network-expressroutecircuit`
- [ ] Deploy VPN Gateway in GatewaySubnet (if needed for hybrid)
- [ ] For Demo: May skip if no on-prem connectivity required

**Subtask 3.2.5: Network Security Groups (NSGs)**
- [ ] Use AVM module: `avm-res-network-networksecuritygroup`
- [ ] Create NSGs:
  - Management subnet NSG (allow RDP/SSH from admin IPs)
  - Firewall management NSG
  - Bastion NSG (if used)

**Modules to use**:
- [avm-res-network-virtualnetwork](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/latest)
- [avm-res-network-azurefirewall](https://registry.terraform.io/modules/Azure/avm-res-network-azurefirewall/azurerm/latest)
- [avm-res-network-networksecuritygroup](https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm/latest)

**Naming Conventions** (AVM requirement: TFNFR4 snake_case):
```
vnet-hub-platform-prod-eastus-01
snet-gateway-hub-platform-prod-eastus-01
snet-firewall-hub-platform-prod-eastus-01
snet-mgmt-hub-platform-prod-eastus-01
fw-hub-platform-prod-eastus-01
nsg-mgmt-hub-platform-prod-eastus-01
```

**Tagging** (all resources must have):
```hcl
tags = {
  Environment = "prod"
  Application = "platform"
  Owner       = "platform-team"
  CostCenter  = "engineering"
  CreatedDate = "2026-06-30"
  Terraform   = "true"
  ManagedBy   = "terraform"
}
```

**Acceptance Criteria**:
- ✅ Hub vnet deployed with correct address space
- ✅ All subnets created
- ✅ Azure Firewall deployed and operational
- ✅ NSGs attached to subnets
- ✅ All resources follow naming/tagging conventions
- ✅ Workflow passes: terraform validate, terraform plan, terraform apply

**References**:
- [Network topology design area](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/network-topology-and-connectivity)
- [Hub-spoke networking](https://learn.microsoft.com/azure/reference-architectures/hybrid-networking/hub-spoke)

---

### Phase 3.3: Management & Monitoring (Layer 03)

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 4 hours

**Tasks**:

**Subtask 3.3.1: Log Analytics Workspace**
- [ ] Use AVM module: `avm-res-operationalinsights-workspace`
- [ ] Deploy in Platform-Management subscription
- [ ] Name: `log-platform-mgmt-prod-eastus-01`
- [ ] Retention: 30 days (or per compliance requirement)
- [ ] Tier: Pay-as-you-go

**Subtask 3.3.2: Automation Account** (optional, for runbooks)
- [ ] Use AVM module for automation account
- [ ] Optional: For infrastructure automation if needed

**Subtask 3.3.3: Diagnostic Settings**
- [ ] Configure diagnostics for all platform resources:
  - Hub vnet → Log Analytics
  - Azure Firewall → Log Analytics
  - NSGs → Log Analytics
  - VPN Gateway → Log Analytics

**Subtask 3.3.4: Action Groups & Alerts**
- [ ] Create action group for ops team
- [ ] Configure alerts for:
  - Firewall threat intel hits
  - NSG rule changes
  - Resource creation/deletion in platform subscriptions

**Modules to use**:
- [avm-res-operationalinsights-workspace](https://registry.terraform.io/modules/Azure/avm-res-operationalinsights-workspace/azurerm/latest)

**Acceptance Criteria**:
- ✅ Log Analytics workspace created
- ✅ Diagnostics flowing from hub resources
- ✅ Action group configured
- ✅ Sample alert rule created and tested

---

### Phase 3.4: Security Baseline (Layer 04)

**Status**: ⚪ TODO  
**Owner**: TBD  
**Effort**: 6 hours

**Tasks**:

**Subtask 3.4.1: Key Vault for Secrets**
- [ ] Use AVM module: `avm-res-keyvault-vault`
- [ ] Deploy in Platform-Security subscription
- [ ] Name: `kv-platform-sec-prod-{random}` (KV names must be globally unique)
- [ ] Enable RBAC for access control
- [ ] Enable soft delete (default) and purge protection

**Subtask 3.4.2: Azure Policy Assignments**
- [ ] Create/assign policies for:
  - Enforce TLS 1.2+ on resources
  - Enforce encryption at rest
  - Enforce tagging on resources
  - Enforce managed identity on resources
  - Deny public IP if non-compliant
  - Enforce Network Security Group Flow Logs

- [ ] Assign at management group levels:
  - Root: Compliance baselines
  - Platform: Stricter security
  - Landing Zones: Workload policies

**Subtask 3.4.3: Microsoft Sentinel (optional, cost: ~$300-1,000/mo)**
- [ ] Create security subscription resources (if enabled)
- [ ] Deploy Log Analytics workspace for Sentinel
- [ ] Enable Sentinel solution
- [ ] Connect data sources (optional: Activity Logs, Firewall logs)

**Modules to use**:
- [avm-res-keyvault-vault](https://registry.terraform.io/modules/Azure/avm-res-keyvault-vault/azurerm/latest)
- Policy modules (custom or community)

**Acceptance Criteria**:
- ✅ Key Vault created and accessible
- ✅ Policies assigned to management groups
- ✅ Policy compliance reports available
- ✅ Sentinel deployed (if enabled)

---

### Phase 3.5: Sandbox Landing Zone (Layer 05)

**Status**: 🟢 PARTIAL (Sandbox module exists from Phase 1.3)  
**Owner**: TBD  
**Effort**: 2 hours  
**Acceptance Criteria Met**: ✅ (see Phase 1.3 completion report)

**Reference**: [TASK-1.3-COMPLETION-REPORT.md](docs/TASK-1.3-COMPLETION-REPORT.md)

**Summary**: Terraform sandbox module complete with feature toggle for safe deployment.

---

## 📊 Progress Tracking

### Deployment Status by Phase

| Phase | Name | Status | % Complete | Blocker | Next Step |
|-------|------|--------|------------|---------|-----------|
| Phase 0 | Planning | 🟡 50% | ❌ Naming/Tagging | Define standards | Phase 0.2/0.3 TODO |
| Phase 1 | Prerequisites | ⚪ 0% | ❌ All | Start Phase 1.1 | Blocked by Phase 0 |
| Phase 2 | Bootstrap | 🟢 30% | ✅ Repo exists | Verify workflows | Phase 2.2 TODO |
| Phase 3 | Run | ⚪ 0% | ✅ None | Start Layer 00 | Blocked by Phase 1 |
| **Overall** | | 🟡 **10%** | | | Phase 0 completion |

### Critical Path

```
Phase 0 (Naming/Tagging) ─→ Phase 1 (Subscriptions/SPs) ─→ Phase 2 (Workflows) ─→ Phase 3 (Deploy)
    2h                         8h                            2h                      30h
    ├─ Naming                  ├─ Subscriptions              ├─ TFC setup            ├─ Layer 00: MG
    └─ Tagging                 ├─ OIDC                       ├─ Workflows            ├─ Layer 01: Identity
                               └─ Groups/SPs                 └─ Test                 ├─ Layer 02: Hub
                                                                                       ├─ Layer 03: Mgmt
                                                                                       ├─ Layer 04: Security
                                                                                       └─ Layer 05: Sandbox
```

**Duration Estimate**: 40+ hours total (5-6 days effort)

---

## 📚 Key Documentation

All documentation lives in `docs/` folder:

1. **[NAMING-CONVENTION.md](docs/NAMING-CONVENTION.md)** - Resource naming patterns
2. **[TAGGING-STRATEGY.md](docs/TAGGING-STRATEGY.md)** - Tag requirements and examples
3. **[SUBSCRIPTIONS.md](docs/SUBSCRIPTIONS.md)** - Subscription inventory and mapping
4. **[SERVICE-PRINCIPALS.md](docs/SERVICE-PRINCIPALS.md)** - SPs, permissions, and OIDC configs
5. **[RBAC-GROUPS.md](docs/RBAC-GROUPS.md)** - Entra groups and role assignments
6. **[DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md)** - Step-by-step deployment runbook
7. **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Diagram of hub-spoke topology
8. **[AVM-COMPLIANCE.md](docs/AVM-COMPLIANCE.md)** - Verification all modules follow AVM standards

---

## 🔗 References

### Microsoft Documentation
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/)
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [CAF Naming Conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [CAF Tagging Strategy](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)

### Terraform Resources
- [Terraform Cloud](https://www.terraform.io/cloud-docs)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Azure Verified Modules Registry](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/latest)

### GitHub & DevOps
- [GitHub Actions Security](https://docs.github.com/actions/security-guides)
- [OIDC Provider Configuration](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

---

## ✅ Getting Started Now

**Immediate Actions** (next 2 hours):

1. [ ] Review this TODO.md with team
2. [ ] Assign owners to Phase 0.2 and Phase 0.3 tasks
3. [ ] Begin Phase 0.2: Define naming convention
4. [ ] Begin Phase 0.3: Define tagging strategy
5. [ ] Schedule Phase 1 kickoff for when Phase 0 completes

**Success Metrics**:
- ✅ All phases completed in order
- ✅ All resources follow naming/tagging standards
- ✅ CI/CD workflows passing
- ✅ Platform deployed via IaC
- ✅ Audit trail in git + TFC
- ✅ Zero manual resources in platform subscriptions

---

**Document Version**: 2.0  
**Last Updated**: June 30, 2026  
**Owner**: Platform Engineering Team  
**Status**: ✅ APPROVED - Refocused to proper ALZ phases


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

