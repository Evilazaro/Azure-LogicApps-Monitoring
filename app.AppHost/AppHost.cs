// =============================================================================
// eShop Distributed Application Host
// Configures .NET Aspire orchestration for the eShop microservices application
// =============================================================================

using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// =============================================================================
// Shared Azure Parameters
// =============================================================================

var resourceGroupParameter = CreateResourceGroupParameterIfNeeded(builder);

// =============================================================================
// Project Resources Configuration
// =============================================================================

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api").WithExternalHttpEndpoints();

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
.WithExternalHttpEndpoints()
.WithHttpHealthCheck("/health")
.WithReference(ordersApi)
.WaitFor(ordersApi);

ConfigureAzureCredentials(builder, ordersApi);

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
/// Configures Azure credentials for local development environments.
/// Sets AZURE_TENANT_ID and AZURE_CLIENT_ID environment variables when configured.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The orders API project resource to configure with Azure credentials.</param>
/// <remarks>
/// This method only applies to local development mode. In Azure Container Apps deployment,
/// Aspire automatically configures the managed identity. Adding credentials here during
/// publish mode would create duplicates and potentially cause authentication failures.
/// </remarks>
static void ConfigureAzureCredentials(IDistributedApplicationBuilder builder, IResourceBuilder<ProjectResource> ordersApi)
{
    ArgumentNullException.ThrowIfNull(builder);

    // Only configure Azure credentials for local development
    // In Azure Container Apps deployment, Aspire automatically configures the managed identity
    // Adding AZURE_CLIENT_ID here would create duplicates and potentially cause authentication failures
    // if the local dev client ID differs from the deployed managed identity
    if (builder.Environment.IsDevelopment() && !builder.ExecutionContext.IsPublishMode)
    {
        if (!string.IsNullOrWhiteSpace(builder.Configuration["Azure:TenantId"]))
        {
            ordersApi.WithEnvironment("AZURE_TENANT_ID", builder.Configuration["Azure:TenantId"]);
        }

        if (!string.IsNullOrWhiteSpace(builder.Configuration["Azure:ClientId"]))
        {
            ordersApi.WithEnvironment("AZURE_CLIENT_ID", builder.Configuration["Azure:ClientId"]);
        }
    }
}

