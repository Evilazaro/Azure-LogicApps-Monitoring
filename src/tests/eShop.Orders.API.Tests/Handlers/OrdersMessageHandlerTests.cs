

// Copyright (c) Evilazaro. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root for license information.

using app.ServiceDefaults.CommonTypes;
using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Handlers;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using System.Diagnostics;
using System.Text.Json;

namespace eShop.Orders.API.Tests.Handlers;

/// <summary>
/// Unit tests for <see cref="OrdersMessageHandler"/> class.
/// Verifies Service Bus message publishing behavior with distributed tracing support.
/// </summary>
[TestClass]
public sealed class OrdersMessageHandlerTests
{
    private ILogger<OrdersMessageHandler> _logger = null!;
    private ServiceBusClient _serviceBusClient = null!;
    private ServiceBusSender _serviceBusSender = null!;
    private ServiceBusReceiver _serviceBusReceiver = null!;
    private IConfiguration _configuration = null!;
    private ActivitySource _activitySource = null!;
    private OrdersMessageHandler _handler = null!;

    private const string TestTopicName = "test-orders-topic";
    private const string TestSubscriptionName = "orderprocessingsub";

    [TestInitialize]
    public void TestInitialize()
    {
        _logger = Substitute.For<ILogger<OrdersMessageHandler>>();
        _serviceBusClient = Substitute.For<ServiceBusClient>();
        _serviceBusSender = Substitute.For<ServiceBusSender>();
        _serviceBusReceiver = Substitute.For<ServiceBusReceiver>();
        _activitySource = new ActivitySource("Tests.OrdersMessageHandler");

        var configData = new Dictionary<string, string?>
        {
            ["Azure:ServiceBus:TopicName"] = TestTopicName
        };
        _configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(configData)
            .Build();

        _serviceBusClient.CreateSender(TestTopicName).Returns(_serviceBusSender);
        _serviceBusClient.CreateReceiver(TestTopicName, Arg.Any<string>()).Returns(_serviceBusReceiver);

        _handler = new OrdersMessageHandler(
            _logger,
            _serviceBusClient,
            _configuration,
            _activitySource);
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _activitySource.Dispose();
    }

    #region Constructor Tests

