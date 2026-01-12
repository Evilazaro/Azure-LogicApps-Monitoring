// =============================================================================
// Unit Tests for OrdersMessageHandler
// Tests messaging layer for Azure Service Bus order publishing
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Handlers;
using eShop.Orders.API.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

namespace eShop.Orders.API.Tests.Handlers;

/// <summary>
/// Unit tests for the <see cref="OrdersMessageHandler"/> class.
/// Tests cover message sending, batch operations, error handling, and distributed tracing.
/// </summary>
[TestClass]
public sealed class OrdersMessageHandlerTests
{
    private Mock<ILogger<OrdersMessageHandler>> _loggerMock = null!;
    private Mock<ServiceBusClient> _serviceBusClientMock = null!;
    private Mock<IConfiguration> _configurationMock = null!;
    private ActivitySource _activitySource = null!;
    private OrdersMessageHandler _handler = null!;

    private const string TestTopicName = "test-orders-topic";

    [TestInitialize]
    public void TestInitialize()
    {
        _loggerMock = new Mock<ILogger<OrdersMessageHandler>>();
        _serviceBusClientMock = new Mock<ServiceBusClient>();
        _configurationMock = new Mock<IConfiguration>();
        _activitySource = new ActivitySource("TestActivitySource");

        // Setup default configuration
        _configurationMock
            .Setup(c => c["Azure:ServiceBus:TopicName"])
            .Returns(TestTopicName);
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _activitySource?.Dispose();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_WithValidParameters_CreatesInstance()
    {
        // Act
        var handler = new OrdersMessageHandler(
            _loggerMock.Object,
            _serviceBusClientMock.Object,
            _configurationMock.Object,
            _activitySource);

        // Assert
        Assert.IsNotNull(handler);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Act
        _ = new OrdersMessageHandler(
            null!,
            _serviceBusClientMock.Object,
            _configurationMock.Object,
            _activitySource);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullServiceBusClient_ThrowsArgumentNullException()
    {
        // Act
        _ = new OrdersMessageHandler(
            _loggerMock.Object,
            null!,
            _configurationMock.Object,
            _activitySource);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullConfiguration_ThrowsArgumentNullException()
    {
        // Act
        _ = new OrdersMessageHandler(
            _loggerMock.Object,
            _serviceBusClientMock.Object,
            null!,
            _activitySource);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullActivitySource_ThrowsArgumentNullException()
    {
        // Act
        _ = new OrdersMessageHandler(
            _loggerMock.Object,
            _serviceBusClientMock.Object,
            _configurationMock.Object,
            null!);
    }

    [TestMethod]
    public void Constructor_WithEmptyTopicName_UsesDefaultTopicName()
    {
        // Arrange
        _configurationMock
            .Setup(c => c["Azure:ServiceBus:TopicName"])
            .Returns(string.Empty);

        var senderMock = new Mock<ServiceBusSender>();
        _serviceBusClientMock
            .Setup(c => c.CreateSender("ordersplaced"))
            .Returns(senderMock.Object);

        // Act
        var handler = new OrdersMessageHandler(
            _loggerMock.Object,
            _serviceBusClientMock.Object,
            _configurationMock.Object,
            _activitySource);

        // Assert
        Assert.IsNotNull(handler);
    }

    [TestMethod]
    public void Constructor_WithNullTopicName_UsesDefaultTopicName()
    {
        // Arrange
        _configurationMock
            .Setup(c => c["Azure:ServiceBus:TopicName"])
            .Returns((string?)null);

        // Act
        var handler = new OrdersMessageHandler(
            _loggerMock.Object,
            _serviceBusClientMock.Object,
            _configurationMock.Object,
            _activitySource);

        // Assert
        Assert.IsNotNull(handler);
    }

    #endregion

    #region SendOrderMessageAsync Tests

    [TestMethod]
    public async Task SendOrderMessageAsync_WithValidOrder_SendsMessageSuccessfully()
    {
        // Arrange
        var order = CreateTestOrder();
        var senderMock = new Mock<ServiceBusSender>();

        senderMock
            .Setup(s => s.SendMessageAsync(It.IsAny<ServiceBusMessage>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        senderMock.Verify(
            s => s.SendMessageAsync(
                It.Is<ServiceBusMessage>(m =>
                    m.MessageId == order.Id &&
                    m.Subject == "OrderPlaced" &&
                    m.ContentType == "application/json"),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public async Task SendOrderMessageAsync_WithNullOrder_ThrowsArgumentNullException()
    {
        // Arrange
        _handler = CreateHandler();

        // Act
        await _handler.SendOrderMessageAsync(null!, CancellationToken.None);
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_WithTransientError_RetriesAndSucceeds()
    {
        // Arrange
        var order = CreateTestOrder();
        var senderMock = new Mock<ServiceBusSender>();
        var callCount = 0;

        senderMock
            .Setup(s => s.SendMessageAsync(It.IsAny<ServiceBusMessage>(), It.IsAny<CancellationToken>()))
            .Returns(() =>
            {
                callCount++;
                if (callCount < 2)
                {
                    throw new ServiceBusException("Transient error", ServiceBusFailureReason.ServiceBusy);
                }
                return Task.CompletedTask;
            });

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        Assert.AreEqual(2, callCount, "Should have retried once after transient error");
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_WithNonTransientError_ThrowsServiceBusException()
    {
        // Arrange
        var order = CreateTestOrder();
        var senderMock = new Mock<ServiceBusSender>();

        senderMock
            .Setup(s => s.SendMessageAsync(It.IsAny<ServiceBusMessage>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ServiceBusException("Non-transient error", ServiceBusFailureReason.MessagingEntityNotFound));

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<ServiceBusException>(
            () => _handler.SendOrderMessageAsync(order, CancellationToken.None));
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_LogsSuccessMessage()
    {
        // Arrange
        var order = CreateTestOrder();
        var senderMock = new Mock<ServiceBusSender>();

        senderMock
            .Setup(s => s.SendMessageAsync(It.IsAny<ServiceBusMessage>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Successfully sent order message")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region SendOrdersBatchMessageAsync Tests

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithValidOrders_SendsAllMessages()
    {
        // Arrange
        var orders = new List<Order>
        {
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2"),
            CreateTestOrder("order-3")
        };

        var senderMock = new Mock<ServiceBusSender>();

        senderMock
            .Setup(s => s.SendMessagesAsync(It.IsAny<IEnumerable<ServiceBusMessage>>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        senderMock.Verify(
            s => s.SendMessagesAsync(
                It.Is<IEnumerable<ServiceBusMessage>>(msgs => msgs.Count() == 3),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public async Task SendOrdersBatchMessageAsync_WithNullOrders_ThrowsArgumentNullException()
    {
        // Arrange
        _handler = CreateHandler();

        // Act
        await _handler.SendOrdersBatchMessageAsync(null!, CancellationToken.None);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithEmptyOrders_ReturnsEarlyWithWarning()
    {
        // Arrange
        var orders = new List<Order>();
        var senderMock = new Mock<ServiceBusSender>();

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        senderMock.Verify(
            s => s.SendMessagesAsync(It.IsAny<IEnumerable<ServiceBusMessage>>(), It.IsAny<CancellationToken>()),
            Times.Never);

        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Empty orders collection")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithServiceBusError_ThrowsServiceBusException()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        var senderMock = new Mock<ServiceBusSender>();

        senderMock
            .Setup(s => s.SendMessagesAsync(It.IsAny<IEnumerable<ServiceBusMessage>>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ServiceBusException("Batch send failed", ServiceBusFailureReason.QuotaExceeded));

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<ServiceBusException>(
            () => _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None));
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_SetsCorrectMessageProperties()
    {
        // Arrange
        var order = CreateTestOrder();
        var orders = new List<Order> { order };
        var senderMock = new Mock<ServiceBusSender>();
        IEnumerable<ServiceBusMessage>? capturedMessages = null;

        senderMock
            .Setup(s => s.SendMessagesAsync(It.IsAny<IEnumerable<ServiceBusMessage>>(), It.IsAny<CancellationToken>()))
            .Callback<IEnumerable<ServiceBusMessage>, CancellationToken>((msgs, _) => capturedMessages = msgs.ToList())
            .Returns(Task.CompletedTask);

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        _handler = CreateHandler();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        Assert.IsNotNull(capturedMessages);
        var message = capturedMessages.First();
        Assert.AreEqual(order.Id, message.MessageId);
        Assert.AreEqual("OrderPlaced", message.Subject);
        Assert.AreEqual("application/json", message.ContentType);
    }

    #endregion

    #region ListMessagesFromTopicAsync Tests

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task ListMessagesFromTopicAsync_WithNullSubscription_ThrowsArgumentException()
    {
        // Arrange
        _handler = CreateHandler();

        // Act
        await _handler.ListMessagesFromTopicAsync(null!);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task ListMessagesFromTopicAsync_WithEmptySubscription_ThrowsArgumentException()
    {
        // Arrange
        _handler = CreateHandler();

        // Act
        await _handler.ListMessagesFromTopicAsync(string.Empty);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task ListMessagesFromTopicAsync_WithWhitespaceSubscription_ThrowsArgumentException()
    {
        // Arrange
        _handler = CreateHandler();

        // Act
        await _handler.ListMessagesFromTopicAsync("   ");
    }

    #endregion

    #region ListMessagesAsync Tests

    [TestMethod]
    public async Task ListMessagesAsync_UsesDefaultSubscription()
    {
        // Arrange
        var receiverMock = new Mock<ServiceBusReceiver>();

        receiverMock
            .Setup(r => r.ReceiveMessagesAsync(
                It.IsAny<int>(),
                It.IsAny<TimeSpan>(),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<ServiceBusReceivedMessage>());

        _serviceBusClientMock
            .Setup(c => c.CreateReceiver(TestTopicName, "orderprocessingsub"))
            .Returns(receiverMock.Object);

        _handler = CreateHandler();

        // Act
        var result = await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        _serviceBusClientMock.Verify(
            c => c.CreateReceiver(TestTopicName, "orderprocessingsub"),
            Times.Once);
    }

    #endregion

    #region Interface Implementation Tests

    [TestMethod]
    public void OrdersMessageHandler_ImplementsIOrdersMessageHandler()
    {
        // Arrange & Act
        _handler = CreateHandler();

        // Assert
        Assert.IsInstanceOfType(_handler, typeof(IOrdersMessageHandler));
    }

    #endregion

    #region Distributed Tracing Tests

    [TestMethod]
    public async Task SendOrderMessageAsync_AddsTraceContextToMessage()
    {
        // Arrange
        var order = CreateTestOrder();
        var senderMock = new Mock<ServiceBusSender>();
        ServiceBusMessage? capturedMessage = null;

        senderMock
            .Setup(s => s.SendMessageAsync(It.IsAny<ServiceBusMessage>(), It.IsAny<CancellationToken>()))
            .Callback<ServiceBusMessage, CancellationToken>((msg, _) => capturedMessage = msg)
            .Returns(Task.CompletedTask);

        _serviceBusClientMock
            .Setup(c => c.CreateSender(TestTopicName))
            .Returns(senderMock.Object);

        // Add an ActivityListener to ensure activities are created
        using var activityListener = new ActivityListener
        {
            ShouldListenTo = _ => true,
            Sample = (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllData
        };
        ActivitySource.AddActivityListener(activityListener);

        _handler = CreateHandler();

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        Assert.IsNotNull(capturedMessage);
        // Trace context properties should be present
        Assert.IsTrue(capturedMessage.ApplicationProperties.ContainsKey("TraceId") ||
                     capturedMessage.ApplicationProperties.ContainsKey("traceparent"),
            "Message should contain trace context properties");
    }

    #endregion

    #region Helper Methods

    private OrdersMessageHandler CreateHandler()
    {
        return new OrdersMessageHandler(
            _loggerMock.Object,
            _serviceBusClientMock.Object,
            _configurationMock.Object,
            _activitySource);
    }

    private static Order CreateTestOrder(string? id = null)
    {
        return new Order
        {
            Id = id ?? $"ORD-{Guid.NewGuid():N}".Substring(0, 16).ToUpper(),
            CustomerId = $"CUST-{Guid.NewGuid():N}".Substring(0, 12).ToUpper(),
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Total = 99.99m,
            Products = new List<OrderProduct>
            {
                new OrderProduct
                {
                    Id = $"OP-{Guid.NewGuid():N}".Substring(0, 15).ToUpper(),
                    OrderId = id ?? "ORD-TEST123",
                    ProductId = "PROD-1001",
                    ProductDescription = "Test Product",
                    Quantity = 2,
                    Price = 49.99m
                }
            }
        };
    }

    #endregion
}