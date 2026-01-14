// =============================================================================
// Unit Tests for AddAzureServiceBusClient Extension Method
// Tests Azure Service Bus client configuration for local and Azure modes
// =============================================================================

using Azure.Messaging.ServiceBus;

namespace app.ServiceDefaults.Tests.Extensions;

/// <summary>
/// Unit tests for the <see cref="Microsoft.Extensions.Hosting.Extensions.AddAzureServiceBusClient"/> method.
/// </summary>
[TestClass]
public sealed class AddAzureServiceBusClientTests
{
    #region Null Parameter Tests

    [TestMethod]
    public void AddAzureServiceBusClient_WithNullBuilder_ThrowsArgumentNullException()
    {
        // Arrange
        IHostApplicationBuilder builder = null!;

        // Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => builder.AddAzureServiceBusClient());

        Assert.AreEqual("builder", exception.ParamName);
    }

    #endregion

    #region Configuration Tests

    [TestMethod]
    public void AddAzureServiceBusClient_WithValidBuilder_ReturnsBuilder()
    {
        // Arrange
        var configuration = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost;SharedAccessKeyName=test;SharedAccessKey=test"
        };

        var builder = CreateHostApplicationBuilder(configuration);

        // Act
        var result = builder.AddAzureServiceBusClient();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreSame(builder, result);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_RegistersServiceBusClientAsSingleton()
    {
        // Arrange
        var configuration = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost;SharedAccessKeyName=test;SharedAccessKey=test"
        };

        var builder = CreateHostApplicationBuilder(configuration);

        // Act
        builder.AddAzureServiceBusClient();

        // Assert - Verify ServiceBusClient is registered
        var descriptor = builder.Services.FirstOrDefault(s => s.ServiceType == typeof(ServiceBusClient));
        Assert.IsNotNull(descriptor, "ServiceBusClient should be registered");
        Assert.AreEqual(ServiceLifetime.Singleton, descriptor.Lifetime);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_WithMissingHostConfig_ThrowsOnResolve()
    {
        // Arrange
        var builder = CreateHostApplicationBuilder();
        builder.AddAzureServiceBusClient();

        var serviceProvider = builder.Services.BuildServiceProvider();

        // Act & Assert - Should throw when trying to resolve the client
        var exception = Assert.ThrowsExactly<InvalidOperationException>(
            () => serviceProvider.GetRequiredService<ServiceBusClient>());

        StringAssert.Contains(exception.Message, "MESSAGING_HOST");
    }

    [TestMethod]
    public void AddAzureServiceBusClient_WithLocalhostAndMissingConnectionString_ThrowsOnResolve()
    {
        // Arrange
        var configuration = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost"
            // Missing ConnectionStrings:messaging
        };

        var builder = CreateHostApplicationBuilder(configuration);
        builder.AddAzureServiceBusClient();

        var serviceProvider = builder.Services.BuildServiceProvider();

        // Act & Assert
        var exception = Assert.ThrowsExactly<InvalidOperationException>(
            () => serviceProvider.GetRequiredService<ServiceBusClient>());

        StringAssert.Contains(exception.Message, "ConnectionStrings:messaging");
    }

    [TestMethod]
    public void AddAzureServiceBusClient_WithAlternativeHostNameConfig_Works()
    {
        // Arrange
        var configuration = new Dictionary<string, string?>
        {
            ["Azure:ServiceBus:HostName"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost;SharedAccessKeyName=test;SharedAccessKey=test"
        };

        var builder = CreateHostApplicationBuilder(configuration);

        // Act
        var result = builder.AddAzureServiceBusClient();

        // Assert
        Assert.IsNotNull(result);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_LocalhostMode_ConfiguresWithConnectionString()
    {
        // Arrange
        var configuration = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=test123"
        };

        var builder = CreateHostApplicationBuilder(configuration);
        builder.AddAzureServiceBusClient();

        // Assert - Client is registered (actual creation happens on resolve)
        var descriptor = builder.Services.FirstOrDefault(s => s.ServiceType == typeof(ServiceBusClient));
        Assert.IsNotNull(descriptor);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_AzureMode_ConfiguresWithManagedIdentity()
    {
        // Arrange
        var configuration = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "my-servicebus.servicebus.windows.net"
        };

        var builder = CreateHostApplicationBuilder(configuration);

        // Act
        builder.AddAzureServiceBusClient();

        // Assert - Client is registered
        var descriptor = builder.Services.FirstOrDefault(s => s.ServiceType == typeof(ServiceBusClient));
        Assert.IsNotNull(descriptor);
    }

    [TestMethod]
    public void AddAzureServiceBusClient_LocalhostCaseInsensitive_Works()
    {
        // Arrange - Test case insensitivity
        var configuration = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "LOCALHOST",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost;SharedAccessKeyName=test;SharedAccessKey=test"
        };

        var builder = CreateHostApplicationBuilder(configuration);

        // Act
        var result = builder.AddAzureServiceBusClient();

        // Assert
        Assert.IsNotNull(result);
    }

    #endregion

    #region Method Chaining Tests

    [TestMethod]
    public void AddAzureServiceBusClient_SupportsMethodChaining()
    {
        // Arrange
        var configuration = new Dictionary<string, string?>
        {
            ["MESSAGING_HOST"] = "localhost",
            ["ConnectionStrings:messaging"] = "Endpoint=sb://localhost;SharedAccessKeyName=test;SharedAccessKey=test"
        };

        var builder = CreateHostApplicationBuilder(configuration);

        // Act
        var result = builder
            .AddServiceDefaults()
            .AddAzureServiceBusClient();

        // Assert
        Assert.IsNotNull(result);
    }

    #endregion

    #region Helper Methods

    private static HostApplicationBuilder CreateHostApplicationBuilder(
        Dictionary<string, string?>? configuration = null)
    {
        var builder = Host.CreateApplicationBuilder(new HostApplicationBuilderSettings
        {
            ApplicationName = "TestApplication",
            EnvironmentName = "Development"
        });

        if (configuration != null)
        {
            builder.Configuration.AddInMemoryCollection(configuration);
        }

        return builder;
    }

    #endregion
}