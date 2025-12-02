@description('Base name for Logic App and App Service Plan resources. Will be suffixed with unique string for global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).') 
param envName string

@description('Azure region for Logic App deployment. Must support Workflow Standard SKU and Application Insights.')
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
param storageAccountId string

@description('Name of the Application Insights instance for telemetry collection and performance monitoring.')
param appInsightsName string

@description('Resource tags applied to Logic App, App Service Plan, and dashboard resources for cost tracking and governance.')
param tags object

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-apis-asp'
  location: location
  sku: {
    name: 'P0v3'
    tier: 'Premium0V3'
    size: 'P0v3'
    family: 'Pv3'
    capacity: 1
  }
  kind: 'linux'
  tags: tags
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup()
}

resource webApi 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-api'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
    httpsOnly: true
  }
}

resource webApiDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webApi.name}-diag'
  scope: webApi
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
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

resource DiagnosticSettingsAsp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appServicePlan.name}-diag'
  scope: appServicePlan
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
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
  location: location
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

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the deployed Function App for API layer')
output FUNCTION_APP_ID string = webApi.id

@description('Name of the deployed Function App')
output FUNCTION_APP_NAME string = webApi.name

@description('Default hostname of the Function App')
output FUNCTION_APP_DEFAULT_HOSTNAME string = webApi.properties.defaultHostName
