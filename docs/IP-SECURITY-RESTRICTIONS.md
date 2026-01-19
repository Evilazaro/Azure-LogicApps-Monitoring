---
title: IP Security Restrictions Configuration
description: Comprehensive guide for IP restrictions across all Azure resources in the solution
author: Evilazaro
date: 2026-01-19
version: 1.0
tags: [security, ip-restrictions, network, azure, firewall]
---

# 🔒 IP Security Restrictions Configuration

> [!NOTE]
> 🎯 **For Security Engineers and Platform Teams**: Detailed configuration guide for IP restrictions across Azure infrastructure.  
> ⏱️ **Estimated reading time:** 15 minutes

<details>
<summary>📍 <strong>Quick Navigation</strong></summary>

| Previous | Index | Next |
|:---------|:------:|--------:|
| — | [📚 Docs Index](README.md) | [Quick Reference →](IP-SECURITY-RESTRICTIONS-SUMMARY.md) |

</details>

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [⚙️ Container Apps (orders-api)](#%EF%B8%8F-container-apps-orders-api)
- [🔄 Logic Apps Standard (Workflow Engine)](#-logic-apps-standard-workflow-engine)
- [📦 Azure Container Registry](#-azure-container-registry)
- [🗄️ Azure SQL Database](#%EF%B8%8F-azure-sql-database)
- [💾 Storage Accounts (Workflow Storage)](#-storage-accounts-workflow-storage)
- [🔒 Security Best Practices](#-security-best-practices)
- [🌍 Environment-Specific Configuration](#-environment-specific-configuration)
- [🔧 Troubleshooting](#-troubleshooting)
- [📚 References](#-references)

---

This document describes the IP security restrictions implemented across the Azure infrastructure to enhance security posture.

## 📋 Overview

IP security restrictions have been implemented at multiple layers:

- Container Apps (API endpoints)
- Logic Apps / App Services (workflow engine)
- Azure Container Registry
- Azure SQL Database
- Storage Accounts

## ⚙️ Container Apps (orders-api)

**File**: `app.AppHost\infra\orders-api.tmpl.yaml`

### Restrictions Applied

- **Virtual Network Traffic**: Allows traffic from VNet (10.0.0.0/16)
- **Azure Services**: Allows traffic from Azure Cloud services using service tags

```yaml
ipSecurityRestrictions:
  - name: AllowVirtualNetwork
    action: Allow
    ipAddressRange: 10.0.0.0/16
    description: Allow traffic from Virtual Network
  - name: AllowAzureServices
    action: Allow
    tag: AzureCloud
    description: Allow traffic from Azure services
```

### Customization

To add additional IP ranges, modify the `ipSecurityRestrictions` array in the template file.

## 🔄 Logic Apps Standard (Workflow Engine)

**File**: `infra-old\workload\logic-app.bicep`

### Logic Apps Restrictions Applied

#### Main Site Access

- **Virtual Network**: 10.0.0.0/16 (Priority 100)
- **Azure Services**: Service tag-based access (Priority 200)
- **Default Action**: Deny all other traffic

#### SCM (Source Control Management) Access

- **Virtual Network**: 10.0.0.0/16 (Priority 100)
- **Default Action**: Deny all other traffic
- **Independent from Main**: SCM restrictions do not inherit from main site

```bicep
ipSecurityRestrictions: [
  {
    ipAddress: '10.0.0.0/16'
    action: 'Allow'
    priority: 100
    name: 'AllowVirtualNetwork'
  }
  {
    action: 'Allow'
    tag: 'ServiceTag'
    priority: 200
    name: 'AllowAzureServices'
  }
]
ipSecurityRestrictionsDefaultAction: 'Deny'
```

### Logic Apps Customization

Add additional IP rules by inserting new objects in the `ipSecurityRestrictions` array with appropriate priority values (lower numbers = higher priority).

## 📦 Azure Container Registry

**File**: `infra\resources.bicep`

### Container Registry Restrictions

- **Default Action**: Deny
- **Azure Services Bypass**: Enabled (allows Azure services to access)
- **IP Rules**: Empty by default (all public access denied)
- **Virtual Network Rules**: Empty by default

```bicep
networkRuleSet: {
  defaultAction: 'Deny'
  ipRules: []
  virtualNetworkRules: []
}
networkRuleBypassOptions: 'AzureServices'
```

### Container Registry Customization

To allow specific IP addresses:

```bicep
ipRules: [
  {
    value: '203.0.113.0/24'
    action: 'Allow'
  }
]
```

To allow VNet access:

```bicep
virtualNetworkRules: [
  {
    virtualNetworkResourceId: '<subnet-resource-id>'
    action: 'Allow'
  }
]
```

## 🗄️ Azure SQL Database

**File**: `infra\OrdersDatabase\OrdersDatabase.module.bicep`

### SQL Database Restrictions

- **Azure Services**: Allowed (0.0.0.0 - 0.0.0.0 rule)
- **Additional Rules**: Template provided for VNet ranges

```bicep
resource sqlFirewallRule_AllowAllAzureIps 'Microsoft.Sql/servers/firewallRules@2023-08-01' = {
  name: 'AllowAllAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  parent: OrdersDatabase
}
```

### SQL Database Customization

Uncomment and modify the template to add VNet or specific IP ranges:

```bicep
resource sqlFirewallRule_AllowVNet 'Microsoft.Sql/servers/firewallRules@2023-08-01' = {
  name: 'AllowVirtualNetwork'
  properties: {
    startIpAddress: '10.0.0.0'
    endIpAddress: '10.0.255.255'
  }
  parent: OrdersDatabase
}
```

For client-specific access:

```bicep
resource sqlFirewallRule_ClientIP 'Microsoft.Sql/servers/firewallRules@2023-08-01' = {
  name: 'AllowClientOffice'
  properties: {
    startIpAddress: '203.0.113.10'
    endIpAddress: '203.0.113.10'
  }
  parent: OrdersDatabase
}
```

## 💾 Storage Accounts (Workflow Storage)

**File**: `infra-old\shared\data\main.bicep`

### Storage Account Restrictions

- **Default Action**: Deny
- **Bypass**: Azure Services, Logging, Metrics
- **IP Rules**: Empty (configure per environment)
- **Virtual Network Rules**: Empty (configure per environment)

```bicep
networkAcls: {
  bypass: 'AzureServices, Logging, Metrics'
  defaultAction: 'Deny'
  ipRules: []
  virtualNetworkRules: []
}
```

### Storage Account Customization

Add IP addresses:

```bicep
ipRules: [
  {
    value: '203.0.113.0/24'
    action: 'Allow'
  }
]
```

Add VNet subnets:

```bicep
virtualNetworkRules: [
  {
    id: '/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/{subnet}'
    action: 'Allow'
  }
]
```

## 🔒 Security Best Practices

1. **Principle of Least Privilege**: Start with deny-all and explicitly allow only required sources
2. **Use VNet Integration**: Prefer VNet service endpoints over public IP allowlists
3. **Service Tags**: Use Azure service tags for Azure-to-Azure communication
4. **Regular Audits**: Review and update IP allowlists quarterly
5. **Environment-Specific Rules**: Use different rules for dev/staging/production
6. **Monitoring**: Enable diagnostic logging for failed access attempts

## 🌍 Environment-Specific Configuration

### Development

- May require broader IP ranges for developer access
- Consider allowing VPN endpoint IPs

### Staging

- Mirror production restrictions
- Add CI/CD pipeline IPs if needed

### Production

- Strictest restrictions
- Only allow production VNets and essential services
- Document all exceptions with business justification

## 🔧 Troubleshooting

### Common Issues

1. **Cannot access from Azure Portal**
   - Check if client IP is allowed in SQL/Storage firewall
   - Verify "Allow Azure services" is enabled

2. **Logic App cannot reach Storage**
   - Ensure managed identity has proper RBAC roles
   - Verify storage network ACLs allow Azure services

3. **Container App communication blocked**
   - Check VNet integration is properly configured
   - Verify service-to-service rules allow internal traffic

## 📚 References

- [Azure App Service IP Restrictions](https://learn.microsoft.com/azure/app-service/app-service-ip-restrictions)
- [Container Apps Ingress Configuration](https://learn.microsoft.com/azure/container-apps/ingress)
- [SQL Database Firewall Rules](https://learn.microsoft.com/azure/azure-sql/database/firewall-configure)
- [Storage Account Network Security](https://learn.microsoft.com/azure/storage/common/storage-network-security)
- [Container Registry Network Rules](https://learn.microsoft.com/azure/container-registry/container-registry-access-selected-networks)