    /// <summary>
    /// Verifies that the constructor throws an <see cref="ArgumentNullException"/> when a null logger is provided.
    /// </summary>
    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrdersMessageHandler(
                null!,
                _serviceBusClient,
                _configuration,
                _activitySource));

        Assert.AreEqual("logger", exception.ParamName);
    }

    /// <summary>
    /// Verifies that the constructor throws an <see cref="ArgumentNullException"/> when a null Service Bus client is provided.
    /// </summary>
    [TestMethod]
    public void Constructor_NullServiceBusClient_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrdersMessageHandler(
                _logger,
                null!,
                _configuration,
                _activitySource));

        /// <summary>
        /// Verifies that the constructor throws an <see cref="ArgumentNullException"/> when a null configuration is provided.
        /// </summary>
        Assert.AreEqual("serviceBusClient", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullConfiguration_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrdersMessageHandler(
                _logger,
                _serviceBusClient,
                /// <summary>
                /// Verifies that the constructor throws an <see cref="ArgumentNullException"/> when a null activity source is provided.
                /// </summary>
                null!,
                _activitySource));

        Assert.AreEqual("configuration", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullActivitySource_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            /// <summary>
            /// Verifies that the constructor uses a default topic name when an empty topic name is configured.
            /// </summary>
            new OrdersMessageHandler(
                _logger,
                _serviceBusClient,
                _configuration,
                null!));

        Assert.AreEqual("activitySource", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_EmptyTopicName_UsesDefaultTopicName()
    {
        // Arrange
        var emptyConfig = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Azure:ServiceBus:TopicName"] = ""
            })
            .Build();

        // Act - Should not throw, uses default topic name
        var handler = new OrdersMessageHandler(
            _logger,
            /// <summary>
            /// Verifies that a valid order is successfully sent as a Service Bus message with correct properties.
            /// </summary>
            _serviceBusClient,
            emptyConfig,
            _activitySource);

        // Assert - Handler created successfully (default topic name used internally)
        Assert.IsNotNull(handler);
    }

    #endregion

    #region SendOrderMessageAsync Tests

    [TestMethod]
    public async Task SendOrderMessageAsync_ValidOrder_SendsMessageSuccessfully()
    {
        // Arrange
        var order = CreateTestOrder();

        /// <summary>
        /// Verifies that sending a null order throws an <see cref="ArgumentNullException"/>.
        /// </summary>
        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        await _serviceBusSender.Received(1).SendMessageAsync(
            Arg.Is<ServiceBusMessage>(m =>
                m.MessageId == order.Id &&
                /// <summary>
                /// Verifies that Service Bus exceptions are propagated to the caller when sending fails.
                /// </summary>
                m.Subject == "OrderPlaced" &&
                m.ContentType == "application/json"),
            Arg.Any<CancellationToken>());
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_NullOrder_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _handler.SendOrderMessageAsync(null!, CancellationToken.None));

        Assert.AreEqual("order", exception.ParamName);
    }

    /// <summary>
    /// Verifies that transient errors trigger retry behavior before eventual success.
    /// </summary>
    [TestMethod]
    public async Task SendOrderMessageAsync_ServiceBusException_PropagatesException()
    {
        // Arrange
        var order = CreateTestOrder();
        var serviceBusException = new ServiceBusException("Connection failed", ServiceBusFailureReason.ServiceCommunicationProblem);

        _serviceBusSender
            .SendMessageAsync(Arg.Any<ServiceBusMessage>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(serviceBusException);

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ServiceBusException>(
            () => _handler.SendOrderMessageAsync(order, CancellationToken.None));

        Assert.AreEqual(ServiceBusFailureReason.ServiceCommunicationProblem, exception.Reason);
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_TransientError_RetriesBeforeSuccess()
    {
        // Arrange
        var order = CreateTestOrder();
        var callCount = 0;
        var transientException = new ServiceBusException(
            message: "Transient error",
            reason: ServiceBusFailureReason.ServiceBusy,
            innerException: null);

        _serviceBusSender
            /// <summary>
            /// Verifies that the order is correctly serialized to JSON in the Service Bus message body.
            /// </summary>
            .SendMessageAsync(Arg.Any<ServiceBusMessage>(), Arg.Any<CancellationToken>())
            .Returns(callInfo =>
            {
                callCount++;
                if (callCount < 2)
                {
                    throw transientException;
                }
                return Task.CompletedTask;
            });

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert - Should have retried at least once
        Assert.IsGreaterThanOrEqualTo(callCount, 2, $"Expected at least 2 calls, got {callCount}");
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_MessageContainsCorrectJsonSerialization()
    {
        // Arrange
        var order = CreateTestOrder();
        ServiceBusMessage? capturedMessage = null;

        _serviceBusSender
            .SendMessageAsync(Arg.Do<ServiceBusMessage>(m => capturedMessage = m), Arg.Any<CancellationToken>())
            /// <summary>
            /// Verifies that multiple orders are successfully sent as a batch of Service Bus messages.
            /// </summary>
            .Returns(Task.CompletedTask);

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        Assert.IsNotNull(capturedMessage);
        var deserializedOrder = JsonSerializer.Deserialize<Order>(
            capturedMessage.Body.ToString(),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        Assert.IsNotNull(deserializedOrder);
        Assert.AreEqual(order.Id, deserializedOrder.Id);
        Assert.AreEqual(order.CustomerId, deserializedOrder.CustomerId);
        Assert.AreEqual(order.Total, deserializedOrder.Total);
    }

    #endregion

    #region SendOrdersBatchMessageAsync Tests
    /// <summary>
    /// Verifies that sending a null orders collection throws an <see cref="ArgumentNullException"/>.
    /// </summary>

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_ValidOrders_SendsBatchSuccessfully()
    {
        // Arrange
        var orders = new List<Order>
        {
    /// <summary>
    /// Verifies that an empty orders collection returns without sending any messages.
    /// </summary>
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2"),
            CreateTestOrder("order-3")
        };

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        await _serviceBusSender.Received(1).SendMessagesAsync(
            Arg.Is<IEnumerable<ServiceBusMessage>>(messages => messages.Count() == 3),
            Arg.Any<CancellationToken>());
    }

    [TestMethod]
    /// <summary>
    /// Verifies that cancellation requests are honored and throw <see cref="OperationCanceledException"/>.
    /// </summary>
    public async Task SendOrdersBatchMessageAsync_NullOrders_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _handler.SendOrdersBatchMessageAsync(null!, CancellationToken.None));

        Assert.AreEqual("orders", exception.ParamName);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_EmptyCollection_ReturnsWithoutSending()
    {
        // Arrange
        var emptyOrders = Enumerable.Empty<Order>();
        /// <summary>
        /// Verifies that Service Bus exceptions are propagated to the caller when batch sending fails.
        /// </summary>

        // Act
        await _handler.SendOrdersBatchMessageAsync(emptyOrders, CancellationToken.None);

        // Assert - No messages should be sent
        await _serviceBusSender.DidNotReceive().SendMessagesAsync(
            Arg.Any<IEnumerable<ServiceBusMessage>>(),
            Arg.Any<CancellationToken>());
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_CancellationRequested_ThrowsOperationCanceledException()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        /// <summary>
        /// Verifies that a single order is correctly sent as a batch containing one message.
        /// </summary>
        _serviceBusSender
            .SendMessagesAsync(Arg.Any<IEnumerable<ServiceBusMessage>>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(new OperationCanceledException());

        // Act & Assert
        await Assert.ThrowsExactlyAsync<OperationCanceledException>(
            () => _handler.SendOrdersBatchMessageAsync(orders, cts.Token));
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_ServiceBusException_PropagatesException()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        var serviceBusException = new ServiceBusException("Quota exceeded", ServiceBusFailureReason.QuotaExceeded);

        _serviceBusSender
            .SendMessagesAsync(Arg.Any<IEnumerable<ServiceBusMessage>>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(serviceBusException);

        /// <summary>
        /// Verifies that an empty collection is returned when no messages are available.
        /// </summary>
        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ServiceBusException>(
            () => _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None));

        Assert.AreEqual(ServiceBusFailureReason.QuotaExceeded, exception.Reason);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_SingleOrder_SendsBatchWithOneMessage()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        IEnumerable<ServiceBusMessage>? capturedMessages = null;
        /// <summary>
        /// Verifies that cancellation requests are honored and throw <see cref="OperationCanceledException"/>.
        /// </summary>

        _serviceBusSender
            .SendMessagesAsync(Arg.Do<IEnumerable<ServiceBusMessage>>(m => capturedMessages = m.ToList()), Arg.Any<CancellationToken>())
            .Returns(Task.CompletedTask);

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        Assert.IsNotNull(capturedMessages);
        Assert.AreEqual(1, capturedMessages.Count());
    }

    #endregion

    #region ListMessagesAsync Tests
    /// <summary>
    /// Verifies that Service Bus exceptions are propagated to the caller when listing messages fails.
    /// </summary>

    [TestMethod]
    public async Task ListMessagesAsync_NoMessages_ReturnsEmptyCollection()
    {
        // Arrange
        _serviceBusReceiver
            .ReceiveMessagesAsync(Arg.Any<int>(), Arg.Any<TimeSpan>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<ServiceBusReceivedMessage>>([]));

        // Act
        var result = await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.IsFalse(result.Any());
    }

    [TestMethod]
    /// <summary>
    /// Creates a test order with optional custom order ID for use in unit tests.
    /// </summary>
    /// <param name="orderId">Optional order ID. If null, a new GUID-based ID is generated.</param>
    /// <returns>A new <see cref="Order"/> instance populated with test data.</returns>
    public async Task ListMessagesAsync_CancellationRequested_ThrowsOperationCanceledException()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _serviceBusReceiver
            .ReceiveMessagesAsync(Arg.Any<int>(), Arg.Any<TimeSpan>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(new OperationCanceledException());

        // Act & Assert
        await Assert.ThrowsExactlyAsync<OperationCanceledException>(
            () => _handler.ListMessagesAsync(cts.Token));
    }

    [TestMethod]
    public async Task ListMessagesAsync_ServiceBusException_PropagatesException()
    {
        // Arrange
        var serviceBusException = new ServiceBusException("Subscription not found", ServiceBusFailureReason.MessagingEntityNotFound);

        _serviceBusReceiver
            .ReceiveMessagesAsync(Arg.Any<int>(), Arg.Any<TimeSpan>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(serviceBusException);

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ServiceBusException>(
            () => _handler.ListMessagesAsync(CancellationToken.None));

        Assert.AreEqual(ServiceBusFailureReason.MessagingEntityNotFound, exception.Reason);
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string? orderId = null) => new()
    {
        Id = orderId ?? $"order-{Guid.NewGuid():N}",
        CustomerId = $"customer-{Guid.NewGuid():N}",
        Date = DateTime.UtcNow,
        DeliveryAddress = "123 Test Street, Test City, TC 12345",
        Total = 99.99m,
        Products =
        [
            new OrderProduct
            {
                Id = $"product-item-{Guid.NewGuid():N}",
                OrderId = orderId ?? "order-1",
                ProductId = $"product-{Guid.NewGuid():N}",
                ProductDescription = "Test Product",
                Quantity = 2,
                Price = 49.995m
            }
        ]
    };

    #endregion
}