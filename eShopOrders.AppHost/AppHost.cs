using Aspire.Hosting.Azure;
using Microsoft.Extensions.Hosting;
using System.Diagnostics;

// ========== ActivitySource Management ==========
// Static ActivitySource ensures proper lifecycle management and prevents resource leaks
// This instance is reused throughout the application lifetime
var activitySource = new ActivitySource("eShop.Orders.AppHost");

// ========== Application Startup ==========
// Create root activity for AppHost startup tracing
using var startupActivity = activitySource.StartActivity("AppHost.Startup", ActivityKind.Internal);

try
{
    startupActivity?.SetTag("aspire.apphost", "eShopOrders");
    startupActivity?.SetTag("environment", Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production");
    startupActivity?.SetTag("version", "1.0.0");

    var builder = DistributedApplication.CreateBuilder(args);

    ArgumentNullException.ThrowIfNull(builder);

    var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api");
    var ordersWebApp = builder.AddProject<Projects.eShop_Orders_App>("orders-webapp");

    // ========== Resource Configuration ==========
    // Configure infrastructure resources based on environment
    using (var resourceActivity = activitySource.StartActivity("AppHost.ConfigureResources", ActivityKind.Internal))
    {
        try
        {
            resourceActivity?.SetTag("environment", builder.Environment.EnvironmentName);
            resourceActivity?.SetTag("is_development", builder.Environment.IsDevelopment());

            var resources = ConfigureInfrastructureResources(builder);
            resourceActivity?.AddEvent(new ActivityEvent("Infrastructure resources configured"));

            ConfigureServices(builder, ordersApi, ordersWebApp, resources);
            resourceActivity?.AddEvent(new ActivityEvent("Services configured"));

            resourceActivity?.SetStatus(ActivityStatusCode.Ok);
        }
        catch (Exception ex)
        {
            resourceActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            resourceActivity?.AddException(ex);
            throw;
        }
    }

    // ========== Application Build and Run ==========
    using (var buildActivity = activitySource.StartActivity("AppHost.Build", ActivityKind.Internal))
    {
        try
        {
            startupActivity?.SetStatus(ActivityStatusCode.Ok);
            startupActivity?.AddEvent(new ActivityEvent("AppHost startup completed"));

            await builder.Build().RunAsync();
        }
        catch (Exception ex)
        {
            buildActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            buildActivity?.AddException(ex);
            throw;
        }
    }
}
catch (Exception ex)
{
    startupActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
    startupActivity?.AddException(ex);
    Console.Error.WriteLine($"AppHost startup failed: {ex.Message}");
    throw;
}

// ========== Infrastructure Configuration Methods ==========

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

    const string TelemetryParamName = "azure-application-insights-dev";
    const string TelemetryResourceName = "telemetry";
    const string MessagingParamName = "azure-service-bus-dev";
    const string MessagingResourceName = "messaging";
    const string ServiceBusDevParameterName = "service-bus-dev";
    const string ResourceGroupParameterName = "azure-resource-group-dev";

    // Get values from configuration (user secrets, appsettings, or environment variables)
    var config = GetAzureConfiguration(builder);

    IResourceBuilder<AzureApplicationInsightsResource>? appInsights = null;
    IResourceBuilder<AzureServiceBusResource>? serviceBus;
    IResourceBuilder<ParameterResource>? resourceGroupParameter = null;

    if (config.HasResourceGroupConfiguration)
    {
        resourceGroupParameter = builder.AddParameter(ResourceGroupParameterName, config.ResourceGroupName!);
    }

    // Configure Application Insights if configuration is available
    if (config.HasAppInsightsConfiguration)
    {
        var appInsightsParameter = builder.AddParameter(TelemetryParamName, config.AppInsightsName!);

        appInsights = builder.AddAzureApplicationInsights(TelemetryResourceName)
            .AsExisting(appInsightsParameter, resourceGroupParameter);
    }

    // Configure Service Bus - use emulator if no configuration is available
    if (config.HasServiceBusConfiguration)
    {
        var serviceBusParameter = builder.AddParameter(MessagingParamName, config.ServiceBusNamespace!);

        serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
            .AsExisting(serviceBusParameter, resourceGroupParameter);
    }
    else
    {
        var serviceBusParameter = builder.AddParameter(MessagingParamName, ServiceBusDevParameterName);
        serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
            .RunAsEmulator();
    }

    // Add orders topic with subscription to the Service Bus namespace
    // The subscription is required for the API to receive messages from the topic
    var topicName = config.ServiceBusTopicName ?? "OrdersPlaced";
    var ordersTopic = serviceBus.AddServiceBusTopic(topicName);
    ordersTopic.AddServiceBusSubscription("OrderProcessingSubscription");

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

    // Configure Service Bus with topic and subscription
    var serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
        .AsExisting(serviceBusParameter, resourceGroupParameter);

    // Add orders topic with subscription
    // Topic name should always be configured in production, but provide a default for safety
    var topicName = config.ServiceBusTopicName ?? "OrdersPlaced";
    var ordersTopic = serviceBus.AddServiceBusTopic(topicName);
    ordersTopic.AddServiceBusSubscription("OrderProcessingSubscription");

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

    var clientId = authConfig.ClientId;
    var tenantId = authConfig.TenantId;

    if (!string.IsNullOrWhiteSpace(clientId) && !string.IsNullOrWhiteSpace(tenantId))
    {
        ordersApi.WithEnvironment("AZURE_CLIENT_ID", clientId)
                 .WithEnvironment("AZURE_TENANT_ID", tenantId);
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
    ordersWebApp.WithReference(ordersApi)
                .AsHttp2Service();

    // Add Application Insights reference if available
    if (appInsights is not null)
    {
        ordersWebApp.WithReference(appInsights);
    }

    var clientId = authConfig.ClientId;
    var tenantId = authConfig.TenantId;

    if (!string.IsNullOrWhiteSpace(clientId) && !string.IsNullOrWhiteSpace(tenantId))
    {
        ordersWebApp.WithEnvironment("AZURE_CLIENT_ID", clientId)
                    .WithEnvironment("AZURE_TENANT_ID", tenantId);
    }
}

/// <summary>
/// Retrieves Azure configuration from the builder's configuration sources.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>A tuple containing Azure resource names and configuration status flags.</returns>
static (string? AppInsightsName, string? ServiceBusNamespace, string? ServiceBusTopicName, string? ResourceGroupName, bool HasResourceGroupConfiguration, bool HasAppInsightsConfiguration, bool HasServiceBusConfiguration)
    GetAzureConfiguration(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

    var appInsightsName = builder.Configuration["Azure:ApplicationInsights:Name"];
    var serviceBusNamespace = builder.Configuration["Azure:ServiceBus:Namespace"];
    var serviceBusTopicName = builder.Configuration["Azure:ServiceBus:TopicName"] ?? "OrdersPlaced";
    var resourceGroupName = builder.Configuration["Azure:ResourceGroup"];

    var hasAppInsightsConfig = !string.IsNullOrWhiteSpace(appInsightsName)
                             && !string.IsNullOrWhiteSpace(resourceGroupName);
    var hasServiceBusConfig = !string.IsNullOrWhiteSpace(serviceBusNamespace)
                            && !string.IsNullOrWhiteSpace(resourceGroupName)
                            && !string.IsNullOrWhiteSpace(serviceBusTopicName);

    var hasResourceGroup = !string.IsNullOrWhiteSpace(resourceGroupName);

    return (appInsightsName, serviceBusNamespace, serviceBusTopicName, resourceGroupName, hasResourceGroup, hasAppInsightsConfig, hasServiceBusConfig);
}

/// <summary>
/// Retrieves authentication configuration from the builder's configuration sources.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>A tuple containing Azure AD tenant ID and client ID.</returns>
static (string? TenantId, string? ClientId) GetAuthenticationConfiguration(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

    var tenantId = builder.Configuration["AZURE_TENANT_ID"];
    var clientId = builder.Configuration["AZURE_CLIENT_ID"];

    return (tenantId, clientId);
}

/// <summary>
/// Validates that all required production configuration values are present.
/// </summary>
static void ValidateProductionConfiguration(
    (string? AppInsightsName, string? ServiceBusNamespace, string? ServiceBusTopicName, string? ResourceGroupName, bool HasResourceGroupConfiguration, bool HasAppInsightsConfiguration, bool HasServiceBusConfiguration) config)
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

    if (string.IsNullOrWhiteSpace(config.ServiceBusTopicName))
    {
        throw new InvalidOperationException(
            "Azure Service Bus topic name is not configured. Set 'Azure:ServiceBus:TopicName' in user secrets or configuration.");
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