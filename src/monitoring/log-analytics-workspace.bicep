// ============================================================================
// LOG ANALYTICS WORKSPACE MODULE
// ============================================================================
// Provides centralized log aggregation and analytics using Kusto Query Language (KQL).
// 
// Configuration:
// - SKU: PerGB2018 (pay-as-you-go pricing based on data ingested)
// - Retention: 30 days (configurable, balances cost and compliance)
// - Immediate Purge: Enabled (data deleted immediately after 30 days)
// - Identity: System-assigned managed identity for secure data access
//
// This workspace serves as the central repository for:
// - Logic Apps WorkflowRuntime logs
// - Application Insights telemetry
// - Service Bus diagnostic logs
// - App Service Plan metrics
//
// Reference: https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for the Log Analytics workspace. Will be suffixed with unique string and "-law" to ensure global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
param envName string

@description('Azure region for the Log Analytics workspace deployment. Should match application resources for optimal data transfer costs.')
param location string = resourceGroup().location

@description('Resource tags applied to the Log Analytics workspace for cost tracking, organization, and compliance.')
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-law'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      immediatePurgeDataOn30Days: true
    }
  }
}

@description('Resource ID of the deployed Log Analytics workspace for diagnostic settings configuration')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.id

@description('Name of the deployed Log Analytics workspace for reference and queries')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.name
