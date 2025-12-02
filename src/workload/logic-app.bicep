// ============================================================================
// LOGIC APP WORKLOAD MODULE
// ============================================================================
// Deploys Logic Apps Standard workload with comprehensive monitoring:
// - App Service Plan (Workflow Standard SKU - WS1)
// - Logic App (Function App + Workflow App)
// - RBAC role assignments for managed identity access
// - Diagnostic settings for logs and metrics
// - Azure Portal dashboards for operational monitoring
//
// App Service Plan Configuration:
// - SKU: WS1 (Workflow Standard tier)
// - Elastic scaling: up to 20 workers
// - Zone redundancy: configurable
//
// Logic App Configuration:
// - Runtime: .NET (FUNCTIONS_WORKER_RUNTIME=dotnet)
// - Identity: System-assigned managed identity
// - Storage: Connection string-based (transition to managed identity recommended)
// - Monitoring: Application Insights integration with connection string
//
// RBAC Roles Assigned to Logic App Managed Identity:
// 1. Storage Account (4 roles):
//    - Storage Blob Data Owner (b7e6dc6d-f1e8-4753-8033-0f276bb0955b)
//      Full access to blob containers and data
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-owner
//
//    - Storage Queue Data Contributor (974c5e8b-45b9-4653-ba55-5f855dd0fb88)
//      Read, write, delete queue messages
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-queue-data-contributor
//
//    - Storage Table Data Contributor (0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3)
//      Read, write, delete table entities
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-table-data-contributor
//
//    - Storage File Data Privileged Contributor (69566ab7-960f-475b-8e7c-b3118f30c6bd)
//      Read, write, delete, modify ACLs on files/directories
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor
//
// 2. Application Insights (1 role):
//    - Monitoring Metrics Publisher (3913510d-42f4-4e42-8a64-420c390055eb)
//      Publish metrics to Azure Monitor
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#monitoring-metrics-publisher
//
// 3. Service Bus (1 role):
//    - Azure Service Bus Data Owner (090c5cfd-751d-490a-894a-3ce6f1109419)
//      Full control over Service Bus resources (send, receive, manage)
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#azure-service-bus-data-owner
//
// Monitoring Dashboards:
// - Service Plan Metrics: CPU, Memory, Data I/O, HTTP Queue Length
// - Workflow Metrics: Runs, Failures, Triggers, Actions, Duration
// - Time Range: Past 24 hours with auto-refresh
//
// References:
// - Logic Apps Standard: https://learn.microsoft.com/azure/logic-apps/single-tenant-overview-compare
// - App Service Plan: https://learn.microsoft.com/azure/app-service/overview-hosting-plans
// - Managed Identity: https://learn.microsoft.com/azure/logic-apps/authenticate-with-managed-identity
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for Logic App and App Service Plan resources. Will be suffixed with unique string for global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for Logic App deployment. Must support Workflow Standard SKU and Application Insights.')
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
param workspaceId string

@description('Name of the existing storage account required by Logic Apps Standard for workflow state and artifacts.')
param storageAccountName string

@description('Name of the Application Insights instance for telemetry collection and performance monitoring.')
param appInsightsName string

@description('Name of existing Service Bus namespace for messaging integration with workflows.')
param serviceBusName string

@description('Resource tags applied to Logic App, App Service Plan, and dashboard resources for cost tracking and governance.')
param tags object

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name)}-asp'
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 1
  }
  kind: 'elastic'
  tags: tags
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
    asyncScalingEnabled: false
  }
}

resource DiagnosticSettingsAsp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appServicePlan.name}-diag'
  scope: appServicePlan
  properties: {
    workspaceId: workspaceId
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}

