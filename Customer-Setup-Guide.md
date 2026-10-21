# Customer Setup Guide & Getting Started

Last Updated: June 30, 2026  
Time Estimate: 30 minutes for setup  
Difficulty: Intermediate

## Overview

This guide walks you through deploying an Azure Landing Zone using this infrastructure-as-code system.

## Prerequisites

You need:
- Azure subscription (or multiple for multi-environment)
- GitHub organization account
- Terraform Cloud account (free tier OK)
- Azure CLI or PowerShell installed

## Step 1: Understand Architecture

### What You're Deploying

A production-ready Azure Landing Zone with:
- Hub-spoke networking (dual-region capable)
- Azure Firewall (or Palo Alto / Fortinet)
- Azure Policy governance baseline
- Backup and disaster recovery
- Security scanning and compliance
- GitHub Actions automation

### Critical Policy

NO DEPLOYMENTS until ALL code and validation complete.

System uses:
1. Code-complete-first approach
2. Automated testing (8 separate test types)
3. Security team sign-off
4. Full audit trail (git + Terraform Cloud)

## Step 2: Clone Repository

```bash
git clone https://github.com/YOUR-ORG/hcw-landing-zone.git
cd hcw-landing-zone
```

## Step 3: Prepare Environment

### 3.1: Gather Information

Collect before starting:

1. Azure Tenant ID:
   az account show --query tenantId -o tsv

2. Subscription IDs (need 6):
   az account list --query "[].{id:id, name:name}" -o table

3. Organization Prefix (2-4 lowercase letters)
   Examples: contoso, acme, fab

### 3.2: Install Tools

```bash
pwsh --version          # PowerShell 7+
az version              # Azure CLI
terraform version       # Terraform
git version             # Git
```

## Step 4: Run Bootstrap Script

```bash
./scripts/000_LZ_Bootloader.ps1
```

This script:
- Validates CLI tools installed
- Creates Entra app registrations
- Sets up OIDC federation to Azure
- Configures GitHub secrets
- Initializes Terraform Cloud

Duration: 5-10 minutes

## Step 5: Set Up Terraform Cloud

### 5.1: Create TFC Organization

1. Go to https://app.terraform.io
2. Sign up or login
3. Create new organization
4. Record organization name

### 5.2: Create API Token

1. Account Settings → Tokens
2. Create an API token
3. Name it "GitHub Actions"
4. Copy token value
5. Add to GitHub secrets:
   gh secret set TF_CLOUD_TOKEN --body "[token]"
   gh variable set TF_CLOUD_ORGANIZATION --body "[org]"

### 5.3: Create Workspaces

Create 6 TFC workspaces:
- lz-global
- lz-connectivity
- lz-management
- lz-sandbox
- lz-workloads-prod
- lz-workloads-nonprod

## Step 6: Generate Configuration

```bash
./scripts/040-CONFIGURE-LANDING-ZONE.ps1
```

Wizard generates:
- terraform.tfvars (all 5 layers)
- presentation.html (static page)
- cost estimates
- audit trail

Answer 3-phase questionnaire (10 minutes)

## Step 7: Review Configuration

### 7.1: View Presentation

File: presentation.html
- Executive summary
- Cost breakdown
- Architecture diagram
- Configuration details

### 7.2: Get Cost Estimate

File: cost-estimate.txt
- Monthly cost breakdown
- By service and region
- Optional features pricing

## Step 8: Deploy via Terraform

### 8.1: Initialize Terraform

```bash
cd terraform/live/global
terraform init -backend-config=backend.hcl
```

### 8.2: Review Plan

```bash
terraform plan
```

### 8.3: Deploy

```bash
terraform apply
```

Duration: 15-20 minutes

### 8.4: Monitor Deployment

In Terraform Cloud UI:
- Watch run progress
- Review resource creation
- Check for errors

## Step 9: Validate Deployment

### 9.1: Check Azure Portal

Verify resources:
- Management groups created
- Hub VNet in primary region
- Spoke VNet(s) created
- Policies applied
- Firewall deployed (if selected)

### 9.2: Run Compliance Checks

Via GitHub Actions:
./scripts/020-rbac-validation.yml

### 9.3: Verify Terraform State

```bash
terraform state list
terraform state show [resource_name]
```

## Step 10: Day 2 Operations

### 10.1: Daily Health Check

15-20 minute daily check:
1. Service Health (Azure Portal)
2. Backup jobs running
3. Firewall health
4. Policy compliance
5. Sandbox cleanup
6. Security alerts
7. State backend

See: docs/day2/01-daily-operations.md

### 10.2: Handle Changes

All changes via git + Terraform:

1. Make change in Terraform code
2. Commit to feature branch
3. Open PR (triggers workflow 100)
4. Review changes in PR
5. Merge PR (triggers workflow 200)
6. Monitor deployment in TFC

See: docs/day2/05-change-management.md

## Troubleshooting

### OIDC token exchange failed
- Verify federated credential matches repo path
- Check AZURE_CLIENT_ID, AZURE_TENANT_ID in secrets
- Run bootstrap script again

### Terraform Cloud workspace not found
- Verify TF_CLOUD_TOKEN is set
- Verify TF_CLOUD_ORGANIZATION matches
- Check workspace exists in TFC UI

### Module not found
- Ensure modules/ directory exists
- Check relative paths in main.tf
- Verify module files not deleted

### Deployment timed out
- Landing zone creation takes 15-20 minutes
- Check Terraform Cloud run logs
- Check Azure resource creation logs

## What's Included

### Always Deployed
- Management groups (3-level hierarchy)
- Azure Policy baseline
- Hub VNet (firewall, gateways)
- Spoke VNets (workloads, peering)
- DR skeleton (secondary region)

### Optional (If Selected)
- Backup & recovery resources
- Defender for Cloud
- Advanced firewall features
- Private Link/DNS zones

## Next Steps

### Week 1
1. Deploy landing zone
2. Validate resources created
3. Monitor for errors

### Week 2-4
1. Onboard first workload team
2. Deploy workload spoke VNet
3. Configure application resources
4. Train junior administrators

### Month 1+
1. Establish on-call rotation
2. Verify sandbox cleanup (30-day automated)
3. Test disaster recovery
4. Optimize costs

## Support

For Setup Help:
- README.md - Quick start
- CUSTOMER-SETUP.md - This guide
- DEPLOYMENT-GUIDE.md - Detailed steps

For Operations:
- docs/day2/ - Operational runbooks
- docs/ARCHITECTURE-SUMMARY.md - Architecture reference
- docs/ - All documentation

For Issues:
1. Check troubleshooting above
2. Check relevant documentation
3. Open GitHub issue
4. Contact platform team

---

Status: Production-ready for customer deployment
