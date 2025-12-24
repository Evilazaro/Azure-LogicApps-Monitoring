using Aspire.Hosting.Azure;

var builder = DistributedApplication.CreateBuilder(args);

// =============================================================================
// Project Resources Configuration
// =============================================================================

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api");

ConfigureOrdersStoragePath(builder, ordersApi);

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
    .WithExternalHttpEndpoints()
    .WithHttpHealthCheck("/health")
    .WithReference(ordersApi)
    .WaitFor(ordersApi);

// =============================================================================
// Observability Configuration
// =============================================================================
// Application Insights is automatically configured in Azure Container Apps
// through the infrastructure. In local development, it uses user secrets.

ConfigureApplicationInsights(builder, ordersApi, webApp);

// =============================================================================
// Azure Service Bus Configuration
// =============================================================================
// Supports two modes:
// 1. Local Development: Uses Service Bus emulator (when HostName is not configured)
// 2. Azure Deployment: Connects to existing Azure Service Bus via managed identity

ConfigureServiceBus(builder, ordersApi);

builder.Build().Run();

// =============================================================================
// Helper Methods
// =============================================================================

/// <summary>
/// Configures the storage directory path for orders based on the deployment environment.
/// Uses absolute paths for Azure Container Apps and relative paths for local development.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The orders API project resource.</param>
static void ConfigureOrdersStoragePath(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersApi)
{
    const string DefaultParamName = "storage";
    const string LocalStoragePath = "data/orders";
    const string StorageDirectoryKey = "OrderStorage__StorageDirectory";
    const string DefaultStorageName = "orders-storage";
    const string BlobContainerName = "orders";

    var storageResourceName = builder.Configuration["Azure:Storage:AccountName"];
    var isLocalMode = string.IsNullOrWhiteSpace(storageResourceName) ||
                      storageResourceName.Equals(DefaultStorageName, StringComparison.OrdinalIgnoreCase);

    if (isLocalMode)
    {
        // Local development mode - use Azure Storage emulator
        var storageResource = builder.AddAzureStorage(DefaultParamName)
            .RunAsEmulator();

        var blobContainer = storageResource.AddBlobs(BlobContainerName);

        ordersApi
            .WithEnvironment(StorageDirectoryKey, LocalStoragePath)
            .WithReference(blobContainer);
    }
    else
    {
        // Azure deployment mode - use existing storage account with managed identity
        var resourceGroupParameter = builder.AddParameterFromConfiguration("resourceGroup", "Azure:ResourceGroup");
        var storageAccountParameter = builder.AddParameter(DefaultParamName, storageResourceName!);

        var storageResource = builder.AddAzureStorage(DefaultParamName)
            .AsExisting(storageAccountParameter, resourceGroupParameter);

        var blobContainer = storageResource.AddBlobs(BlobContainerName);

        ordersApi.WithReference(blobContainer);
    }
}

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
    const string AppInsightsConnectionStringKey = "ApplicationInsights:ConnectionString";
    const string AppInsightsEnvironmentKey = "APPLICATIONINSIGHTS_CONNECTION_STRING";

    var appInsightsConnectionString = builder.Configuration[AppInsightsConnectionStringKey];

    if (string.IsNullOrWhiteSpace(appInsightsConnectionString))
    {
        // Application Insights not configured - will use local development mode
        return;
    }

    foreach (var project in projects)
    {
        project.WithEnvironment(AppInsightsEnvironmentKey, appInsightsConnectionString);
    }
}

/// <summary>
/// Configures Azure Service Bus for order message processing.
/// Supports both local emulator mode and Azure managed identity authentication.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The orders API project resource to configure with Service Bus.</param>
static void ConfigureServiceBus(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersApi)
{
    const string DefaultNamespaceName = "localhost";
    const string DefaultConnectionStringName = "messaging";
    const string DefaultTopicName = "OrdersPlaced";
    const string DefaultSubscriptionName = "OrderProcessingSubscription";

    var sbHostName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:HostName"]) ? DefaultNamespaceName : builder.Configuration["Azure:ServiceBus:HostName"];
    var sbTopicName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:TopicName"]) ? DefaultTopicName : builder.Configuration["Azure:ServiceBus:TopicName"];
    var sbSubscriptionName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:SubscriptionName"]) ? DefaultSubscriptionName : builder.Configuration["Azure:ServiceBus:SubscriptionName"];

    // Determine if we're running in local emulator mode or Azure mode
    var isLocalMode = (sbHostName ?? string.Empty).Equals(DefaultNamespaceName, StringComparison.OrdinalIgnoreCase);

    // Create Service Bus resource
    IResourceBuilder<Aspire.Hosting.Azure.AzureServiceBusResource> serviceBusResource;

    if (isLocalMode)
    {
        serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName)
            .RunAsEmulator();
    }
    else
    {
        var sbParam = builder.AddParameter("service-bus", sbHostName ?? DefaultNamespaceName);
        var sbResourceGroupParam = builder.AddParameterFromConfiguration("resourceGroup", "Azure:ResourceGroup");
        
        serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName)
            .AsExisting(sbParam, sbResourceGroupParam);
    }

    // Configure Service Bus topology
    var serviceBusTopic = serviceBusResource.AddServiceBusTopic(sbTopicName ?? DefaultTopicName);
    serviceBusTopic.AddServiceBusSubscription(sbSubscriptionName ?? DefaultSubscriptionName);

    // Add Service Bus reference to orders API
    ordersApi.WithReference(serviceBusResource);

    // Configure Azure credentials if available
    var azureSubscriptionId = builder.Configuration["Azure:SubscriptionId"];
    var azureClientId = builder.Configuration["Azure:ClientId"];
    var azureTenantId = builder.Configuration["Azure:TenantId"];

    if (!string.IsNullOrWhiteSpace(azureSubscriptionId) &&
        !string.IsNullOrWhiteSpace(azureClientId) &&
        !string.IsNullOrWhiteSpace(azureTenantId))
    {
        ordersApi
            .WithEnvironment("AZURE_SUBSCRIPTION_ID", azureSubscriptionId)
            .WithEnvironment("AZURE_CLIENT_ID", azureClientId)
            .WithEnvironment("AZURE_TENANT_ID", azureTenantId);
    }
}