/// <summary>
/// Creates the Azure Resource Group parameter if Azure resources are configured.
/// This ensures the parameter is only created once and shared across all Azure resources.
/// </summary>
/// <param name="builder">The distributed application builder used to create the parameter.</param>
/// <returns>
/// A <see cref="IResourceBuilder{ParameterResource}"/> containing the resource group parameter if Azure:ResourceGroup 
/// is configured; otherwise, <c>null</c> to indicate local development mode without Azure resources.
/// </returns>
/// <remarks>
/// <para>
/// This method reads the "Azure:ResourceGroup" configuration key to determine if Azure resources are being used.
/// If the value is null or whitespace, the method returns null, indicating that the application should use 
/// local development resources (containers, emulators, etc.) instead of Azure services.
/// </para>
/// <para>
/// The returned parameter builder is intended to be shared across multiple Azure resource configurations
/// (Service Bus, SQL Database, Application Insights) to maintain consistency and avoid duplicate parameters.
/// </para>
/// </remarks>
/// <exception cref="ArgumentNullException">Thrown when <paramref name="builder"/> is null.</exception>
static IResourceBuilder<ParameterResource>? CreateResourceGroupParameterIfNeeded(
IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

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
/// <param name="resourceGroupParameter">The Azure resource group parameter.</param>
/// <param name="projects">The project resources to configure with Application Insights.</param>
static void ConfigureApplicationInsights(
IDistributedApplicationBuilder builder,
IResourceBuilder<ParameterResource>? resourceGroupParameter,
params IResourceBuilder<ProjectResource>[] projects)
{
    ArgumentNullException.ThrowIfNull(builder);
    ArgumentNullException.ThrowIfNull(projects);

    const string AppInsightsConnectionStringKey = "ApplicationInsights:ConnectionString";

    var appInsightsConnectionString = builder.Configuration[AppInsightsConnectionStringKey];
    var appInsightsName = builder.Configuration["Azure:ApplicationInsights:Name"];

    if (string.IsNullOrWhiteSpace(appInsightsName))
    {
        // Application Insights not configured - will use local development mode
        return;
    }
    else
    {
        // Azure deployment mode - use existing Application Insights with managed identity
        if (resourceGroupParameter is null)
        {
            throw new InvalidOperationException(
            "Azure Resource Group configuration is required when using Azure Application Insights. " +
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
    ArgumentNullException.ThrowIfNull(builder);
    ArgumentNullException.ThrowIfNull(ordersApi);

    const string DefaultNamespaceName = "localhost";
    const string DefaultConnectionStringName = "messaging";
    const string DefaultTopicName = "ordersplaced";
    const string DefaultSubscriptionName = "orderprocessingsub";

    // Use null-coalescing operator for cleaner code
    var sbHostName = builder.Configuration["Azure:ServiceBus:HostName"] ?? DefaultNamespaceName;
    var sbTopicName = builder.Configuration["Azure:ServiceBus:TopicName"] ?? DefaultTopicName;
    var sbSubscriptionName = builder.Configuration["Azure:ServiceBus:SubscriptionName"] ?? DefaultSubscriptionName;

    // Determine if we're running in local emulator mode or Azure mode
    var isLocalMode = sbHostName.Equals(DefaultNamespaceName, StringComparison.OrdinalIgnoreCase);

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

        var dotIndex = sbHostName.IndexOf('.', StringComparison.Ordinal);
        var serviceBusName = dotIndex > 0 ? sbHostName[..dotIndex] : sbHostName;
        var sbParam = builder.AddParameter("service-bus", serviceBusName);

        serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName)
        .AsExisting(sbParam, resourceGroupParameter);
    }

    // Configure Service Bus topology
    var serviceBusTopic = serviceBusResource.AddServiceBusTopic(sbTopicName);
    serviceBusTopic.AddServiceBusSubscription(sbSubscriptionName);

    // Add Service Bus reference to orders API
    ordersApi.WithReference(serviceBusResource)
    .WaitFor(serviceBusResource);
}

/// <summary>
/// Configures Azure SQL Database for order data persistence.
/// Supports both local container mode and Azure managed identity authentication with Entra ID.
/// In Azure mode, Entra ID authentication is automatically configured through managed identity.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The orders API project resource to configure with SQL Database.</param>
/// <param name="resourceGroupParameter">The shared Azure resource group parameter.</param>
static void ConfigureSQLAzure(
IDistributedApplicationBuilder builder,
IResourceBuilder<ProjectResource> ordersApi,
IResourceBuilder<ParameterResource>? resourceGroupParameter)
{
    ArgumentNullException.ThrowIfNull(builder);
    ArgumentNullException.ThrowIfNull(ordersApi);

    const string DefaultSqlServerName = "OrdersDatabase";
    const string DefaultDatabaseName = "OrderDb";

    // Use null-coalescing operator for cleaner code
    var sqlServerName = builder.Configuration["Azure:SqlServer:Name"] ?? DefaultSqlServerName;
    var sqlDatabaseName = builder.Configuration["Azure:SqlServer:DatabaseName"] ?? DefaultDatabaseName;
    var isLocalMode = sqlServerName.Equals(DefaultSqlServerName, StringComparison.OrdinalIgnoreCase);

    if (isLocalMode)
    {
        // Local development mode - use SQL Server container with persistent volume
        var sqlServer = builder.AddAzureSqlServer(DefaultSqlServerName)
        .RunAsContainer(configureContainer =>
        {
            configureContainer.WithDataVolume();
        });

        var sqlDatabase = sqlServer.AddDatabase(DefaultDatabaseName);

        ordersApi.WithReference(sqlDatabase)
        .WaitFor(sqlDatabase);
    }
    else
    {
        // Azure deployment mode - use existing Azure SQL Server with managed identity
        // Entra ID authentication is automatically configured when using RunAsExisting()
        if (resourceGroupParameter is null)
        {
            throw new InvalidOperationException(
            "Azure Resource Group configuration is required when using Azure SQL Database. " +
            "Please configure 'Azure:ResourceGroup' in your application settings.");
        }

        var sqlServerParam = builder.AddParameter("sql-server", sqlServerName);
        var sqlServer = builder.AddAzureSqlServer(DefaultSqlServerName)
        .RunAsExisting(sqlServerParam, resourceGroupParameter);

        var sqlDatabase = sqlServer.AddDatabase(sqlDatabaseName).WithDefaultAzureSku();

        ordersApi.WithReference(sqlDatabase)
        .WaitFor(sqlDatabase);
    }
}