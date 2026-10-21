<!-- Source: docs/STD-TAGGING-STRATEGY.md -->
<!-- Last migrated: 2026-06-30 -->

# Azure Resource Tagging Strategy

**Document ID**: DOC-TAGGING-STRATEGY-001  
**Version**: 1.0  
**Status**: ✅ APPROVED  
**Last Updated**: 2026-06-30  
**Owner**: Platform Engineering  
**Review Date**: 2026-12-30

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Tag Governance Model](#tag-governance-model)
3. [Mandatory Tags](#mandatory-tags)
4. [Optional Tags](#optional-tags)
5. [Tag Naming Rules](#tag-naming-rules)
6. [Tag Values & Allowed Values](#tag-values--allowed-values)
7. [Implementation by Resource Type](#implementation-by-resource-type)
8. [Enforcement & Compliance](#enforcement--compliance)
9. [Cost Allocation via Tags](#cost-allocation-via-tags)
10. [Tag Inheritance & Defaults](#tag-inheritance--defaults)

---

## Overview

Tags are metadata key-value pairs that enable:
- **Cost Management**: Allocate costs to teams/projects
- **Operations**: Automation and resource discovery
- **Compliance**: Governance and audit trails
- **Billing**: Chargeback and showback reporting

This strategy aligns with:
- [Microsoft CAF Tagging Strategy](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)
- [Azure Cost Management tagging](https://learn.microsoft.com/azure/cost-management-billing/costs/enable-tag-inheritance)
- [Azure Verified Modules best practices](https://azure.github.io/Azure-Verified-Modules/)

---

## Tag Governance Model

### Mandatory (Core) Tags

**Required on ALL resources** → Enforced via Azure Policy

| Tag | Allowed Values | Purpose | Example |
|-----|----------------|---------|---------|
| `Environment` | prod, nonprod, dev, test, sandbox | Deployment stage | prod |
| `Application` | {app-name} or "platform" | Workload identifier | "platform", "payroll", "hr-system" |
| `Owner` | {team-name} or {email} | Responsible team/person | platform-team, saul@acme.com |
| `CostCenter` | {cost-code} | Finance chargeback code | CC-1001, ENG-2022 |
| `CreatedDate` | YYYY-MM-DD | Resource creation date | 2026-06-30 |
| `Terraform` | true, false | IaC management flag | true |

**Policy Effect**: DENY (prevents deployment if mandatory tags missing)

### Recommended (Optional) Tags

**Encouraged but not enforced** → Best practice

| Tag | Allowed Values | Purpose | Example |
|-----|----------------|---------|---------|
| `ManagedBy` | terraform, manual, script, arm | Deployment method | terraform |
| `DataClassification` | public, internal, confidential, restricted | Data sensitivity | confidential |
| `BackupRequired` | true, false | Backup inclusion | true |
| `BackupFrequency` | daily, weekly, monthly | Backup schedule | daily |
| `DeprovisionDate` | YYYY-MM-DD | Scheduled deletion date | 2027-06-30 |
| `CriticalityLevel` | critical, high, medium, low | Business criticality | critical |
| `DisasterRecovery` | required, optional, not-required | DR requirement | required |
| `Compliance` | soc2, hipaa, pci-dss, gdpr, iso27001 | Compliance frameworks | soc2 |
| `BusinessUnit` | {org-unit} | Organizational owner | Finance, HR, IT |
| `Project` | {project-name} | Associated project | ALZ-Migration, PayrollModernization |
| `ApprovedBy` | {approver-name} | Deployment approval | platform-lead |
| `ChangeTicket` | {ticket-id} | Change management reference | CHG-2026-001 |
| `Confidentiality` | public, internal, secret | Data confidentiality level | internal |
| `DeploymentSlot` | blue, green, canary | Deployment strategy | blue |
| `ScheduledShutdown` | true, false | Auto-shutdown enabled | false |
| `ShutdownTime` | HH:MM (24h format) | Shutdown schedule | 18:00 |
| `StartupTime` | HH:MM (24h format) | Startup schedule | 06:00 |
| `AutoShutdownTZ` | {timezone} | Timezone for automation | US/Eastern |
| `HotfixRequired` | true, false | Hotfix priority | false |
| `PatchGroup` | {group-name} | Patch management group | patch-group-prod-web |
| `MaintenanceWindow` | day/time | Maintenance schedule | Tuesday/02:00-04:00 |

---

## Mandatory Tags

### 1. Environment

**Purpose**: Identify deployment stage for policy segregation

**Tag Name**: `Environment`  
**Type**: String  
**Required**: ✅ YES  
**Enforced**: Azure Policy (DENY if missing)

**Allowed Values**:

| Value | Tier | Usage | Policy Strictness | Cost Center |
|-------|------|-------|------------------|------------|
| `prod` | Tier-1 | Production workloads | Strictest | Business unit |
| `nonprod` | Tier-2 | Staging/pre-prod | Strict | Engineering |
| `dev` | Tier-3 | Development | Moderate | Engineering |
| `test` | Tier-3 | Testing | Moderate | QA |
| `sandbox` | Tier-4 | Experimentation | Permissive | Engineering |

**Rule**: Use EXACT value from table. Do NOT invent (e.g., no `p`, `d`, `production`, `development`).

**Example Usage in Terraform**:

```hcl
locals {
  environment = "prod"
}

resource "azurerm_resource_group" "example" {
  name     = "rg-hub-platform-prod-eastus-01"
  location = "eastus"
  
  tags = {
    Environment = local.environment  # ✅ Must be: prod, nonprod, dev, test, sandbox
  }
}
```

---

### 2. Application

**Purpose**: Identify logical workload/service

**Tag Name**: `Application`  
**Type**: String  
**Required**: ✅ YES  
**Enforced**: Azure Policy (DENY if missing)

**Allowed Values**:

| Value | Type | Example |
|-------|------|---------|
| `platform` | Platform | Hub networking, management, identity |
| `{app-name}` | Workload | payroll, hr-system, crm, analytics |
| `sandbox` | Experimentation | Sandbox landing zones |

**Rule**: Use lowercase alphanumeric and hyphens. Max 30 chars. Meaningful (not generic "app" or "data").

**Examples**:

```hcl
tags = {
  Application = "platform"              # Platform resources
  Application = "payroll"               # Payroll workload
  Application = "hr-system"             # HR system
  Application = "inventory-mgmt"        # Inventory management
  Application = "analytics-pipeline"    # Analytics
}
```

**Cost Analysis**: This tag enables:
```
SELECT Application, SUM(Cost) FROM FinanceReport GROUP BY Application
# Output:
# platform      $5,000
# payroll       $12,000
# hr-system     $8,000
# Total         $25,000
```

---

### 3. Owner

**Purpose**: Identify responsible team or person for operations/cost

**Tag Name**: `Owner`  
**Type**: String  
**Required**: ✅ YES  
**Enforced**: Azure Policy (DENY if missing)

**Format Options**:

| Format | Type | Example | Best For |
|--------|------|---------|----------|
| `{team-name}` | Team | platform-team, security-team | Large teams |
| `{email}` | Individual | saul@acme.com, jane.doe@acme.com | Individual accountability |
| `{title}` | Role | platform-lead, security-architect | Role-based assignment |

**Rule**: Choose ONE format for consistency. Examples show team-based approach (recommended for platform).

**Examples**:

```hcl
# Team-based (recommended for platform/shared)
tags = {
  Owner = "platform-team"
}

# Individual (recommended for workload-specific)
tags = {
  Owner = "payroll-team"
  Owner = "john.smith@acme.com"
}
```

**Process**: 
1. Owner is notified quarterly for tag validation
2. Resources with unknown owner marked for review
3. Unused resources with past-due owners may be deprovisioned (after warning)

---

### 4. CostCenter

**Purpose**: Allocate costs for billing/chargeback

**Tag Name**: `CostCenter`  
**Type**: String  
**Required**: ✅ YES  
**Enforced**: Azure Policy (DENY if missing)

**Format**: `{org-code}-{number}` or `{department}-{fiscal-year}`

**Allowed Values** (Example):

| Code | Department | Budget Owner | Monthly Budget |
|------|------------|--------------|----------------|
| CC-1001 | Platform Engineering | CTO | $5,000 |
| CC-1002 | Security Operations | CISO | $3,000 |
| CC-2001 | Business Apps | COO | $10,000 |
| CC-3001 | Finance Systems | CFO | $4,000 |

**Rule**: Validate against approved cost center list. Provisioning denied for unknown codes.

**Examples**:

```hcl
# Platform costs
tags = {
  CostCenter = "CC-1001"  # Platform Engineering
}

# Workload costs
tags = {
  CostCenter = "CC-2001"  # Business Apps
}
```

**Finance Integration**:
```sql
-- Monthly chargeback report
SELECT 
  CostCenter,
  Department,
  SUM(Cost) as TotalCost
FROM AzureBilling
WHERE Month = '2026-06'
GROUP BY CostCenter, Department
ORDER BY TotalCost DESC;

-- Output:
-- CC-2001  Business Apps      $10,500
-- CC-1001  Platform Eng       $5,200
-- CC-3001  Finance Systems    $4,100
```

---

### 5. CreatedDate

**Purpose**: Track resource creation for lifecycle management

**Tag Name**: `CreatedDate`  
**Type**: String (ISO 8601)  
**Required**: ✅ YES  
**Enforced**: Azure Policy (DENY if missing)

**Format**: `YYYY-MM-DD` (ISO 8601 standard)

**Rule**: Always use creation date, not current date. Never update this tag.

**Examples**:

```hcl
# Set at creation time
tags = {
  CreatedDate = "2026-06-30"  # When resource was first deployed
}

# Terraform tip: Use timestamp at plan time
locals {
  created_date = formatdate("YYYY-MM-DD", timestamp())
}

# Or specify explicitly
tags = {
  CreatedDate = "2026-06-30"
}
```

**Use Cases**:
- Find "old" resources: Filter by CreatedDate < 2024-01-01
- Calculate age: TODAY() - CreatedDate
- Identify orphaned resources: CreatedDate > 2 years + Owner not found

---

### 6. Terraform

**Purpose**: Flag resources deployed via Terraform vs. manual/portal

**Tag Name**: `Terraform`  
**Type**: Boolean (true/false as string)  
**Required**: ✅ YES  
**Enforced**: Azure Policy (DENY if missing)

**Allowed Values**:

| Value | Meaning | Action |
|-------|---------|--------|
| `true` | Deployed by Terraform IaC | Managed via git + TFC |
| `false` | Deployed manually or via ARM | Manual updates required |

**Rule**: Set to `true` for all resources deployed via Terraform modules. Set to `false` only for manual or emergency deployments.

**Examples**:

```hcl
# All Terraform resources
tags = {
  Terraform = "true"  # Managed by terraform state
}

# Manual deployment (emergency only, should be rare)
tags = {
  Terraform = "false"  # Manual resource, needs conversion to IaC
}
```

**Process**: 
- Every 30 days: Audit resources with `Terraform = "false"`
- Create tickets to convert manual resources to IaC
- Goal: 100% of platform resources have `Terraform = "true"`

---

## Optional Tags

### Operational Tags

#### `ManagedBy`

**Purpose**: Document how resource was deployed

**Allowed Values**: terraform, manual, script, arm

```hcl
tags = {
  ManagedBy = "terraform"  # Deployed via Terraform + GitHub Actions
}
```

---

#### `BackupRequired`

**Purpose**: Trigger backup policies

**Allowed Values**: true, false

```hcl
tags = {
  BackupRequired = "true"  # Include in backup jobs
}
```

---

#### `DataClassification`

**Purpose**: Identify data sensitivity for encryption/access policies

**Allowed Values**: public, internal, confidential, restricted

```hcl
# Platform storage (internal logs)
tags = {
  DataClassification = "internal"
}

# Security logs (sensitive)
tags = {
  DataClassification = "confidential"
}

# Demo/sandbox data (public)
tags = {
  DataClassification = "public"
}
```

---

#### `CriticalityLevel`

**Purpose**: Drive SLO/SLA and escalation policies

**Allowed Values**: critical, high, medium, low

```hcl
# Hub networking (critical - supports all workloads)
tags = {
  CriticalityLevel = "critical"
}

# Sandbox (low - experimentation)
tags = {
  CriticalityLevel = "low"
}
```

---

#### `DisasterRecovery`

**Purpose**: Define DR backup/replication strategy

**Allowed Values**: required, optional, not-required

```hcl
# Hub (critical - must have DR)
tags = {
  DisasterRecovery = "required"
}

# Development (no DR needed)
tags = {
  DisasterRecovery = "not-required"
}
```

---

### Compliance Tags

#### `Compliance`

**Purpose**: Track regulatory compliance requirements

**Allowed Values**: soc2, hipaa, pci-dss, gdpr, iso27001

```hcl
# Finance workload (PCI-DSS)
tags = {
  Compliance = "pci-dss"
}

# Healthcare app (HIPAA)
tags = {
  Compliance = "hipaa"
}
```

---

### Automation Tags

#### `ScheduledShutdown`

**Purpose**: Enable auto shutdown (cost optimization)

**Allowed Values**: true, false

```hcl
# Development resources (shut down at 6 PM daily)
tags = {
  ScheduledShutdown = "true"
  ShutdownTime      = "18:00"
  StartupTime       = "06:00"
  AutoShutdownTZ    = "US/Eastern"
}

# Production resources (always on)
tags = {
  ScheduledShutdown = "false"
}
```

---

#### `DeprovisionDate`

**Purpose**: Schedule resource deletion after specific date

**Allowed Values**: YYYY-MM-DD

```hcl
# Temporary development environment (expires 2026-12-31)
tags = {
  DeprovisionDate = "2026-12-31"
}

# Scheduled job: Audit resources where TODAY() > DeprovisionDate
```

---

## Tag Naming Rules

### Key Naming (Tag Names)

1. **Case Sensitivity**: Azure tags ARE case-sensitive
   - ✅ `Environment`, `Application`, `Owner` (PascalCase - STANDARD)
   - ❌ `environment`, `ENVIRONMENT` (avoid - inconsistent)

2. **Length**: Max 512 characters for key
   - ✅ `Owner`, `CreatedDate`, `DataClassification`
   - ❌ `ThisIsAVeryLongTagNameThatExceedsRecommendedLengthAndIsHardToRememberOrType`

3. **Allowed Characters**: Alphanumeric, hyphen, underscore
   - ✅ `Cost-Center`, `Backup_Required`
   - ❌ `Cost Center` (space), `Cost@Center` (special char)

4. **Standard Format**: Use PascalCase (CamelCase with capital first letter)
   ```
   ✅ Correct
   Environment
   Application
   Owner
   CostCenter
   CreatedDate
   DataClassification
   BackupRequired
   
   ❌ Incorrect
   environment (lowercase)
   ENVIRONMENT (ALL CAPS)
   cost-center (lowercase-hyphen)
   cost_center (lowercase-underscore)
   ```

---

### Value Naming (Tag Values)

1. **Case Sensitivity**: Azure tag VALUES are case-insensitive (but be consistent)
   - ✅ `prod`, `Prod`, `PROD` (all work, but choose ONE)
   - RECOMMENDATION: Use lowercase for values

2. **Length**: Max 256 characters for value
   - ✅ `platform`, `payroll-team`, `saul@acme.com`
   - ❌ Very long descriptions

3. **Allowed Characters**: Alphanumeric, hyphen, underscore, dot, colon, at-sign (@)
   - ✅ `saul@acme.com` (emails)
   - ✅ `platform-team` (team names)
   - ✅ `2026-06-30` (dates)
   - ❌ `saul [at] acme.com` (use @ not [at])

4. **Format Standards**:
   - **Dates**: ISO 8601 (`2026-06-30`, not `6/30/2026` or `06-30-2026`)
   - **Teams**: lowercase-hyphen (`platform-team`, not `Platform Team` or `platform_team`)
   - **Emails**: lowercase (`saul@acme.com`, not `Saul@Acme.Com`)
   - **Codes**: UPPERCASE or alphanumeric (`CC-1001`, not `cc-1001`)

---

## Tag Values & Allowed Values

### Master Tag Values Reference

**File**: `docs/TAG-VALUES-REFERENCE.md` (auto-generated)

```yaml
Environment:
  - prod
  - nonprod
  - dev
  - test
  - sandbox

Application:
  - platform
  - payroll
  - hr-system
  - crm
  - analytics
  - # Add more as workloads deployed

Owner:
  - platform-team
  - payroll-team
  - security-team
  - # Or use emails: saul@acme.com

CostCenter:
  - CC-1001  # Platform Engineering
  - CC-1002  # Security Operations
  - CC-2001  # Business Apps
  - CC-3001  # Finance Systems

Terraform:
  - "true"
  - "false"

BackupRequired:
  - "true"
  - "false"

DataClassification:
  - public
  - internal
  - confidential
  - restricted

CriticalityLevel:
  - critical
  - high
  - medium
  - low

DisasterRecovery:
  - required
  - optional
  - not-required

Compliance:
  - soc2
  - hipaa
  - pci-dss
  - gdpr
  - iso27001
```

---

## Implementation by Resource Type

### Platform Resources (Hub, Management, Identity, Security)

```hcl
# Example: Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-platform-prod-eastus-01"
  resource_group_name = azurerm_resource_group.platform.name
  location            = "eastus"
  address_space       = ["10.0.0.0/16"]
  
  tags = {
    # Mandatory
    Environment  = "prod"
    Application  = "platform"
    Owner        = "platform-team"
    CostCenter   = "CC-1001"
    CreatedDate  = "2026-06-30"
    Terraform    = "true"
    
    # Recommended
    ManagedBy            = "terraform"
    DataClassification   = "internal"
    CriticalityLevel     = "critical"
    DisasterRecovery     = "required"
    BackupRequired       = "true"
  }
}
```

### Workload Resources (Sandbox, Prod App)

```hcl
# Example: Workload application resource
resource "azurerm_app_service_plan" "app" {
  name                = "aspnet-payroll-prod-eastus-01"
  resource_group_name = azurerm_resource_group.workload.name
  location            = "eastus"
  kind                = "Linux"
  reserved            = true
  
  sku {
    tier = "Standard"
    size = "S1"
  }
  
  tags = {
    # Mandatory
    Environment  = "prod"
    Application  = "payroll"
    Owner        = "payroll-team"
    CostCenter   = "CC-2001"
    CreatedDate  = "2026-06-30"
    Terraform    = "true"
    
    # Recommended
    ManagedBy            = "terraform"
    DataClassification   = "confidential"  # Payroll is sensitive
    CriticalityLevel     = "high"
    DisasterRecovery     = "required"
    BackupRequired       = "true"
    Compliance           = "soc2"
  }
}
```

### Temporary/Development Resources (Sandbox)

```hcl
# Example: Dev/sandbox resource (can be shut down)
resource "azurerm_app_service_plan" "sandbox" {
  name                = "aspnet-sandbox-nonprod-eastus-01"
  resource_group_name = azurerm_resource_group.sandbox.name
  location            = "eastus"
  
  tags = {
    # Mandatory
    Environment  = "sandbox"
    Application  = "sandbox"
    Owner        = "engineering-team"
    CostCenter   = "CC-1001"
    CreatedDate  = "2026-06-30"
    Terraform    = "true"
    
    # Recommended (sandbox-specific)
    ScheduledShutdown    = "true"
    ShutdownTime         = "18:00"
    StartupTime          = "06:00"
    AutoShutdownTZ       = "US/Eastern"
    DeprovisionDate      = "2026-09-30"  # 3 months for testing
    CriticalityLevel     = "low"
    DisasterRecovery     = "not-required"
  }
}
```

---

## Enforcement & Compliance

### Azure Policy: Mandatory Tag Enforcement

**Policy File**: `terraform/modules/policy-baseline/policies/require-mandatory-tags.json`

```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "field": "type",
      "notEquals": "Microsoft.Resources/subscriptions/resourceGroups"
    },
    "then": {
      "effect": "deny",
      "details": {
        "roleDefinitionIds": [
          "/subscriptions/{subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        ],
        "requiredTags": [
          "Environment",
          "Application",
          "Owner",
          "CostCenter",
          "CreatedDate",
          "Terraform"
        ]
      }
    }
  }
}
```

**Behavior**:
- ✅ Deployment succeeds if all 6 mandatory tags present
- ❌ Deployment denied if any mandatory tag missing
- No exceptions (all resources required)

### Audit Non-Compliance

```powershell
# Find resources without required tags
az policy state list \
  --query "[?complianceState=='NonCompliant'].{ResourceId:resourceId,Policy:policyDefinitionName}" \
  --filter "policyDefinitionName eq 'require-mandatory-tags'" \
  --output table
```

### Compliance Report (Monthly)

```sql
-- Query: Resources missing mandatory tags
SELECT 
  ResourceName,
  ResourceGroup,
  Environment,
  Application,
  Owner,
  CostCenter,
  CASE WHEN Environment IS NULL THEN 'Missing' ELSE 'OK' END as EnvironmentStatus,
  CASE WHEN Application IS NULL THEN 'Missing' ELSE 'OK' END as ApplicationStatus
FROM AzureResources
WHERE 
  Environment IS NULL 
  OR Application IS NULL 
  OR Owner IS NULL 
  OR CostCenter IS NULL
ORDER BY ResourceGroup, ResourceName;
```

---

## Cost Allocation via Tags

### Cost Management Setup

**Goal**: Break down $25,000/month Azure bill by department

1. **Enable Tag Inheritance** (Cost Management):
   ```
   Resource Group tags → propagate to all child resources
   ```

2. **Grouping Configuration**:
   ```
   GROUP BY: Application, CostCenter, Environment
   ```

3. **Sample Cost Report**:

   | Application | CostCenter | Environment | Monthly Cost | YTD Cost |
   |-------------|-----------|-------------|-------------|----------|
   | platform | CC-1001 | prod | $5,200 | $31,200 |
   | payroll | CC-2001 | prod | $8,500 | $51,000 |
   | hr-system | CC-2001 | prod | $3,200 | $19,200 |
   | analytics | CC-1002 | nonprod | $2,100 | $12,600 |
   | **Total** | | | **$19,000** | **$114,000** |

### Chargeback Process

1. **Report Generation** (Month end):
   ```
   SELECT Application, Owner, SUM(Cost) 
   FROM CostManagement 
   WHERE Month = '2026-06'
   GROUP BY Application, Owner
   ```

2. **Validation**:
   - Owner approves costs for their resources
   - Dispute unrecognized resources

3. **Billing**:
   - Finance applies costs to cost center budget
   - Department manager receives bill

---

## Tag Inheritance & Defaults

### Resource Group-Level Tags

All tags on resource group are inherited by child resources:

```hcl
resource "azurerm_resource_group" "platform" {
  name     = "rg-hub-platform-prod-eastus-01"
  location = "eastus"
  
  tags = {
    Environment  = "prod"
    Application  = "platform"
    Owner        = "platform-team"
    CostCenter   = "CC-1001"
    CreatedDate  = "2026-06-30"
    Terraform    = "true"
  }
}

# Individual resources inherit RG tags
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-platform-prod-eastus-01"
  resource_group_name = azurerm_resource_group.platform.name
  location            = "eastus"
  
  tags = merge(
    azurerm_resource_group.platform.tags,
    {
      # Add resource-specific tags
      DataClassification = "internal"
    }
  )
}
```

### Terraform Locals for DRY Tags

```hcl
locals {
  # Base tags for all platform resources
  platform_tags = {
    Environment  = "prod"
    Application  = "platform"
    Owner        = "platform-team"
    CostCenter   = "CC-1001"
    CreatedDate  = "2026-06-30"
    Terraform    = "true"
  }
  
  # Platform-specific additions
  platform_security_tags = merge(
    local.platform_tags,
    {
      DataClassification = "confidential"
      CriticalityLevel    = "critical"
    }
  )
}

# Use in resources
resource "azurerm_key_vault" "platform_secrets" {
  name     = "kv-sec-prod-eastus-01"
  # ... other config ...
  
  tags = local.platform_security_tags
}
```

---

## Tag Audit Schedule

| Frequency | Task | Owner | Action |
|-----------|------|-------|--------|
| Monthly | Compliance report | Ops | Review non-compliant resources |
| Monthly | Cost allocation | Finance | Chargeback billing |
| Quarterly | Owner validation | Asset Mgmt | Confirm resource owners still valid |
| Quarterly | Tag standards review | Platform | Update allowed values as needed |
| Annually | Cost optimization | Finance | Identify unused resources by tags |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-30 | Platform Engineering | Initial tagging strategy |

---

## Related Documents

- [NAMING-CONVENTION.md](NAMING-CONVENTION.md) - Resource naming patterns
- [SUBSCRIPTIONS.md](SUBSCRIPTIONS.md) - Subscription structure
- [TAG-VALUES-REFERENCE.md](TAG-VALUES-REFERENCE.md) - Auto-generated allowed values
- [COST-ALLOCATION-GUIDE.md](COST-ALLOCATION-GUIDE.md) - Financial chargeback setup

---

**Questions?** Contact Platform Engineering Team


---

**Navigation:** [[Home]] | [[Phase-Roadmap]] | [[Getting-Started]]
**Last Updated:** 2026-06-30

