using Aspire.Hosting.Azure;
using Microsoft.Extensions.Hosting;
using System.Diagnostics;

// Create activity source for AppHost startup tracing
using var startupActivity = new ActivitySource("eShop.Orders.AppHost.Startup")
    .StartActivity("AppHost.Startup", ActivityKind.Internal);

startupActivity?.SetTag("aspire.apphost", "eShopOrders");
startupActivity?.SetTag("environment", Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production");

var builder = DistributedApplication.CreateBuilder(args);

ArgumentNullException.ThrowIfNull(builder);

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api");
var ordersWebApp = builder.AddProject<Projects.eShop_Orders_App>("orders-webapp");

// Configure resources based on environment
using (var resourceActivity = new ActivitySource("eShop.Orders.AppHost.Startup")
    .StartActivity("AppHost.ConfigureResources", ActivityKind.Internal))
{
    resourceActivity?.SetTag("environment", builder.Environment.EnvironmentName);
    resourceActivity?.SetTag("is_development", builder.Environment.IsDevelopment());

    var resources = ConfigureInfrastructureResources(builder);
    resourceActivity?.AddEvent(new ActivityEvent("Infrastructure resources configured"));

    ConfigureServices(builder, ordersApi, ordersWebApp, resources);
    resourceActivity?.AddEvent(new ActivityEvent("Services configured"));
}

using (var buildActivity = new ActivitySource("eShop.Orders.AppHost.Startup")
    .StartActivity("AppHost.Build", ActivityKind.Internal))
{
    startupActivity?.SetStatus(ActivityStatusCode.Ok);
    startupActivity?.AddEvent(new ActivityEvent("AppHost startup completed"));

    await builder.Build().RunAsync();
}

/// <summary>
/// Configures infrastructure resources (Application Insights, Service Bus) based on the environment.
/// In non-development environments, references existing Azure resources.
/// In development, uses local development emulators or in-memory alternatives.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>A tuple containing configured infrastructure resources.</returns>
static (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource>? ServiceBus)
    ConfigureInfrastructureResources(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

    return builder.Environment.IsDevelopment()
        ? ConfigureDevelopmentResources(builder)
        : ConfigureProductionResources(builder);
}

/// <summary>
/// Configures Azure resources for development environments using local emulators or optional Azure resources.
/// Retrieves configuration from user secrets, appsettings, or environment variables.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>Configured Application Insights and Service Bus resources.</returns>
static (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource> ServiceBus)
    ConfigureDevelopmentResources(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

    const string TelemetryResourceName = "telemetry";
    const string MessagingResourceName = "messaging";
    const string ServiceBusDevParameterName = "service-bus-dev";

    // Get values from configuration (user secrets, appsettings, or environment variables)
    var config = GetAzureConfiguration(builder);

    IResourceBuilder<AzureApplicationInsightsResource>? appInsights = null;
    IResourceBuilder<AzureServiceBusResource> serviceBus;

    // Configure Application Insights if configuration is available
    if (config.HasAppInsightsConfiguration)
    {
        var resourceGroupParameter = builder.AddParameter("azure-resource-group", config.ResourceGroupName!);
        var appInsightsParameter = builder.AddParameter("azure-application-insights", config.AppInsightsName!);

        appInsights = builder.AddAzureApplicationInsights(TelemetryResourceName)
            .AsExisting(appInsightsParameter, resourceGroupParameter);
    }

    // Configure Service Bus - use emulator if no configuration is available
    if (config.HasServiceBusConfiguration)
    {
        var resourceGroupParameter = builder.AddParameter("azure-resource-group", config.ResourceGroupName!);
        var serviceBusParameter = builder.AddParameter("azure-service-bus", config.ServiceBusNamespace!);

        serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
            .AsExisting(serviceBusParameter, resourceGroupParameter);
    }
    else
    {
        var serviceBusParameter = builder.AddParameter("azure-service-bus", ServiceBusDevParameterName);
        serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
            .RunAsEmulator();
    }

    // Add orders queue to the Service Bus namespace
    serviceBus.AddServiceBusQueue(config.ServiceBusQueueName);

    return (AppInsights: appInsights, ServiceBus: serviceBus);
}

/// <summary>
/// Configures Azure resources for production environments using existing infrastructure.
/// Retrieves configuration from user secrets, appsettings, or environment variables.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>Configured Application Insights and Service Bus resources.</returns>
static (IResourceBuilder<AzureApplicationInsightsResource> AppInsights, IResourceBuilder<AzureServiceBusResource> ServiceBus)
    ConfigureProductionResources(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

    const string TelemetryResourceName = "telemetry";
    const string MessagingResourceName = "messaging";

    // Get and validate configuration
    var config = GetAzureConfiguration(builder);
    ValidateProductionConfiguration(config);

    // Create parameters for Azure resources
    var appInsightsParameter = builder.AddParameter("azure-application-insights", config.AppInsightsName!);
    var serviceBusParameter = builder.AddParameter("azure-service-bus", config.ServiceBusNamespace!);
    var resourceGroupParameter = builder.AddParameter("azure-resource-group", config.ResourceGroupName!);

    // Configure Service Bus with queue
    var serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
        .AsExisting(serviceBusParameter, resourceGroupParameter);

    serviceBus.AddServiceBusQueue(config.ServiceBusQueueName);

    // Configure Application Insights
    var appInsights = builder.AddAzureApplicationInsights(TelemetryResourceName)
        .AsExisting(appInsightsParameter, resourceGroupParameter);

    return (AppInsights: appInsights, ServiceBus: serviceBus);
}

/// <summary>
/// Configures the Orders API and Web App services with appropriate references and settings.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The Orders API project resource.</param>
/// <param name="ordersWebApp">The Orders Web App project resource.</param>
/// <param name="resources">Infrastructure resources to reference.</param>
static void ConfigureServices(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersApi,
    IResourceBuilder<ProjectResource> ordersWebApp,
    (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource>? ServiceBus) resources)
{
    ArgumentNullException.ThrowIfNull(builder);
    ArgumentNullException.ThrowIfNull(ordersApi);
    ArgumentNullException.ThrowIfNull(ordersWebApp);

    // Get authentication configuration
    var authConfig = GetAuthenticationConfiguration(builder);

    // Configure Orders API
    ConfigureOrdersApi(ordersApi, builder.Environment.EnvironmentName, authConfig, resources);

    // Configure Orders Web App (Blazor WebAssembly)
    ConfigureOrdersWebApp(ordersWebApp, ordersApi, authConfig, resources.AppInsights);
}

/// <summary>
/// Configures the Orders API project with environment variables and resource references.
/// </summary>
static void ConfigureOrdersApi(
    IResourceBuilder<ProjectResource> ordersApi,
    string environmentName,
    (string? TenantId, string? ClientId) authConfig,
    (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource>? ServiceBus) resources)
{
    const string AzureTenantIdKey = "AZURE_TENANT_ID";
    const string AzureClientIdKey = "AZURE_CLIENT_ID";

    ordersApi.WithEnvironment("ASPNETCORE_ENVIRONMENT", environmentName);

    // Add authentication configuration if available
    if (!string.IsNullOrWhiteSpace(authConfig.TenantId))
    {
        ordersApi.WithEnvironment(AzureTenantIdKey, authConfig.TenantId);
    }

    if (!string.IsNullOrWhiteSpace(authConfig.ClientId))
    {
        ordersApi.WithEnvironment(AzureClientIdKey, authConfig.ClientId);
    }

    // Add Service Bus reference if available
    if (resources.ServiceBus is not null)
    {
        ordersApi.WithReference(resources.ServiceBus);
    }

    // Add Application Insights reference if available
    if (resources.AppInsights is not null)
    {
        ordersApi.WithReference(resources.AppInsights);
    }

    ordersApi.AsHttp2Service();
}

/// <summary>
/// Configures the Orders Web App project with environment variables and resource references.
/// </summary>
static void ConfigureOrdersWebApp(
    IResourceBuilder<ProjectResource> ordersWebApp,
    IResourceBuilder<ProjectResource> ordersApi,
    (string? TenantId, string? ClientId) authConfig,
    IResourceBuilder<AzureApplicationInsightsResource>? appInsights)
{
    const string AzureTenantIdKey = "AZURE_TENANT_ID";
    const string AzureClientIdKey = "AZURE_CLIENT_ID";

    ordersWebApp.WithReference(ordersApi)
                .AsHttp2Service();

    // Add authentication configuration if available
    if (!string.IsNullOrWhiteSpace(authConfig.TenantId))
    {
        ordersWebApp.WithEnvironment(AzureTenantIdKey, authConfig.TenantId);
    }

    if (!string.IsNullOrWhiteSpace(authConfig.ClientId))
    {
        ordersWebApp.WithEnvironment(AzureClientIdKey, authConfig.ClientId);
    }

    // Add Application Insights reference if available
    if (appInsights is not null)
    {
        ordersWebApp.WithReference(appInsights);
    }
}

/// <summary>
/// Retrieves Azure configuration from the builder's configuration sources.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>A tuple containing Azure resource names and configuration status flags.</returns>
static (string? AppInsightsName, string? ServiceBusNamespace, string? ServiceBusQueueName, string? ResourceGroupName, bool HasAppInsightsConfiguration, bool HasServiceBusConfiguration)
    GetAzureConfiguration(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);
    var appInsightsName = builder.Configuration["Azure:ApplicationInsights:Name"];
    var serviceBusNamespace = builder.Configuration["Azure:ServiceBus:Namespace"];
    var serviceBusQueueName = builder.Configuration["Azure:ServiceBus:TopicName"];
    var resourceGroupName = builder.Configuration["Azure:ResourceGroup"];

    var hasAppInsightsConfig = !string.IsNullOrWhiteSpace(appInsightsName)
                             && !string.IsNullOrWhiteSpace(resourceGroupName);
    var hasServiceBusConfig = !string.IsNullOrWhiteSpace(serviceBusNamespace)
                            && !string.IsNullOrWhiteSpace(resourceGroupName)
                            && !string.IsNullOrWhiteSpace(serviceBusQueueName);

    return (appInsightsName, serviceBusNamespace, serviceBusQueueName, resourceGroupName, hasAppInsightsConfig, hasServiceBusConfig);
}

