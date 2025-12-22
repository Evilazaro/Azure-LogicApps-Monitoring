using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// =============================================================================
// Project Resources
// =============================================================================

var ordersAPI = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
                       .WithHttpHealthCheck("/health");

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
                    .WithExternalHttpEndpoints()
                    .WithHttpHealthCheck("/health")
                    .WithReference(ordersAPI)
                    .WaitFor(ordersAPI);

// =============================================================================
// Application Insights Configuration
// =============================================================================
// Application Insights is automatically configured in Azure Container Apps
// through the infrastructure. In local development, it uses user secrets.

ConfigureApplicationInsights(builder, ordersAPI, webApp);

// =============================================================================
// Azure Service Bus Configuration
// =============================================================================
// Supports two modes:
// 1. Local Development: Uses Service Bus emulator (when HostName is not configured)
// 2. Azure Deployment: Connects to existing Azure Service Bus via managed identity

ConfigureServiceBus(builder, ordersAPI);

builder.Build().Run();

// =============================================================================
// Helper Methods
// =============================================================================

static void ConfigureApplicationInsights(
    IDistributedApplicationBuilder builder,
    params IResourceBuilder<ProjectResource>[] projects)
{
    var appInsightsConnString = builder.Configuration["ApplicationInsights:ConnectionString"];
    
    if (string.IsNullOrWhiteSpace(appInsightsConnString))
    {
        return;
    }

    foreach (var project in projects)
    {
        project.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
    }
}

static void ConfigureServiceBus(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersAPI)
{
    const string DefaultConnectionStringName = "messaging";
    const string DefaultTopicName = "OrdersPlaced";
    const string DefaultSubscriptionName = "OrderProcessingSubscription";

    var sbHostName = builder.Configuration["Azure:ServiceBus:HostName"] ?? DefaultConnectionStringName;
    var sbTopicName = builder.Configuration["Azure:ServiceBus:TopicName"] ?? DefaultTopicName;
    var sbSubscriptionName = builder.Configuration["Azure:ServiceBus:SubscriptionName"] ?? DefaultSubscriptionName;
    
    // Determine if we're running in local emulator mode or Azure mode
    var isLocalMode = string.IsNullOrWhiteSpace(sbHostName) || sbHostName == DefaultConnectionStringName;
    var resourceName = isLocalMode ? DefaultConnectionStringName  : sbHostName;

    // Create Service Bus resource
    var serviceBusResource = builder.AddAzureServiceBus(resourceName);
    var serviceBusTopic = serviceBusResource.AddServiceBusTopic(sbTopicName);
    var serviceBus = serviceBusTopic.AddServiceBusSubscription(sbSubscriptionName);

    // Configure emulator for local development
    if (isLocalMode)
    {
        serviceBusResource.RunAsEmulator();
    }

    // Add Service Bus reference to orders API with configuration
    ordersAPI.WithReference(serviceBusResource);
}
