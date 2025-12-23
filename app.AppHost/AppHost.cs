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
                    .WaitFor(ordersAPI)
                    .WithReplicas(10);

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

/// <summary>
/// Configures Application Insights connection string for the specified projects.
/// Enables distributed tracing and telemetry collection in Azure environments.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="projects">The project resources to configure with Application Insights.</param>
static void ConfigureApplicationInsights(
    IDistributedApplicationBuilder builder,
    params IResourceBuilder<ProjectResource>[] projects)
{
    var appInsightsConnString = builder.Configuration["ApplicationInsights:ConnectionString"];

    if (string.IsNullOrWhiteSpace(appInsightsConnString))
    {
        // Application Insights not configured - will use local development mode
        return;
    }

    foreach (var project in projects)
    {
        project.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
    }
}

/// <summary>
/// Configures Azure Service Bus for order message processing.
/// Supports both local emulator mode and Azure managed identity authentication.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersAPI">The orders API project resource to configure with Service Bus.</param>
static void ConfigureServiceBus(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersAPI)
{
    const string DefaultNamespaceName = "localhost";
    const string DefaultConnectionStringName = "messaging";
    const string DefaultTopicName = "OrdersPlaced";
    const string DefaultSubscriptionName = "OrderProcessingSubscription";

    var sbHostName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:HostName"]) ? DefaultNamespaceName : builder.Configuration["Azure:ServiceBus:HostName"];
    var sbTopicName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:TopicName"]) ? DefaultTopicName : builder.Configuration["Azure:ServiceBus:TopicName"];
    var sbSubscriptionName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:SubscriptionName"]) ? DefaultSubscriptionName : builder.Configuration["Azure:ServiceBus:SubscriptionName"];

    // Determine if we're running in local emulator mode or Azure mode
    var isLocalMode = sbHostName.Equals(DefaultNamespaceName, StringComparison.OrdinalIgnoreCase);
    var resourceName = isLocalMode ? DefaultConnectionStringName : sbHostName;

    // Create Service Bus resource

    if (isLocalMode)
    {
        var serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName);
        var serviceBusTopic = serviceBusResource.AddServiceBusTopic(sbTopicName);
        var serviceBusSubscription = serviceBusTopic.AddServiceBusSubscription(sbSubscriptionName);

        serviceBusResource.RunAsEmulator();

        // Add Service Bus reference to orders API with configuration
        ordersAPI.WithReference(serviceBusResource);
    }
    else
    {
        var sbParam = builder.AddParameter("service-bus", resourceName);
        var sbResourceGroupParam = builder.AddParameterFromConfiguration("resourceGroup", "Azure:ResourceGroup");
        var serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName).RunAsExisting(sbParam, sbResourceGroupParam);

        var serviceBusTopic = serviceBusResource.AddServiceBusTopic(sbTopicName);
        var serviceBusSubscription = serviceBusTopic.AddServiceBusSubscription(sbSubscriptionName);

        // Add Service Bus reference to orders API with configuration
        ordersAPI.WithReference(serviceBusResource);
    }

    var azureSubscriptionId = builder.Configuration["Azure:SubscriptionId"];
    var azureClientId = builder.Configuration["Azure:ClientId"];
    var azureTenantId = builder.Configuration["Azure:TenantId"];

    if (!string.IsNullOrWhiteSpace(azureSubscriptionId) &&
        !string.IsNullOrWhiteSpace(azureClientId) &&
        !string.IsNullOrWhiteSpace(azureTenantId))
    {
        ordersAPI.WithEnvironment("AZURE_SUBSCRIPTION_ID", azureSubscriptionId ?? string.Empty);
        ordersAPI.WithEnvironment("AZURE_CLIENT_ID", azureClientId ?? string.Empty);
        ordersAPI.WithEnvironment("AZURE_TENANT_ID", azureTenantId ?? string.Empty);
    }

    ordersAPI.WithReplicas(10);
}
