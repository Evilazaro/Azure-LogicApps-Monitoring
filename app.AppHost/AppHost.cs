var builder = DistributedApplication.CreateBuilder(args);

// =============================================================================
// Shared Azure Parameters
// =============================================================================

var resourceGroupParameter = CreateResourceGroupParameterIfNeeded(builder);

// =============================================================================
// Project Resources Configuration
// =============================================================================

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api");

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

ConfigureApplicationInsights(builder, resourceGroupParameter, ordersApi, webApp);

ConfigureSQLAzure(builder, ordersApi, resourceGroupParameter);

// =============================================================================
// Azure Service Bus Configuration
// =============================================================================
// Supports two modes:
// 1. Local Development: Uses Service Bus emulator (when HostName is not configured)
// 2. Azure Deployment: Connects to existing Azure Service Bus via managed identity

ConfigureServiceBus(builder, ordersApi, resourceGroupParameter);

builder.Build().Run();

// =============================================================================
// Helper Methods
// =============================================================================

/// <summary>
/// Creates the Azure Resource Group parameter if Azure resources are configured.
/// This ensures the parameter is only created once and shared across all Azure resources.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>The resource group parameter builder, or null if not in Azure mode.</returns>
static IResourceBuilder<ParameterResource>? CreateResourceGroupParameterIfNeeded(
    IDistributedApplicationBuilder builder)
{
    const string ResourceGroupConfigKey = "Azure:ResourceGroup";

    var resourceGroup = builder.Configuration[ResourceGroupConfigKey];

    if (string.IsNullOrWhiteSpace(resourceGroup))
    {
        return null;
    }

    return builder.AddParameterFromConfiguration("resourceGroup", ResourceGroupConfigKey);
}

/// <summary>
/// Configures Application Insights connection string for the specified projects.
/// Enables distributed tracing and telemetry collection in Azure environments.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="projects">The project resources to configure with Application Insights.</param>
static void ConfigureApplicationInsights(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ParameterResource>? resourceGroupParameter,
    params IResourceBuilder<ProjectResource>[] projects)
{
    const string AppInsightsConnectionStringKey = "ApplicationInsights:ConnectionString";
    const string AppInsightsEnvironmentKey = "APPLICATIONINSIGHTS_CONNECTION_STRING";

    var appInsightsConnectionString = builder.Configuration[AppInsightsConnectionStringKey];
    var appInsightsName = builder.Configuration["Azure:ApplicationInsights:Name"];

    if (string.IsNullOrWhiteSpace(appInsightsName))
    {
        // Application Insights not configured - will use local development mode
        return;
    }
    else
    {
        // Azure deployment mode - use existing storage account with managed identity
        if (resourceGroupParameter is null)
        {
            throw new InvalidOperationException(
                "Azure Resource Group configuration is required when using Azure Storage Account. " +
                "Please configure 'Azure:ResourceGroup' in your application settings.");
        }

        var appInsightsParam = builder.AddParameter("app-insights", appInsightsName);
        var appInsights = builder.AddAzureApplicationInsights("telemetry").RunAsExisting(appInsightsParam, resourceGroupParameter);
        foreach (var project in projects)
        {
            project.WithReference(appInsights);
        }
    }
}

/// <summary>
/// Configures Azure Service Bus for order message processing.
/// Supports both local emulator mode and Azure managed identity authentication.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The orders API project resource to configure with Service Bus.</param>
/// <param name="resourceGroupParameter">The shared Azure resource group parameter.</param>
static void ConfigureServiceBus(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersApi,
    IResourceBuilder<ParameterResource>? resourceGroupParameter)
{
    const string DefaultNamespaceName = "localhost";
    const string DefaultConnectionStringName = "messaging";
    const string DefaultTopicName = "OrdersPlaced";
    const string DefaultSubscriptionName = "OrderProcessingSubscription";

    var sbHostName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:HostName"])
        ? DefaultNamespaceName
        : builder.Configuration["Azure:ServiceBus:HostName"];

    var sbTopicName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:TopicName"])
        ? DefaultTopicName
        : builder.Configuration["Azure:ServiceBus:TopicName"];

    var sbSubscriptionName = string.IsNullOrEmpty(builder.Configuration["Azure:ServiceBus:SubscriptionName"])
        ? DefaultSubscriptionName
        : builder.Configuration["Azure:ServiceBus:SubscriptionName"];

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
        if (resourceGroupParameter is null)
        {
            throw new InvalidOperationException(
                "Azure Resource Group configuration is required when using Azure Service Bus. " +
                "Please configure 'Azure:ResourceGroup' in your application settings.");
        }

        var sbParam = builder.AddParameter("service-bus", sbHostName ?? DefaultNamespaceName);

        serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName)
            .AsExisting(sbParam, resourceGroupParameter);
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

/// <summary>
/// Configures Azure SQL Database connection for the Orders API.
/// Supports both local SQL Server (container-based) and Azure SQL Database with managed identity.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The orders API project resource to configure with SQL Database.</param>
/// <param name="resourceGroupParameter">The shared Azure resource group parameter.</param>
static void ConfigureSQLAzure(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersApi,
    IResourceBuilder<ParameterResource>? resourceGroupParameter)
{
    // Default configuration for local development
    // Uses localhost SQL Server running in a container
    const string DefaultSqlServerName = "localhost";
    const string DefaultDatabaseName = "eShopOrdersDb";
    const string DefaultSqlUserName = "sa";
    const string DefaultSqlPassword = "123#@!qweEWQ";
    
    // Read SQL Server configuration from user secrets or appsettings
    // Falls back to localhost if not configured (local development mode)
    var sqlServerName = string.IsNullOrEmpty(builder.Configuration["Azure:SQL:ServerName"])
        ? DefaultSqlServerName
        : builder.Configuration["Azure:SQL:ServerName"];
    var sqlDatabaseName = string.IsNullOrEmpty(builder.Configuration["Azure:SQL:DatabaseName"])
        ? DefaultDatabaseName
        : builder.Configuration["Azure:SQL:DatabaseName"];
    
    // Determine deployment mode based on server name
    // localhost = local container, anything else = Azure SQL Database
    var isLocalMode = (sqlServerName ?? string.Empty).Equals(DefaultSqlServerName, StringComparison.OrdinalIgnoreCase);
    
    if (isLocalMode)
    {
        // Local development mode - use SQL Server in container
        // Container is automatically provisioned with default credentials
        // Connection string is injected into the ordersApi automatically
        var sqlResource = builder.AddAzureSqlServer("sql-db").RunAsContainer();
        ordersApi.WithReference(sqlResource);
    }
    else
    {
        // Azure deployment mode - use existing Azure SQL Server with managed identity authentication
        // Requires resource group configuration to locate the existing SQL Server
        if (resourceGroupParameter is null)
        {
            throw new InvalidOperationException(
                "Azure Resource Group configuration is required when using Azure SQL Database. " +
                "Please configure 'Azure:ResourceGroup' in your application settings.");
        }
        
        // Create parameter for SQL Server name and connect to existing resource
        // AsExisting indicates this resource is already deployed via Bicep
        var sqlServerParam = builder.AddParameter("sql-server", sqlServerName!);
        var sqlResource = builder.AddAzureSqlServer("sql-db")
            .AsExisting(sqlServerParam, resourceGroupParameter)
            .AddDatabase(DefaultDatabaseName);
        
        // WithReference configures the connection string in the ordersApi
        // Uses managed identity authentication (passwordless) when deployed to Azure
        ordersApi.WithReference(sqlResource);
    }
}