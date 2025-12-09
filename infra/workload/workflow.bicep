param logicAppName string
param poProcAPIEndPoint string
param workflowStorageAccountName string
param tags object

var wfDefinition = {
  '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
  contentVersion: '1.0.0.0'
  actions: {
    HTTP: {
      type: 'Http'
      inputs: {
        uri: 'https://${poProcAPIEndPoint}/Orders'
        method: 'POST'
        headers: {
          accept: '*/*'
          'Content-Type': 'application/json'
        }
        body: '@triggerBody()'
      }
      runAfter: {}
      runtimeConfiguration: {
        contentTransfer: {
          transferMode: 'Chunked'
        }
      }
    }
    Condition: {
      type: 'If'
      expression: {
        and: [
          {
            equals: [
              '@outputs(\'HTTP\')?[\'statusCode\']'
              200
            ]
          }
        ]
      }
      actions: {
        'Insert_Entity_(V2)': {
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                referenceName: 'azuretables'
              }
            }
            method: 'post'
            body: '@body(\'Parse_JSON\')'
            path: '/v2/storageAccounts/@{encodeURIComponent(encodeURIComponent(\'${workflowStorageAccountName}\'))}/tables/@{encodeURIComponent(\'audit\')}/entities'
          }
          runAfter: {
            Parse_JSON: [
              'SUCCEEDED'
            ]
          }
        }
        Parse_JSON: {
          type: 'ParseJson'
          inputs: {
            content: '@triggerBody()'
            schema: {
              type: 'object'
              properties: {
                PartitionKey: {
                  type: 'string'
                }
                RowKey: {
                  type: 'string'
                }
                Date: {
                  type: 'string'
                }
                Quantity: {
                  type: 'integer'
                }
                Total: {
                  type: 'number'
                }
                Message: {
                  type: 'string'
                }
              }
            }
          }
        }
      }
      else: {
        actions: {
          Parse_JSON_1: {
            type: 'ParseJson'
            inputs: {
              content: '@triggerBody()'
              schema: {
                type: 'object'
                properties: {
                  PartitionKey: {
                    type: 'string'
                  }
                  RowKey: {
                    type: 'string'
                  }
                  Message: {
                    type: 'string'
                  }
                }
              }
            }
          }
          'Insert_Entity_(V2)_1': {
            type: 'ApiConnection'
            inputs: {
              host: {
                connection: {
                  referenceName: 'azuretables'
                }
              }
              method: 'post'
              body: '@body(\'Parse_JSON_1\')'
              path: '/v2/storageAccounts/@{encodeURIComponent(encodeURIComponent(\'${workflowStorageAccountName}\'))}/tables/@{encodeURIComponent(\'audit\')}/entities'
            }
            runAfter: {
              Parse_JSON_1: [
                'Succeeded'
              ]
            }
          }
        }
      }
      runAfter: {
        HTTP: [
          'SUCCEEDED'
        ]
      }
    }
  }
  outputs: {}
  triggers: {
    'When_there_are_messages_in_a_queue_(V2)': {
      type: 'ApiConnection'
      inputs: {
        host: {
          connection: {
            referenceName: 'azurequeues'
          }
        }
        method: 'get'
        path: '/v2/storageAccounts/@{encodeURIComponent(encodeURIComponent(\'${workflowStorageAccountName}\'))}/queues/@{encodeURIComponent(\'orders-queue\')}/message_trigger'
      }
      recurrence: {
        interval: 1
        frequency: 'Second'
        timeZone: 'Central Standard Time'
      }
      runtimeConfiguration: {
        concurrency: {
          runs: 50
        }
      }
      splitOn: '@triggerBody()?[\'QueueMessagesList\']?[\'QueueMessage\']'
    }
  }
}

resource workflowDef 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'orders-processing'
  location: resourceGroup().location
  properties: {
    definition: wfDefinition
    parameters: {}
  }
  tags: tags
}

resource logicAppSite 'Microsoft.Web/sites@2020-06-01' existing = {
  name: logicAppName
  scope: resourceGroup()
}

resource logicApp 'Microsoft.App/logicApps@2025-10-02-preview' existing = {
  name: logicAppName
  scope: logicAppSite
}