resource dashboardASP 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: '${appServicePlan.name}-dashboard'
  location: 'eastus2'
  tags: {
    'hidden-title': 'Service Plan Metrics'
  }
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appServicePlan.id
                          }
                          name: 'CpuPercentage'
                          aggregationType: 4
                          namespace: 'microsoft.web/serverfarms'
                          metricVisualization: {
                            displayName: 'CPU Percentage'
                          }
                        }
                      ]
                      title: 'Avg CPU Percentage for tax-docs-xz5pxrxowhg6e-asp'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 6
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appServicePlan.id
                          }
                          name: 'MemoryPercentage'
                          aggregationType: 4
                          namespace: 'microsoft.web/serverfarms'
                          metricVisualization: {
                            displayName: 'Memory Percentage'
                          }
                        }
                      ]
                      title: 'Avg Memory Percentage for tax-docs-xz5pxrxowhg6e-asp'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 12
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appServicePlan.id
                          }
                          name: 'BytesReceived'
                          aggregationType: 4
                          namespace: 'microsoft.web/serverfarms'
                          metricVisualization: {
                            displayName: 'Data In'
                          }
                        }
                      ]
                      title: 'Avg Data In for tax-docs-xz5pxrxowhg6e-asp'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 0
              y: 4
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appServicePlan.id
                          }
                          name: 'BytesSent'
                          aggregationType: 4
                          namespace: 'microsoft.web/serverfarms'
                          metricVisualization: {
                            displayName: 'Data Out'
                          }
                        }
                      ]
                      title: 'Avg Data Out for tax-docs-xz5pxrxowhg6e-asp'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 6
              y: 4
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appServicePlan.id
                          }
                          name: 'HttpQueueLength'
                          aggregationType: 4
                          namespace: 'microsoft.web/serverfarms'
                          metricVisualization: {
                            displayName: 'Http Queue Length'
                          }
                        }
                      ]
                      title: 'Avg Http Queue Length for tax-docs-xz5pxrxowhg6e-asp'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 12
              y: 4
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: appServicePlan.id
                          }
                          name: 'HttpQueueLength'
                          aggregationType: 4
                          namespace: 'microsoft.web/serverfarms'
                          metricVisualization: {
                            displayName: 'Http Queue Length'
                          }
                        }
                      ]
                      title: 'Avg Http Queue Length for tax-docs-xz5pxrxowhg6e-asp'
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'utc'
                granularity: 'auto'
                relative: '24h'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 24 hours'
              }
              filteredPartIds: [
                'StartboardPart-MonitorChartPart-65e21b99-3dc9-436e-b1ab-eae896f3631b'
                'StartboardPart-MonitorChartPart-65e21b99-3dc9-436e-b1ab-eae896f3631d'
                'StartboardPart-MonitorChartPart-65e21b99-3dc9-436e-b1ab-eae896f3631f'
                'StartboardPart-MonitorChartPart-65e21b99-3dc9-436e-b1ab-eae896f36321'
                'StartboardPart-MonitorChartPart-65e21b99-3dc9-436e-b1ab-eae896f36323'
                'StartboardPart-MonitorChartPart-65e21b99-3dc9-436e-b1ab-eae896f36325'
              ]
            }
          }
        }
      }
    }
  }
}

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: '${name}-mi'
  scope: resourceGroup()
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
  scope: resourceGroup()
}

var storageRBAC = [
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner - Full control over blob containers and data
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor - Read, write, and delete queue messages
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor - Read, write, and delete table data
  '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data Privileged Contributor - Read, write, and modify files/directories
]

resource storageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in storageRBAC: {
    name: guid(logicApp.id, logicApp.name, roleId)
    scope: storageAccount
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: mi.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup()
}

var appInsightsRBAC = [
  '3913510d-42f4-4e42-8a64-420c390055eb'
]

resource appInsightsRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in appInsightsRBAC: {
    name: guid(appInsights.id, appInsights.name, roleId)
    scope: appInsights
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: mi.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

var sbRBAC = [
  '090c5cfd-751d-490a-894a-3ce6f1109419' // Azure Service Bus Data Owner - Full control over Service Bus resources
  '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
]

resource serviceBus 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' existing = {
  name: serviceBusName
  scope: resourceGroup()
}

resource sbRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in sbRBAC: {
    name: guid(serviceBus.id, serviceBus.name, roleId)
    scope: serviceBus
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: mi.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ============================================================================
// VARIABLES - APP SETTINGS
// ============================================================================

// Core runtime settings
var functionsExtensionVersion = '~4'
var functionsWorkerRuntime = 'dotnet'

// Extension bundle for Logic Apps Standard
var extensionBundleId = 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
var extensionBundleVersion = '[1.*, 2.0.0)'

// Application Insights telemetry
var appInsightsInstrumentationKey = appInsights.properties.InstrumentationKey
var appInsightsConnectionString = appInsights.properties.ConnectionString

// Workflow configuration settings
var workflowsSubscriptionId = subscription().subscriptionId
var workflowsResourceGroupName = resourceGroup().name
var workflowsLocationName = location
var workflowsTenantId = subscription().tenantId

// ============================================================================
// LOGIC APP RESOURCE
// ============================================================================

resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name)}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    publicNetworkAccess: 'Enabled'
    storageAccountRequired: true
    siteConfig: {
      appSettings: [
        // Core Azure Functions runtime settings
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionsExtensionVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionsWorkerRuntime
        }
        // Storage account settings (workflow state, run history, artifacts)
        // Using managed identity for secure authentication
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: 'https://${storageAccountName}.blob.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: 'https://${storageAccountName}.queue.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: 'https://${storageAccountName}.table.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: mi.properties.clientId
        }
        // Application Insights telemetry and monitoring
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        // Logic Apps Standard extension bundle
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: extensionBundleId
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: extensionBundleVersion
        }
        // Workflow management settings
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: workflowsSubscriptionId
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: workflowsResourceGroupName
        }
        {
          name: 'WORKFLOWS_LOCATION_NAME'
          value: workflowsLocationName
        }
        {
          name: 'WORKFLOWS_TENANT_ID'
          value: workflowsTenantId
        }
        {
          name: 'WORKFLOWS_MANAGEMENT_BASE_URI'
          value: environment().resourceManager
        }
      ]
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v6.0'
    }
  }
}

