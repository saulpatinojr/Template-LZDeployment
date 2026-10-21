# RBAC Requirements & Service Principal Configuration

**Last Updated**: 2026-06-30  
**Status**: Reference Documentation

---

## Overview

This document defines Role-Based Access Control requirements for the Landing Zone deployment. All service principals follow the principle of least privilege: **Contributor role only**.

## Service Principal Architecture

Layer-based service principals with blast-contained permissions:
- sp-terraform-main-prod: Main branch deployments
- sp-terraform-dev-prod: Development environment  
- sp-terraform-prod-prod: Production environment

Each SP has Contributor role scoped to its target subscription, with no Owner role assignments.

## Role Definitions

### Contributor Role
- Create, read, update, delete resources
- Manage resource group contents
- Cannot: Create subscriptions, change policies, delete resource groups
- Security: Acceptable for infrastructure deployment

### User Access Administrator Role
- Assign any role to any principal
- Modify RBAC at assigned scope
- Used by: Dev and Prod layers only
- Justification: Dev needs RBAC testing; Prod needs identity management

## Scope Levels

### Subscription Scope (Recommended)
\\\
/subscriptions/<subscription-id>
\\\
- Applies to all resources within subscription
- Necessary for Terraform deployments

### Resource Group Scope (Future)
- More restrictive than subscription scope
- Future migration path after infrastructure stabilizes

### Tenant/Global Scope (FORBIDDEN)
- No service principal should have this
- Would allow global permission changes

## RBAC Validation (Workflow 020)

Automated checks run:
- On every push to main
- On every PR to main
- Weekly (Monday 9 AM UTC)
- On-demand via workflow dispatch

Validates:
- No Owner roles
- Contributor role exists
- Subscription-only scope
- Proper OIDC subject scoping
- No tenant-level assignments

## RBAC Enforcement Policies

**Policy 1**: No Owner Roles
- Action: CRITICAL ALERT + BLOCK
- Justification: Owner bypasses all permission controls

**Policy 2**: Subscription Scope Only
- Action: CRITICAL ALERT
- Justification: Multi-subscription SPs create cross-boundary risks

**Policy 3**: OIDC Subject Scoping
- Action: CRITICAL ALERT
- Justification: Overly broad OIDC allows unauthorized workflows

**Policy 4**: Least-Privilege Role Assignment
- Action: WARNING + RECOMMENDATION
- Justification: Extra roles increase attack surface

## Best Practices

### DO's
- Run Workflow 020 on every push to main
- Review audit reports monthly
- Document any manual RBAC changes
- Keep federated credentials scoped to specific branches
- Use separate SPs for different environments
- Assign Contributor-only by default
- Audit role assignments quarterly

### DON'Ts
- Don't assign Owner role to service principals
- Don't use single SP for multiple subscriptions
- Don't create overly broad OIDC subjects
- Don't store RBAC configurations in code
- Don't skip Workflow 020 validation
- Don't manually modify roles without updating docs

---

**Approver**: Platform Engineering Team