/// <summary>
/// Retrieves authentication configuration from the builder's configuration sources.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>A tuple containing Azure AD tenant ID and client ID.</returns>
static (string? TenantId, string? ClientId) GetAuthenticationConfiguration(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);
    var tenantId = builder.Configuration["Azure:TenantId"]
                ?? builder.Configuration["AZURE_TENANT_ID"];
    var clientId = builder.Configuration["Azure:ClientId"]
                ?? builder.Configuration["AZURE_CLIENT_ID"];

    return (tenantId, clientId);
}

/// <summary>
/// Validates that all required production configuration values are present.
/// </summary>
static void ValidateProductionConfiguration(
    (string? AppInsightsName, string? ServiceBusNamespace, string? ServiceBusQueueName, string? ResourceGroupName, bool HasAppInsightsConfiguration, bool HasServiceBusConfiguration) config)
{
    if (string.IsNullOrWhiteSpace(config.AppInsightsName))
    {
        throw new InvalidOperationException(
            "Azure Application Insights name is not configured. Set 'Azure:ApplicationInsights:Name' in user secrets or configuration.");
    }

    if (string.IsNullOrWhiteSpace(config.ServiceBusNamespace))
    {
        throw new InvalidOperationException(
            "Azure Service Bus namespace is not configured. Set 'Azure:ServiceBus:Namespace' in user secrets or configuration.");
    }

    if (string.IsNullOrWhiteSpace(config.ServiceBusQueueName))
    {
        throw new InvalidOperationException(
            "Azure Service Bus queue name is not configured. Set 'Azure:ServiceBus:TopicName' in user secrets or configuration.");
    }

    if (string.IsNullOrWhiteSpace(config.ResourceGroupName))
    {
        throw new InvalidOperationException(
            "Azure Resource Group is not configured. Set 'Azure:ResourceGroup' in user secrets or configuration.");
    }

    if (!config.HasServiceBusConfiguration)
    {
        throw new InvalidOperationException(
            "Azure Service Bus configuration is incomplete. Ensure 'Azure:ServiceBus:Namespace', 'Azure:ServiceBus:TopicName', and 'Azure:ResourceGroup' are set in user secrets or configuration.");
    }
}