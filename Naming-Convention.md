<!-- Source: docs/STD-NAMING-CONVENTION.md -->
<!-- Last migrated: 2026-06-30 -->

# Azure Resource Naming Convention

**Document ID**: DOC-NAMING-CONVENTION-001  
**Version**: 1.0  
**Status**: ✅ APPROVED  
**Last Updated**: 2026-06-30  
**Owner**: Platform Engineering  
**Review Date**: 2026-12-30

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Naming Pattern](#naming-pattern)
3. [Components & Rules](#components--rules)
4. [Resource Type Abbreviations](#resource-type-abbreviations)
5. [Examples by Layer](#examples-by-layer)
6. [Enforcement](#enforcement)
7. [Exceptions & Deviations](#exceptions--deviations)

---

## Overview

A consistent naming convention is essential for:
- **Discoverability**: Quickly find resources in Azure Portal
- **Automation**: Scripts can parse resource names for logic
- **Compliance**: Audit trails show resource purpose
- **Cost Tracking**: Resource names aid in chargeback
- **Governance**: Policy enforcement can validate names

This convention aligns with:
- [Microsoft CAF Naming Best Practices](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Azure Verified Modules TFNFR4](https://azure.github.io/Azure-Verified-Modules/specs/terraform/#code-style-standards) - Lower snake_casing requirement

---

## Naming Pattern

### Master Format

```
{resource-type}-{workload}-{environment}-{region}-{instance}
```

### Component Descriptions

| Component | Length | Format | Example | Required |
|-----------|--------|--------|---------|----------|
| **resource-type** | 2-6 chars | lowercase abbr | vnet, fw, kv, rg | ✅ YES |
| **workload** | 3-10 chars | lowercase | hub, mgmt, identity, spoke | ✅ YES |
| **environment** | 4-7 chars | lowercase | prod, nonprod, dev, test | ✅ YES |
| **region** | 3-6 chars | lowercase code | eastus, westus, northeu | ✅ YES |
| **instance** | 2 chars | numeric | 01, 02, 03 | ✅ YES |

### Separator

- **Primary Separator**: Hyphen `-` (not underscore)
- **All components in lowercase** (AVM requirement TFNFR4)
- **No spaces, underscores, or special characters**

### Total Length

Most Azure resources: **Max 60-64 characters** (varies by type)
- **Virtual Networks**: 64 chars max
- **Storage Accounts**: 24 chars (no hyphens!) - use `stg{workload}{env}{region}##`
- **Key Vaults**: 24 chars - use `kv-{workload}-{env}-{region}-##`
- **Log Analytics**: 63 chars
- **Automation Accounts**: 50 chars

---

## Components & Rules

### 1. Resource Type (2-6 characters)

Use lowercase abbreviation from the standard table below. Examples:
- `vnet` = Virtual Network
- `fw` = Azure Firewall
- `kv` = Key Vault
- `rg` = Resource Group
- `nsg` = Network Security Group
- `log` = Log Analytics Workspace
- `st` = Storage Account (but special: `st{no-hyphens}`)

**Rule**: Always use the STANDARD abbreviation from the table—never invent.

---

### 2. Workload (3-10 characters)

Identifies the logical workload or platform component:

| Workload | Usage | Examples |
|----------|-------|----------|
| `hub` | Hub network (platform) | vnet-hub-prod-eastus-01 |
| `spoke` | Spoke vnet (workload) | vnet-spoke-app01-prod-eastus-01 |
| `mgmt` | Management/Ops | log-mgmt-prod-eastus-01 |
| `identity` | Identity/Entra | kv-identity-prod-eastus-01 |
| `sec` or `security` | Security/Sentinel | kv-sec-prod-eastus-01 |
| `{app-name}` | Specific workload | vnet-payroll-prod-eastus-01 |

**Rule**: 3-10 characters, lowercase, meaningful to the team. Avoid generic names like `data` or `app`.

---

### 3. Environment (4-7 characters)

Identifies the SDLC stage:

| Environment | Code | Tier | Purpose |
|-------------|------|------|---------|
| Production | `prod` | Tier-1 | Live customer workloads |
| Non-Production | `nonprod` | Tier-2 | Staging, pre-prod |
| Development | `dev` | Tier-3 | Developer workspaces |
| Test | `test` | Tier-3 | Functional/regression testing |
| Sandbox | `sandbox` | Tier-4 | Experimentation, POCs |

**Rule**: Always use the exact code from table above. Do NOT use `p`, `d`, `t`, `s` (too ambiguous).

**Platform Resources** (special case):
- Platform services (hub, mgmt, identity) typically use `prod` environment
- Separate platform dev/staging only if testing new capabilities

---

### 4. Region (3-6 characters)

Azure region identifier (lowercase):

| Region | Code | Notes |
|--------|------|-------|
| East US | `eastus` | Primary region for demo |
| West US | `westus` | Secondary/DR region |
| North Europe | `northeu` | EU workloads |
| West Europe | `westeu` | EU DR |
| Southeast Asia | `seasia` | Asia-Pacific |
| East Asia | `easia` | Asia-Pacific |
| Central US | `centreus` | Backup region |
| Canada East | `caeast` | Canada |
| UK South | `ukso` | UK |

**Rule**: Use 3-6 character lowercase code. Run `az account list-locations --query "[].name" --output table` for official names.

---

### 5. Instance (2 characters)

Numeric instance counter for multi-deployment scenarios:

| Scenario | Naming |
|----------|--------|
| Single deployment | `-01` (always start at 01) |
| Scale-out (5 resources) | `-01`, `-02`, `-03`, `-04`, `-05` |
| Failover pair | `-01` (primary), `-02` (secondary/DR) |

**Rule**: Always zero-padded, always start at `-01`, even for single resource.

**Exception**: Storage accounts and Key Vaults use `##` (no hyphens) due to character restrictions.

---

## Resource Type Abbreviations

### Networking

| Resource Type | Abbreviation | Example | Max Length |
|---------------|--------------|---------|------------|
| Virtual Network | `vnet` | vnet-hub-prod-eastus-01 | 64 |
| Subnet | `snet` | snet-gateway-hub-prod-eastus-01 | 80 |
| Network Security Group | `nsg` | nsg-hub-mgmt-prod-eastus-01 | 80 |
| Network Interface | `nic` | nic-vm-app-prod-eastus-01 | 80 |
| Public IP | `pip` | pip-fw-hub-prod-eastus-01 | 80 |
| Azure Firewall | `fw` | fw-hub-prod-eastus-01 | 80 |
| VPN Gateway | `vpn` | vpn-hub-prod-eastus-01 | 80 |
| ExpressRoute Gateway | `erg` | erg-hub-prod-eastus-01 | 80 |
| Azure Bastion | `bas` | bas-hub-prod-eastus-01 | 80 |
| Application Gateway | `appgw` | appgw-app-prod-eastus-01 | 80 |
| Load Balancer | `lb` | lb-app-prod-eastus-01 | 80 |
| Traffic Manager | `tm` | tm-app-prod-global-01 | 63 |

### Security & Identity

| Resource Type | Abbreviation | Example | Max Length |
|---------------|--------------|---------|------------|
| Key Vault | `kv` | kv-sec-prod-eastus-01 | 24 (special) |
| Application Insights | `appi` | appi-app-prod-eastus-01 | 255 |
| Log Analytics Workspace | `log` | log-mgmt-prod-eastus-01 | 63 |
| Azure Sentinel | `sent` | sent-sec-prod-eastus-01 | 63 |
| Automation Account | `aa` | aa-mgmt-prod-eastus-01 | 50 |

### Storage & Databases

| Resource Type | Abbreviation | Example | Max Length |
|---------------|--------------|---------|------------|
| Storage Account | `st` | stghubprodeastus01 | 24 (no hyphens!) |
| Blob Container | `blob` | blob-logs-prod | 63 |
| File Share | `fsh` | fsh-data-prod | 63 |
| Azure SQL Server | `sql` | sql-app-prod-eastus-01 | 63 |
| Azure SQL Database | `sqldb` | sqldb-app-prod-eastus-01 | 128 |
| Azure Database for MySQL | `mysql` | mysql-app-prod-eastus-01 | 63 |
| Azure Database for PostgreSQL | `psql` | psql-app-prod-eastus-01 | 63 |
| Cosmos DB Account | `cosmos` | cosmos-app-prod-eastus-01 | 44 |

### Compute

| Resource Type | Abbreviation | Example | Max Length |
|---------------|--------------|---------|------------|
| Virtual Machine | `vm` | vm-app-prod-eastus-01 | 64 (Windows), 63 (Linux) |
| VM Scale Set | `vmss` | vmss-app-prod-eastus-01 | 64 |
| App Service Plan | `asp` | asp-web-prod-eastus-01 | 40 |
| App Service (Web App) | `app` | app-web-prod-eastus-01 | 60 |
| Function App | `func` | func-process-prod-eastus-01 | 60 |
| Container Registry | `acr` | acrhubprodeastus01 | 50 (no hyphens!) |
| AKS Cluster | `aks` | aks-app-prod-eastus-01 | 63 |

### Management & Monitoring

| Resource Type | Abbreviation | Example | Max Length |
|---------------|--------------|---------|------------|
| Resource Group | `rg` | rg-hub-platform-prod-eastus-01 | 90 |
| Subscription | `sub` | sub-platform-hub-prod | N/A (not in resource name) |
| Management Group | `mg` | mg-platform-hub | 80 |
| Policy Definition | `pol` | pol-enforce-tls-12 | 64 |
| Policy Assignment | `pa` | pa-enforce-tls-12 | 64 |
| Role Definition | `role` | role-platform-admin | N/A |
| Recovery Services Vault | `rsv` | rsv-backup-prod-eastus-01 | 50 |

---

## Examples by Layer

### Layer 00: Management Groups & Policies

```
# Management Groups (not prefixed with hyphens in MG names)
mg-intermediate-root
mg-platform
mg-platform-connectivity
mg-platform-identity
mg-platform-management
mg-platform-security
mg-landing-zones
mg-landing-zones-prod
mg-landing-zones-nonprod
mg-landing-zones-sandbox
mg-decommissioned

# Policies
pol-enforce-tls-12-minimum
pol-enforce-tagging-mandatory
pol-enforce-managed-identity
pol-deny-public-ip-on-nics
pol-enforce-nsg-flow-logs
```

### Layer 01: Platform Identity Subscription

```
# Resource Group
rg-platform-identity-prod-eastus-01

# Key Vault for identity secrets
kv-identity-prod-eastus-01

# Optional: VMs for domain controllers (if hybrid identity)
vm-dc-identity-prod-eastus-01
vm-dc-identity-prod-eastus-02

# Network resources
vnet-identity-prod-eastus-01
snet-identity-prod-eastus-01
nsg-identity-prod-eastus-01
```

### Layer 02: Platform Hub Networking

```
# Hub Subscription Resource Groups
rg-hub-network-prod-eastus-01
rg-hub-security-prod-eastus-01

# Virtual Networks
vnet-hub-platform-prod-eastus-01

# Subnets
snet-gateway-hub-prod-eastus-01
snet-firewall-hub-prod-eastus-01
snet-mgmt-hub-prod-eastus-01
snet-bastion-hub-prod-eastus-01

# Firewall
fw-hub-prod-eastus-01
pip-fw-hub-prod-eastus-01

# Gateway (if hybrid connectivity)
vpn-hub-prod-eastus-01
erg-hub-prod-eastus-01

# NSGs
nsg-gateway-hub-prod-eastus-01
nsg-firewall-hub-prod-eastus-01
nsg-mgmt-hub-prod-eastus-01

# Bastion (optional)
bas-hub-prod-eastus-01
pip-bas-hub-prod-eastus-01
nsg-bas-hub-prod-eastus-01
```

### Layer 03: Platform Management & Monitoring

```
# Management Subscription Resource Groups
rg-platform-mgmt-prod-eastus-01

# Log Analytics Workspace
log-platform-mgmt-prod-eastus-01

# Automation Account (optional)
aa-platform-mgmt-prod-eastus-01

# Storage for flow logs
st-flowlogs-prod-eastus-01

# Action Groups (no standard abbreviation, use logical name)
ag-platform-alerts-prod
```

### Layer 04: Platform Security

```
# Security Subscription Resource Groups
rg-platform-security-prod-eastus-01

# Key Vault for platform secrets
kv-platform-sec-prod-eastus-01

# Log Analytics for Sentinel
log-sentinel-sec-prod-eastus-01

# Azure Sentinel (deployed as solution to Log Analytics)
# No separate resource, but referenced as: sent-sec-prod-eastus-01

# Storage for security logs
st-sec-logs-prod-eastus-01
```

### Layer 05: Workload Sandbox Landing Zone

```
# Sandbox Subscription Resource Groups
rg-sandbox-workload-nonprod-eastus-01

# Sandbox networking
vnet-sandbox-nonprod-eastus-01
snet-sandbox-nonprod-eastus-01
nsg-sandbox-nonprod-eastus-01

# Sandbox compute (developers can experiment)
vm-app-sandbox-nonprod-eastus-01
app-sandbox-nonprod-eastus-01
aspnet-sandbox-nonprod-eastus-01

# Sandbox data
sqldb-app-sandbox-nonprod-eastus-01
st-sandbox-nonprod-eastus-01
```

### Workload Spoke Example (Layer 6+)

```
# Workload Subscription: Payroll Application
# Resource Group
rg-spoke-payroll-prod-eastus-01

# Networking
vnet-spoke-payroll-prod-eastus-01
snet-web-payroll-prod-eastus-01
snet-data-payroll-prod-eastus-01
nsg-web-payroll-prod-eastus-01
nsg-data-payroll-prod-eastus-01

# Compute
aspnet-payroll-prod-eastus-01
vm-web-payroll-prod-eastus-01
vm-app-payroll-prod-eastus-01
vmss-api-payroll-prod-eastus-01

# Data
sqldb-payroll-prod-eastus-01
st-payroll-prod-eastus-01

# Monitoring
appi-payroll-prod-eastus-01

# Security
kv-payroll-prod-eastus-01
```

---

## Special Cases

### Storage Accounts (No Hyphens)

Storage account names cannot contain hyphens (24-char max, alphanumeric only).

**Format**: `st{workload}{environment}{region}{instance}`

```
stghubprodeastus01          # Hub platform storage
stgmgmtprodeastus01         # Management storage
stglogsprodeastus01         # Flow logs storage
stgsandboxnpeastus01        # Sandbox storage
stgpayrollprodeastus01      # Workload storage
```

**Rule**: Remove all hyphens, keep only letters and numbers, max 24 chars.

---

### Container Registries (No Hyphens)

Similar to storage accounts, Container Registries have a 50-char alphanumeric limit.

**Format**: `acr{workload}{environment}{region}{instance}`

```
acrhubprodeastus01          # Hub registry (platform images)
acrappsprodeastus01         # Workload registry
```

---

### Key Vaults (24-char limit with hyphens)

Key Vault names are 24 chars max with hyphens allowed.

**Format**: `kv-{workload}-{env}-{region}-##`

```
kv-sec-prod-eastus-01       # Security vault (24 chars)
kv-hub-prod-eastus-01       # Hub vault (24 chars)
kv-identity-prod-eastus-01  # Identity vault (OVER LIMIT - use: kv-id-prod-eastus-01)
```

**Rule**: Count carefully. Use region abbreviations (e.g., `eus` instead of `eastus` if needed).

---

### Abbreviate When Necessary

For resources with tight character limits, abbreviate components:

| Full Name | Abbreviation | Usage |
|-----------|--------------|-------|
| eastus | eus | Storage, ACR, KV |
| westus | wus | |
| northeu | neu | |
| sandbox | sbx | |
| nonprod | np | |
| security | sec | |
| identity | id | |

**Example**: `kv-id-prod-eus-01` (19 chars, fits in 24-char limit for KV)

---

## Enforcement

### 1. Terraform Modules (Automatic)

All Terraform modules should accept these input variables:

```hcl
variable "resource_type_abbreviation" {
  type        = string
  description = "Standard abbreviation for resource type"
  validation {
    condition     = contains(["vnet", "fw", "kv", "rg", "nsg"], var.resource_type_abbreviation)
    error_message = "Must be valid abbreviation from naming convention."
  }
}

variable "workload_name" {
  type        = string
  description = "Workload identifier (3-10 chars lowercase)"
  validation {
    condition     = length(var.workload_name) >= 3 && length(var.workload_name) <= 10
    error_message = "Workload must be 3-10 characters."
  }
}

variable "environment" {
  type        = string
  description = "Environment (prod, nonprod, dev, test, sandbox)"
  validation {
    condition     = contains(["prod", "nonprod", "dev", "test", "sandbox"], var.environment)
    error_message = "Environment must be one of: prod, nonprod, dev, test, sandbox."
  }
}

variable "region" {
  type        = string
  description = "Azure region abbreviation (eastus, westus, etc.)"
}

variable "instance" {
  type        = string
  default     = "01"
  description = "Instance number (01, 02, etc.)"
  validation {
    condition     = can(regex("^\\d{2}$", var.instance))
    error_message = "Instance must be two digits (e.g., 01, 02)."
  }
}

# Example usage in module:
locals {
  resource_name = "${var.resource_type_abbreviation}-${var.workload_name}-${var.environment}-${var.region}-${var.instance}"
}
```

### 2. Azure Policy (Validation)

Create policy to enforce naming conventions at deployment time:

```hcl
# Example policy definition (pseudo-code)
policy "enforce-naming-convention" {
  display_name        = "Enforce Azure Resource Naming Convention"
  policy_type         = "Custom"
  mode                = "All"
  
  rules = [
    {
      resource_type = "Microsoft.Compute/virtualMachines"
      pattern       = "^vm-[a-z]{3,10}-[a-z]+-[a-z0-9]+-\\d{2}$"
      error_message = "VM names must follow: vm-{workload}-{env}-{region}-{instance}"
    },
    {
      resource_type = "Microsoft.Network/virtualNetworks"
      pattern       = "^vnet-[a-z]{3,10}-[a-z]+-[a-z0-9]+-\\d{2}$"
      error_message = "VNET names must follow: vnet-{workload}-{env}-{region}-{instance}"
    }
  ]
}
```

### 3. Code Review Checklist

When reviewing code/PRs, verify:

- [ ] All resources follow the naming pattern
- [ ] Resource type abbreviations are from the standard table
- [ ] Workload names are 3-10 chars, meaningful
- [ ] Environment is one of: prod, nonprod, dev, test, sandbox
- [ ] Region abbreviation is valid
- [ ] Instance starts at 01 and increments
- [ ] Storage accounts and ACRs have no hyphens
- [ ] Key Vaults fit within 24-char limit
- [ ] All components lowercase (no mixed case)

---

## Exceptions & Deviations

### When to Request an Exception

Exceptions require **Platform Engineering approval** and must be documented:

1. **Existing Legacy Systems**: Resource names inherited from prior migration
   - Example: Existing SQL database named `acme_prod_db` (underscore vs. hyphen)
   - Approval: Document in exception log with business justification

2. **Vendor/Third-Party Constraints**: External system with rigid naming
   - Example: SaaS provider requires specific VM naming
   - Approval: Attach vendor documentation to exception

3. **Character Limit Conflicts**: Resource type max length too restrictive
   - Example: Key Vault name exceeds 24 chars even with abbreviations
   - Approval: Use approved abbreviations, request override if still too long

### Exception Log

**File**: `docs/NAMING-EXCEPTIONS.md`

**Format**:
```markdown
| Resource | Exception | Reason | Approved By | Approval Date | Sunset |
|----------|-----------|--------|-------------|---------------|--------|
| kv-super-long-name-prod-eastus-01 | Exceeds 24-char limit | Vendor requirement | Platform-Lead | 2026-06-30 | 2027-06-30 |
```

**Rule**: All exceptions have a sunset date. Re-review every 6 months.

---

## Testing the Convention

### Terraform Validation

```bash
# Validate all names follow convention
terraform validate

# Format check (lowercase)
terraform fmt -check -recursive terraform/
```

### Azure Policy Compliance

```bash
# Check policy compliance across subscriptions
az policy state summarize \
  --subscription sub-platform-hub-prod \
  --filter "ResourceName startswith 'vm-' or ResourceName startswith 'vnet-'"
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-30 | Platform Engineering | Initial convention based on CAF + AVM standards |
| | | | |

---

## Related Documents

- [TAGGING-STRATEGY.md](TAGGING-STRATEGY.md) - Tag naming and values
- [SUBSCRIPTIONS.md](SUBSCRIPTIONS.md) - Subscription naming and layout
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - How to use convention in Terraform
- [NAMING-EXCEPTIONS.md](NAMING-EXCEPTIONS.md) - Approved deviations

---

**Questions?** Contact Platform Engineering Team


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

