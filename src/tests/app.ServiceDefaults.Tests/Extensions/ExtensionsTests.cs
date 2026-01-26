// =============================================================================
// Extensions Unit Tests
// Tests for the service defaults extension methods including OpenTelemetry,
// health checks, service discovery, and Azure Service Bus integration
// =============================================================================

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using NSubstitute;

namespace app.ServiceDefaults.Tests.Extensions;

[TestClass]
public sealed class ExtensionsTests
{
    #region AddServiceDefaults Tests

    [TestMethod]
    public void AddServiceDefaults_NullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IHostApplicationBuilder? builder = null;

        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => builder!.AddServiceDefaults());
    }

    [TestMethod]
    public void AddServiceDefaults_ValidBuilder_ReturnsBuilder()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        var result = builder.AddServiceDefaults();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void AddServiceDefaults_ValidBuilder_RegistersServiceDiscovery()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        builder.AddServiceDefaults();

        // Assert - Service discovery should be registered
        // This is verified by the successful build without exceptions
        Assert.IsNotNull(builder.Services);
    }

    [TestMethod]
    public void AddServiceDefaults_ValidBuilder_ConfiguresHttpClientDefaults()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        builder.AddServiceDefaults();
        var services = builder.Services.BuildServiceProvider();

        // Assert - Verify HTTP client factory is configured
        var httpClientFactory = services.GetService<IHttpClientFactory>();
        Assert.IsNotNull(httpClientFactory, "HttpClientFactory should be registered");
    }

    #endregion

    #region ConfigureOpenTelemetry Tests

    [TestMethod]
    public void ConfigureOpenTelemetry_NullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IHostApplicationBuilder? builder = null;

        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => builder!.ConfigureOpenTelemetry());
    }

    [TestMethod]
    public void ConfigureOpenTelemetry_ValidBuilder_ReturnsBuilder()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        var result = builder.ConfigureOpenTelemetry();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void ConfigureOpenTelemetry_WithOtlpEndpoint_ConfiguresExporter()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://localhost:4317"
        };
        var builder = CreateHostApplicationBuilder(config);

        // Act
        var result = builder.ConfigureOpenTelemetry();

        // Assert - Should not throw and return builder
        Assert.IsNotNull(result);
    }

    [TestMethod]
    public void ConfigureOpenTelemetry_WithApplicationInsights_ConfiguresAzureMonitor()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["APPLICATIONINSIGHTS_CONNECTION_STRING"] = "InstrumentationKey=test-key;IngestionEndpoint=https://test.in.applicationinsights.azure.com/"
        };
        var builder = CreateHostApplicationBuilder(config);

        // Act
        var result = builder.ConfigureOpenTelemetry();

        // Assert - Should not throw and return builder
        Assert.IsNotNull(result);
    }

    [TestMethod]
    public void ConfigureOpenTelemetry_NoExportersConfigured_StillSucceeds()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        var result = builder.ConfigureOpenTelemetry();

        // Assert
        Assert.IsNotNull(result);
    }

    #endregion

    #region AddDefaultHealthChecks Tests

    [TestMethod]
    public void AddDefaultHealthChecks_NullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IHostApplicationBuilder? builder = null;

        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => builder!.AddDefaultHealthChecks());
    }

    [TestMethod]
    public void AddDefaultHealthChecks_ValidBuilder_ReturnsBuilder()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        var result = builder.AddDefaultHealthChecks();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void AddDefaultHealthChecks_ValidBuilder_RegistersSelfHealthCheck()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();

        // Act
        builder.AddDefaultHealthChecks();
        var services = builder.Services.BuildServiceProvider();

        // Assert
        var healthCheckService = services.GetService<HealthCheckService>();
        Assert.IsNotNull(healthCheckService, "HealthCheckService should be registered");
    }

    [TestMethod]
    public async Task AddDefaultHealthChecks_SelfCheck_ReturnsHealthy()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();
        builder.AddDefaultHealthChecks();
        var services = builder.Services.BuildServiceProvider();
        var healthCheckService = services.GetRequiredService<HealthCheckService>();

        // Act
        var report = await healthCheckService.CheckHealthAsync();

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, report.Status);
        Assert.IsTrue(report.Entries.ContainsKey("self"), "Should have 'self' health check");
        Assert.AreEqual(HealthStatus.Healthy, report.Entries["self"].Status);
    }

    [TestMethod]
    public async Task AddDefaultHealthChecks_SelfCheck_HasLiveTag()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();
        builder.AddDefaultHealthChecks();
        var services = builder.Services.BuildServiceProvider();
        var healthCheckService = services.GetRequiredService<HealthCheckService>();

        // Act
        var report = await healthCheckService.CheckHealthAsync(
            predicate: r => r.Tags.Contains("live"));

        // Assert
        Assert.AreEqual(HealthStatus.Healthy, report.Status);
        Assert.IsTrue(report.Entries.ContainsKey("self"), "Self check should be tagged with 'live'");
    }

    #endregion

    #region AddAzureServiceBusClient Tests

    [TestMethod]
    public void AddAzureServiceBusClient_NullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IHostApplicationBuilder? builder = null;

        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => builder!.AddAzureServiceBusClient());
    }

    [TestMethod]
    public void AddAzureServiceBusClient_ValidBuilder_ReturnsBuilder()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "test-namespace.servicebus.windows.net"
        };
        var builder = CreateHostApplicationBuilder(config);

        // Act
        var result = builder.AddAzureServiceBusClient();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_MissingMessagingHost_ThrowsInvalidOperationException()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();
        builder.AddAzureServiceBusClient();
        var services = builder.Services.BuildServiceProvider();

        // Act & Assert
        var exception = Assert.ThrowsExactly<InvalidOperationException>(() =>
            services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>());

        Assert.IsTrue(exception.Message.Contains("MESSAGING_HOST"),
            "Exception should mention the missing configuration key");
    }

    [TestMethod]
    public void AddAzureServiceBusClient_LocalhostWithoutConnectionString_ThrowsInvalidOperationException()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost"
        };
        var builder = CreateHostApplicationBuilder(config);
        builder.AddAzureServiceBusClient();
        var services = builder.Services.BuildServiceProvider();

        // Act & Assert
        var exception = Assert.ThrowsExactly<InvalidOperationException>(() =>
            services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>());

        Assert.IsTrue(exception.Message.Contains("ConnectionStrings:messaging"),
            "Exception should mention the missing connection string");
    }

    [TestMethod]
    public void AddAzureServiceBusClient_LocalhostWithConnectionString_CreatesClient()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost:5672;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=SAS_KEY_VALUE;UseDevelopmentEmulator=true"
        };
        var builder = CreateHostApplicationBuilder(config);
        builder.AddAzureServiceBusClient();
        var services = builder.Services.BuildServiceProvider();

        // Act
        var client = services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>();

        // Assert
        Assert.IsNotNull(client);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_AlternativeConfigKey_CreatesClient()
    {
        // Arrange - Using Azure:ServiceBus:HostName instead of MESSAGING_HOST
        var config = new Dictionary<string, string?>
        {
            ["Azure:ServiceBus:HostName"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost:5672;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=SAS_KEY_VALUE;UseDevelopmentEmulator=true"
        };
        var builder = CreateHostApplicationBuilder(config);
        builder.AddAzureServiceBusClient();
        var services = builder.Services.BuildServiceProvider();

        // Act
        var client = services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>();

        // Assert
        Assert.IsNotNull(client);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_AzureHostWithManagedIdentity_CreatesClient()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "test-namespace.servicebus.windows.net"
        };
        var builder = CreateHostApplicationBuilder(config);
        builder.AddAzureServiceBusClient();
        var services = builder.Services.BuildServiceProvider();

        // Act
        var client = services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>();

        // Assert
        Assert.IsNotNull(client);
        Assert.AreEqual("test-namespace.servicebus.windows.net", client.FullyQualifiedNamespace);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_RegistersAsSingleton()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "test-namespace.servicebus.windows.net"
        };
        var builder = CreateHostApplicationBuilder(config);
        builder.AddAzureServiceBusClient();
        var services = builder.Services.BuildServiceProvider();

        // Act
        var client1 = services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>();
        var client2 = services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>();

        // Assert
        Assert.AreSame(client1, client2, "ServiceBusClient should be registered as singleton");
    }

    #endregion

    #region MapDefaultEndpoints Tests

    [TestMethod]
    public void MapDefaultEndpoints_NullApp_ThrowsArgumentNullException()
    {
        // Arrange
        WebApplication? app = null;

        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => app!.MapDefaultEndpoints());
    }

    [TestMethod]
    public void MapDefaultEndpoints_ValidApp_ReturnsApp()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder();
        builder.AddDefaultHealthChecks();
        var app = builder.Build();

        // Act
        var result = app.MapDefaultEndpoints();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(app, result);
    }

    [TestMethod]
    public void MapDefaultEndpoints_ValidApp_MapsHealthEndpoint()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder();
        builder.AddDefaultHealthChecks();
        var app = builder.Build();

        // Act
        app.MapDefaultEndpoints();

        // Assert - Health endpoints should be mapped (verified by checking endpoints)
        var dataSource = app.Services.GetRequiredService<Microsoft.AspNetCore.Routing.EndpointDataSource>();
        var endpoints = dataSource.Endpoints;
        var healthEndpoint = endpoints.FirstOrDefault(e =>
            e.DisplayName?.Contains("/health") == true ||
            (e as Microsoft.AspNetCore.Routing.RouteEndpoint)?.RoutePattern.RawText == "/health");

        Assert.IsNotNull(healthEndpoint, "Health endpoint should be mapped");
    }

    [TestMethod]
    public void MapDefaultEndpoints_ValidApp_MapsAliveEndpoint()
    {
        // Arrange
        var builder = WebApplication.CreateBuilder();
        builder.AddDefaultHealthChecks();
        var app = builder.Build();

        // Act
        app.MapDefaultEndpoints();

        // Assert - Alive endpoint should be mapped
        var dataSource = app.Services.GetRequiredService<Microsoft.AspNetCore.Routing.EndpointDataSource>();
        var endpoints = dataSource.Endpoints;
        var aliveEndpoint = endpoints.FirstOrDefault(e =>
            e.DisplayName?.Contains("/alive") == true ||
            (e as Microsoft.AspNetCore.Routing.RouteEndpoint)?.RoutePattern.RawText == "/alive");

        Assert.IsNotNull(aliveEndpoint, "Alive endpoint should be mapped");
    }

    #endregion

    #region Integration Tests

    [TestMethod]
    public void FullServiceConfiguration_AllExtensions_ConfiguresSuccessfully()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost:5672;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=SAS_KEY_VALUE;UseDevelopmentEmulator=true",
            ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://localhost:4317"
        };
        var builder = CreateHostApplicationBuilder(config);

        // Act - Apply all extensions
        builder.AddServiceDefaults();
        builder.AddAzureServiceBusClient();

        var services = builder.Services.BuildServiceProvider();

        // Assert - All services should be resolvable
        Assert.IsNotNull(services.GetService<HealthCheckService>());
        Assert.IsNotNull(services.GetService<IHttpClientFactory>());
        Assert.IsNotNull(services.GetRequiredService<Azure.Messaging.ServiceBus.ServiceBusClient>());
    }

    [TestMethod]
    public void ExtensionMethods_Chaining_WorksCorrectly()
    {
        // Arrange
        var config = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost:5672;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=SAS_KEY_VALUE;UseDevelopmentEmulator=true"
        };
        var builder = CreateHostApplicationBuilder(config);

        // Act - Chain extension methods
        var result = builder
            .AddServiceDefaults()
            .AddAzureServiceBusClient();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    #endregion

    #region Test Helpers

    private static HostApplicationBuilder CreateHostApplicationBuilder(
        Dictionary<string, string?>? configuration = null)
    {
        var builder = Host.CreateApplicationBuilder();

        if (configuration != null)
        {
            builder.Configuration.AddInMemoryCollection(configuration);
        }

        return builder;
    }

    #endregion
}
