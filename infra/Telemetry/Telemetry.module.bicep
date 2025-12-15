@description('The location for the resource(s) to be deployed.')
param location string = resourceGroup().location

param Application_Insights string

resource Telemetry 'Microsoft.Insights/components@2020-02-02' existing = {
  name: Application_Insights
}

output appInsightsConnectionString string = Telemetry.properties.ConnectionString

output name string = Application_Insights