param sbConnectionName string = 'serviceBus'

resource serviceBusConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: sbConnectionName
  location: location
  tags: tags
  kind: 'V2'
  properties: {
    displayName: sbConnectionName
    parameterValues: {}
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
    }
  }
  dependsOn: [
    logicApp
    sbRoleAssignments
  ]
}

resource serviceBusConnectionAccessPolicy 'Microsoft.Web/connections/accessPolicies@2018-07-01-preview' = {
  name: logicApp.name
  parent: serviceBusConnection
  location: location
  kind: 'V2'
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicApp.identity.principalId
      }
    }
  }
}

resource DiagnosticSettingsLogicApp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logicApp.name}-diag'
  scope: logicApp
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}

param dashBoardName string = '${name}-dashboard'

resource workflowsDashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: dashBoardName
  location: location
  tags: {
    'hidden-title': 'Tax-Docs-Workflows'
  }
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowActionsFailureRate'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Actions Failure Rate'
                          }
                        }
                      ]
                      title: 'Sum Workflow Actions Failure Rate '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 6
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowActionsFailureRate'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Actions Failure Rate'
                          }
                        }
                      ]
                      title: 'Sum Workflow Actions Failure Rate '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 12
              y: 0
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowJobExecutionDuration'
                          aggregationType: 4
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Job Execution Duration'
                          }
                        }
                      ]
                      title: 'Avg Workflow Job Execution Duration '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 0
              y: 4
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowRunsCompleted'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Runs Completed Count'
                          }
                        }
                      ]
                      title: 'Sum Workflow Runs Completed Count '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 6
              y: 4
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowRunsDispatched'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Runs dispatched Count'
                          }
                        }
                      ]
                      title: 'Sum Workflow Runs dispatched Count '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 12
              y: 4
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowRunsFailureRate'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Runs Failure Rate'
                          }
                        }
                      ]
                      title: 'Sum Workflow Runs Failure Rate '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 0
              y: 8
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowRunsStarted'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Runs Started Count'
                          }
                        }
                      ]
                      title: 'Sum Workflow Runs Started Count '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 6
              y: 8
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowTriggersCompleted'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Triggers Completed Count'
                          }
                        }
                      ]
                      title: 'Sum Workflow Triggers Completed Count '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
          {
            position: {
              x: 12
              y: 8
              rowSpan: 4
              colSpan: 6
            }
            metadata: {
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: {
                            id: logicApp.id
                          }
                          name: 'WorkflowTriggersFailureRate'
                          aggregationType: 1
                          namespace: 'microsoft.web/sites'
                          metricVisualization: {
                            displayName: 'Workflow Triggers Failure Rate'
                          }
                        }
                      ]
                      title: 'Sum Workflow Triggers Failure Rate '
                      titleKind: 1
                      visualization: {
                        chartType: 2
                        legendVisualization: {
                          isVisible: true
                          position: 2
                          hideHoverCard: false
                          hideLabelNames: true
                        }
                        axisVisualization: {
                          x: {
                            isVisible: true
                            axisType: 2
                          }
                          y: {
                            isVisible: true
                            axisType: 1
                          }
                        }
                      }
                      timespan: {
                        relative: {
                          duration: 86400000
                        }
                        showUTCTime: false
                        grain: 1
                      }
                    }
                  }
                  isOptional: true
                }
                {
                  name: 'sharedTimeRange'
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              settings: {
                content: {}
              }
            }
          }
        ]
      }
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'utc'
                granularity: 'auto'
                relative: '24h'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 24 hours'
              }
              filteredPartIds: [
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983e7'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983e9'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983eb'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983ed'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983ef'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983f1'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983f3'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983f5'
                'StartboardPart-MonitorChartPart-08c26d29-ea96-4b0b-8f5d-4d54826983f7'
              ]
            }
          }
        }
      }
    }
  }
}

