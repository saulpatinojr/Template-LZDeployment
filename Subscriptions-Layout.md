<!-- Source: docs/DES-SUBSCRIPTIONS-LAYOUT.md -->
<!-- Last migrated: 2026-06-30 -->

# Azure Subscription Inventory & Architecture

**Document ID**: DOC-SUBSCRIPTIONS-001  
**Version**: 1.0  
**Status**: 📋 PLANNING (subscriptions not yet created)  
**Last Updated**: 2026-06-30  
**Owner**: Platform Engineering  
**Review Date**: 2026-12-30

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Subscription Architecture](#subscription-architecture)
3. [Platform Subscriptions](#platform-subscriptions)
4. [Workload Subscriptions](#workload-subscriptions)
5. [Management Group Mapping](#management-group-mapping)
6. [Subscription Creation Checklist](#subscription-creation-checklist)
7. [Billing & Cost Allocation](#billing--cost-allocation)
8. [Access & RBAC](#access--rbac)

---

## Overview

The Azure landing zone uses a **multi-subscription model** following the hub-spoke topology:

**Key Principles**:
1. **Subscriptions as boundaries**: Each subscription = unit of management/billing
2. **Platform separation**: Platform services isolated from workloads
3. **Environment isolation**: Production, nonprod, dev segregated
4. **Scalability**: Add workload subscriptions without platform impact

**Benefits**:
- Cost tracking per workload/team
- Blast radius containment (subscription-level incidents)
- Separate RBAC per environment
- Resource quota management (subscriptions have limits)
- Governance at subscription level

---

## Subscription Architecture

### Target State Diagram

```
Tenant Root
└── Azure Subscription (Enterprise)
    │
    ├── PLATFORM SUBSCRIPTIONS (Shared services)
    │   ├── Platform-Hub (Connectivity)
    │   ├── Platform-Identity (Identity services)
    │   ├── Platform-Management (Monitoring/Ops)
    │   └── Platform-Security (Sentinel/SOC)
    │
├── WORKLOAD SUBSCRIPTIONS (Application landing zones)
    │   ├── Workload-Prod (First production workload)
    │   ├── Workload-Sandbox (Developer experimentation)
    │   └── [Additional workloads added via vending]
    │
└── DECOMMISSIONED (Retired subscriptions)
```

### Subscription Count

| Category | Count | Purpose | Total Seats |
|----------|-------|---------|-------------|
| Platform | 4 | Shared services | 4 |
| Workload (initial) | 2 | Applications | 2 |
| **Total Phase 3** | 6 | | 6 |
| Future workloads | N | Via vending | As needed |

---

## Platform Subscriptions

Platform subscriptions are **created once** and host **shared services** used by all workloads.

### 1. Platform-Hub (Connectivity)

**Purpose**: Central networking for all workloads

**Subscription Details**:

| Attribute | Value |
|-----------|-------|
| **Name** | `sub-{org}-platform-hub-prod` |
| **Environment** | Production (platform services tier-1) |
| **Region Primary** | East US |
| **Region Secondary** | West US |
| **Management Group** | Platform/Connectivity |
| **Billing Account** | Centralized (Finance) |
| **Monthly Cost Estimate** | $500-2,000 |

**Resources to Deploy**:

| Resource | Name | Purpose |
|----------|------|---------|
| Virtual Network | `vnet-hub-platform-prod-eastus-01` | Hub vnet |
| Subnets | `snet-gateway/firewall/mgmt/bastion` | Hub subnets |
| Azure Firewall | `fw-hub-prod-eastus-01` | Central firewall |
| VPN Gateway | `vpn-hub-prod-eastus-01` | On-premises connectivity (optional) |
| Network Security Groups | `nsg-*-hub-prod-*` | Subnet isolation |
| Public IPs | `pip-fw-hub-prod-eastus-01` | Firewall public IP |
| Route Tables | `rt-hub-prod-eastus-01` | Hub routing |

**Access Control**:
- **Contributor**: `Azure-platform-admins` (deploy/modify hub)
- **Reader**: `Azure-platform-readers` (view only)

**Example subscription IDs** (to be filled during creation):
```
sub-acme-platform-hub-prod: 12345678-1234-1234-1234-123456789abc
```

---

### 2. Platform-Identity

**Purpose**: Identity & access management

**Subscription Details**:

| Attribute | Value |
|-----------|-------|
| **Name** | `sub-{org}-platform-identity-prod` |
| **Environment** | Production |
| **Region** | East US |
| **Management Group** | Platform/Identity |
| **Monthly Cost Estimate** | $0-200 |

**Resources to Deploy**:

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `rg-platform-identity-prod-eastus-01` | Container |
| Virtual Network | `vnet-identity-prod-eastus-01` | Identity vnet (optional) |
| VMs (optional) | `vm-dc-identity-prod-eastus-{01,02}` | Domain controllers (hybrid) |
| Key Vault | `kv-identity-prod-eastus-01` | Identity secrets |
| Managed Identity | (various) | Service principal vaults |

**Access Control**:
- **Contributor**: `Azure-identity-team` (manage identity resources)
- **Reader**: `Azure-platform-admins` (monitor)

**Notes**:
- This subscription is typically SMALL (minimal resources)
- Used for hybrid identity (AD DS) if applicable
- Stores Entra integration credentials

---

### 3. Platform-Management

**Purpose**: Centralized monitoring, logging, automation

**Subscription Details**:

| Attribute | Value |
|-----------|-------|
| **Name** | `sub-{org}-platform-management-prod` |
| **Environment** | Production |
| **Region** | East US |
| **Management Group** | Platform/Management |
| **Monthly Cost Estimate** | $100-500 |

**Resources to Deploy**:

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `rg-platform-mgmt-prod-eastus-01` | Container |
| Log Analytics Workspace | `log-platform-mgmt-prod-eastus-01` | Central logging |
| Automation Account | `aa-platform-mgmt-prod-eastus-01` | Runbooks (optional) |
| Storage Account | `st-flowlogs-prod-eastus-01` | NSG flow logs |
| Key Vault | `kv-mgmt-prod-eastus-01` | Platform secrets |
| Action Group | `ag-platform-alerts-prod` | Alert recipients |
| Diagnostic Settings | (on each platform resource) | Route logs to Log Analytics |

**Access Control**:
- **Contributor**: `Azure-operations-team`
- **Reader**: `Azure-platform-admins`

**Cost Breakdown**:
- Log Analytics: ~$50-300/month (depends on data volume)
- Storage for flow logs: ~$20-50/month
- Automation/monitoring: ~$30-150/month

---

### 4. Platform-Security (Optional but Recommended)

**Purpose**: Security operations, threat detection, compliance

**Subscription Details**:

| Attribute | Value |
|-----------|-------|
| **Name** | `sub-{org}-platform-security-prod` |
| **Environment** | Production |
| **Region** | East US |
| **Management Group** | Platform/Security |
| **Monthly Cost Estimate** | $0 (baseline) + $300-1,000 (if Sentinel enabled) |

**Resources to Deploy**:

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `rg-platform-security-prod-eastus-01` | Container |
| Log Analytics Workspace | `log-sentinel-sec-prod-eastus-01` | Sentinel data store |
| Microsoft Sentinel | (via solution) | SIEM/SOC tooling |
| Key Vault | `kv-sec-prod-eastus-01` | Security secrets |
| Storage Account | `st-sec-logs-prod-eastus-01` | Security logs archive |

**Access Control**:
- **Contributor**: `Azure-security-team`
- **Reader**: `Azure-operations-team`

**Notes**:
- Can be created later (Phase 3.4)
- Sentinel is optional but recommended for enterprises
- Significant cost if data ingestion is high

---

## Workload Subscriptions

Workload subscriptions are created **per application/team** and house business workloads.

### 1. Workload-Prod (First Workload)

**Purpose**: First production application workload

**Subscription Details**:

| Attribute | Value |
|-----------|-------|
| **Name** | `sub-{org}-workload-{app}-prod` |
| **Example** | `sub-acme-workload-payroll-prod` |
| **Environment** | Production |
| **Management Group** | Landing Zones/Prod |
| **Monthly Cost Estimate** | $500-5,000+ (workload-dependent) |

**Example Resources**:

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group (Network) | `rg-spoke-payroll-prod-eastus-01` | Networking |
| Virtual Network | `vnet-spoke-payroll-prod-eastus-01` | Spoke vnet |
| Subnets | `snet-web/app/data-payroll-prod` | Tier isolation |
| Resource Group (Compute) | `rg-app-payroll-prod-eastus-01` | Application |
| App Service Plan | `asp-payroll-prod-eastus-01` | Web tier |
| App Service | `app-payroll-prod-eastus-01` | Application |
| Resource Group (Data) | `rg-data-payroll-prod-eastus-01` | Data tier |
| SQL Server | `sql-payroll-prod-eastus-01` | Database server |
| SQL Database | `sqldb-payroll-prod-eastus-01` | Application database |
| Key Vault | `kv-payroll-prod-eastus-01` | App secrets |
| Application Insights | `appi-payroll-prod-eastus-01` | Monitoring |
| Storage Account | `st-payroll-prod-eastus-01` | Blob/file storage |

**Access Control**:
- **Contributor**: `Azure-payroll-team`, `Azure-platform-admins`
- **Reader**: `Azure-operations-team`

**RBAC Strategy**:
- Workload team has Contributor (can deploy/manage resources)
- Platform team has Contributor (ensure compliance)
- Ops has Reader (monitoring/troubleshooting)

---

### 2. Workload-Sandbox

**Purpose**: Developer experimentation & testing

**Subscription Details**:

| Attribute | Value |
|-----------|-------|
| **Name** | `sub-{org}-sandbox-nonprod` |
| **Environment** | Sandbox (non-production) |
| **Management Group** | Landing Zones/Sandboxes |
| **Monthly Cost Estimate** | $50-200 |

**Resources to Deploy**:

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `rg-sandbox-workload-nonprod-eastus-01` | Container |
| Virtual Network | `vnet-sandbox-nonprod-eastus-01` | Sandbox vnet |
| Virtual Machines | `vm-app-sandbox-nonprod-eastus-{01,02}` | Dev/test VMs |
| App Service Plan | `asp-sandbox-nonprod-eastus-01` | Web app test |
| Storage Account | `st-sandbox-nonprod-eastus-01` | Test data |
| SQL Database | `sqldb-app-sandbox-nonprod-eastus-01` | Test database |

**Access Control**:
- **Contributor**: `Azure-engineering-team` (all engineers can deploy)
- **Reader**: `Azure-operations-team`

**Policy Differences** (less restrictive):
- Allow public IPs (for testing)
- Allow any VM SKU (not restricted to prod sizes)
- Auto-shutdown enabled (cost optimization)
- No backup required

---

## Management Group Mapping

### Visual Hierarchy

```
Tenant Root Group
│
└── Intermediate Root (mg-{org}-lz)
    │
    ├── PLATFORM (mg-platform)
    │   │
    │   ├── Connectivity (mg-platform-connectivity)
    │   │   └── sub-{org}-platform-hub-prod
    │   │
    │   ├── Identity (mg-platform-identity)
    │   │   └── sub-{org}-platform-identity-prod
    │   │
    │   ├── Management (mg-platform-management)
    │   │   └── sub-{org}-platform-management-prod
    │   │
    │   └── Security (mg-platform-security)
    │       └── sub-{org}-platform-security-prod
    │
    ├── LANDING ZONES (mg-landing-zones)
    │   │
    │   ├── Prod (mg-landing-zones-prod)
    │   │   └── sub-{org}-workload-{app}-prod
    │   │       └── sub-{org}-workload-payroll-prod
    │   │
    │   ├── Nonprod (mg-landing-zones-nonprod)
    │   │   └── (Dev/test workload subscriptions)
    │   │
    │   └── Sandbox (mg-landing-zones-sandbox)
    │       └── sub-{org}-sandbox-nonprod
    │
    └── DECOMMISSIONED (mg-decommissioned)
        └── (Retired subscriptions, auto-delete after 30-60 days)
```

### Policy Assignment Hierarchy

```
Policies cascade from parent to child:

Root (Tenant)
  ↓ Compliance baseline policies
Intermediate Root (mg-{org}-lz)
  ↓ Organization policies
Platform (mg-platform)
  ↓ Platform-specific policies (stricter)
  ├─→ Platform-Connectivity (mg-platform-connectivity)
  ├─→ Platform-Identity
  ├─→ Platform-Management
  └─→ Platform-Security
Landing Zones (mg-landing-zones)
  ↓ Workload policies
  ├─→ Prod (mg-landing-zones-prod) [Strict]
  ├─→ Nonprod (mg-landing-zones-nonprod) [Moderate]
  └─→ Sandbox (mg-landing-zones-sandbox) [Permissive]
```

---

## Subscription Creation Checklist

### Pre-Creation Planning

- [ ] **Define naming convention** → Align with NAMING-CONVENTION.md
- [ ] **Define tagging strategy** → Align with TAGGING-STRATEGY.md
- [ ] **Identify cost centers** → Finance provides cost codes
- [ ] **Identify subscription admins** → Who can manage each subscription
- [ ] **Confirm billing setup** → Enterprise Agreement, CSP, or Pay-as-you-go

### Subscription Creation Steps

For each subscription:

**Step 1: Create Subscription**
```bash
# Create via Azure CLI
az account create-subscription \
  --billing-account-name "{billing-account-id}" \
  --display-name "sub-acme-platform-hub-prod" \
  --workload "Production"

# Record subscription ID
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

**Step 2: Set Subscription Tags**
```bash
# Tag the subscription itself
az tag create \
  --resource-id "/subscriptions/${SUBSCRIPTION_ID}" \
  --tags Environment=prod Application=platform Owner=platform-team
```

**Step 3: Move to Management Group**
```bash
# Move subscription to management group
az management-group subscription add \
  --name "mg-platform-connectivity" \
  --subscription "${SUBSCRIPTION_ID}"
```

**Step 4: Configure Billing Alerts**
```bash
# Set up budget alert (example: $5,000/month limit)
az billing account create-budget \
  --subscription-id "${SUBSCRIPTION_ID}" \
  --display-name "Platform-Hub Monthly Budget" \
  --amount 5000 \
  --time-period "Monthly"
```

**Step 5: Assign RBAC**
```bash
# Assign Contributor to platform-admins group
az role assignment create \
  --subscription "${SUBSCRIPTION_ID}" \
  --role "Contributor" \
  --assignee-object-id "{platform-admins-group-id}"
```

**Step 6: Document**
- [ ] Add to subscription inventory table (below)
- [ ] Record in password manager (subscription owner credentials)
- [ ] Create Jira/Azure DevOps ticket for team notification

---

## Subscription Inventory

### Current State (To be populated)

| Subscription Name | ID | Environment | Workload | MG Parent | Monthly Budget | Owner | Status |
|-------------------|----|----|----------|-----------|---|--------|--------|
| `sub-acme-platform-hub-prod` | `TBD` | prod | platform | Platform/Connectivity | $1,000 | platform-team | ⚪ TODO |
| `sub-acme-platform-identity-prod` | `TBD` | prod | platform | Platform/Identity | $100 | identity-team | ⚪ TODO |
| `sub-acme-platform-mgmt-prod` | `TBD` | prod | platform | Platform/Management | $300 | operations-team | ⚪ TODO |
| `sub-acme-platform-security-prod` | `TBD` | prod | platform | Platform/Security | $500 | security-team | ⚪ TODO |
| `sub-acme-workload-payroll-prod` | `TBD` | prod | payroll | Landing Zones/Prod | $2,000 | payroll-team | ⚪ TODO |
| `sub-acme-sandbox-nonprod` | `TBD` | sandbox | sandbox | Landing Zones/Sandbox | $200 | engineering-team | ⚪ TODO |

### Future Workload Subscriptions

```
Template for new workloads via subscription vending:

| sub-{org}-workload-{app}-prod | {NEW-ID} | prod | {app} | Landing Zones/Prod | {Budget} | {team} | ⚪ PENDING |
| sub-{org}-workload-{app}-nonprod | {NEW-ID} | nonprod | {app} | Landing Zones/Nonprod | {Budget} | {team} | ⚪ PENDING |
```

---

## Billing & Cost Allocation

### Cost Management Setup

1. **Subscriptions in Billing Reports**:
   ```sql
   -- Monthly cost breakdown by subscription
   SELECT 
     SubscriptionName,
     SUM(Cost) as MonthlyCost
   FROM AzureUsage
   WHERE Month = '2026-06'
   GROUP BY SubscriptionName
   ORDER BY MonthlyCost DESC
   ```

2. **Chargeback by Application**:
   ```sql
   SELECT 
     Application,
     Owner,
     CostCenter,
     SUM(Cost) as TotalCost
   FROM AzureUsage
   WHERE Month = '2026-06'
   GROUP BY Application, Owner, CostCenter
   ```

3. **Platform Cost Allocation**:
   - Platform subscriptions shared across all workloads
   - Allocate proportionally by workload consumption
   - OR: Fixed allocation to each workload team

### Budget Alerts

Each subscription has automated budget monitoring:

| Subscription | Monthly Budget | Alert at 50% | Alert at 75% | Alert at 100% |
|--------------|----------------|------------|------------|--------------|
| Platform-Hub | $1,000 | $500 | $750 | $1,000 |
| Platform-Mgmt | $300 | $150 | $225 | $300 |
| Workload-Prod | $2,000 | $1,000 | $1,500 | $2,000 |
| Sandbox | $200 | $100 | $150 | $200 |

---

## Access & RBAC

### Subscription-Level Roles

Assign at subscription level (inherited by all resources):

**Example for Platform-Hub subscription**:

```bash
# Contributors (can deploy/modify)
az role assignment create \
  --subscription "sub-acme-platform-hub-prod" \
  --role "Contributor" \
  --assignee-object-id "{azure-platform-admins-id}"

# Readers (can view only)
az role assignment create \
  --subscription "sub-acme-platform-hub-prod" \
  --role "Reader" \
  --assignee-object-id "{azure-platform-readers-id}"

# Network Contributor (for network admins)
az role assignment create \
  --subscription "sub-acme-platform-hub-prod" \
  --role "Network Contributor" \
  --assignee-object-id "{azure-network-admins-id}"
```

### Entra Groups Required

Create these groups in Entra ID:

| Group | Role | Scope | Members |
|-------|------|-------|---------|
| `Azure-platform-admins` | Contributor | All Platform subscriptions | Platform engineers |
| `Azure-platform-readers` | Reader | All Platform subscriptions | Support/Ops staff |
| `Azure-workload-{app}-admins` | Contributor | Workload-specific subscription | App team leads |
| `Azure-security-team` | Contributor | Platform-Security | Security engineers |
| `Azure-operations-team` | Reader | All Platform subscriptions | NOC/Ops |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-30 | Platform Engineering | Initial subscription architecture |

---

## Related Documents

- [NAMING-CONVENTION.md](NAMING-CONVENTION.md) - Subscription naming rules
- [TAGGING-STRATEGY.md](TAGGING-STRATEGY.md) - Subscription tagging
- [RBAC-GROUPS.md](RBAC-GROUPS.md) - Detailed RBAC configuration
- [SERVICE-PRINCIPALS.md](SERVICE-PRINCIPALS.md) - SPs for each subscription

---

**Questions?** Contact Platform Engineering Team


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

