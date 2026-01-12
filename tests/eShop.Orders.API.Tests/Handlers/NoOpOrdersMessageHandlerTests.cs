// =============================================================================
// Unit Tests for NoOpOrdersMessageHandler
// Tests the no-operation message handler for development environments
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Handlers;
using Microsoft.Extensions.Logging;
using Moq;

namespace eShop.Orders.API.Tests.Handlers;

/// <summary>
/// Unit tests for the <see cref="NoOpOrdersMessageHandler"/> class.
/// </summary>
public sealed class NoOpOrdersMessageHandlerTests
{
    private readonly Mock<ILogger<NoOpOrdersMessageHandler>> _loggerMock;
    private readonly NoOpOrdersMessageHandler _handler;

    public NoOpOrdersMessageHandlerTests()
    {
        _loggerMock = new Mock<ILogger<NoOpOrdersMessageHandler>>();
        _handler = new NoOpOrdersMessageHandler(_loggerMock.Object);
    }

    #region Constructor Tests

    [Fact]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Act & Assert
        var exception = Assert.Throws<ArgumentNullException>(() => 
            new NoOpOrdersMessageHandler(null!));
        
        Assert.Equal("logger", exception.ParamName);
    }

    [Fact]
    public void Constructor_WithValidLogger_CreatesInstance()
    {
        // Act
        var handler = new NoOpOrdersMessageHandler(_loggerMock.Object);

        // Assert
        Assert.NotNull(handler);
    }

    #endregion

    #region SendOrderMessageAsync Tests

    [Fact]
    public async Task SendOrderMessageAsync_WithValidOrder_CompletesSuccessfully()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert - No exception thrown, method completes
        VerifyLogInformationCalled();
    }

    [Fact]
    public async Task SendOrderMessageAsync_WithNullOrder_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsAsync<ArgumentNullException>(() => 
            _handler.SendOrderMessageAsync(null!, CancellationToken.None));
    }

    [Fact]
    public async Task SendOrderMessageAsync_LogsOrderId()
    {
        // Arrange
        var order = CreateTestOrder("TEST-ORDER-123");

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("TEST-ORDER-123")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [Fact]
    public async Task SendOrderMessageAsync_WithCancellationToken_CompletesSuccessfully()
    {
        // Arrange
        var order = CreateTestOrder();
        using var cts = new CancellationTokenSource();

        // Act
        await _handler.SendOrderMessageAsync(order, cts.Token);

        // Assert - Completes without throwing
        VerifyLogInformationCalled();
    }

    #endregion

    #region SendOrdersBatchMessageAsync Tests

    [Fact]
    public async Task SendOrdersBatchMessageAsync_WithValidOrders_CompletesSuccessfully()
    {
        // Arrange
        var orders = CreateTestOrders(3);

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        VerifyLogInformationCalled();
    }

    [Fact]
    public async Task SendOrdersBatchMessageAsync_WithNullOrders_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsAsync<ArgumentNullException>(() => 
            _handler.SendOrdersBatchMessageAsync(null!, CancellationToken.None));
    }

    [Fact]
    public async Task SendOrdersBatchMessageAsync_WithEmptyCollection_CompletesSuccessfully()
    {
        // Arrange
        var orders = Enumerable.Empty<Order>();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        VerifyLogInformationCalled();
    }

    [Fact]
    public async Task SendOrdersBatchMessageAsync_WithList_LogsCorrectCount()
    {
        // Arrange
        var orders = CreateTestOrders(5).ToList();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("5")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [Fact]
    public async Task SendOrdersBatchMessageAsync_WithEnumerable_LogsCorrectCount()
    {
        // Arrange - Use an enumerable that is not ICollection<Order>
        var orders = Enumerable.Range(1, 3).Select(i => CreateTestOrder($"ORDER-{i}"));

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("3")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [Fact]
    public async Task SendOrdersBatchMessageAsync_WithCancellationToken_CompletesSuccessfully()
    {
        // Arrange
        var orders = CreateTestOrders(2);
        using var cts = new CancellationTokenSource();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, cts.Token);

        // Assert
        VerifyLogInformationCalled();
    }

    #endregion

    #region ListMessagesAsync Tests

    [Fact]
    public async Task ListMessagesAsync_ReturnsEmptyCollection()
    {
        // Act
        var result = await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        Assert.NotNull(result);
        Assert.Empty(result);
    }

    [Fact]
    public async Task ListMessagesAsync_LogsInformation()
    {
        // Act
        await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        VerifyLogInformationCalled();
    }

    [Fact]
    public async Task ListMessagesAsync_WithCancellationToken_CompletesSuccessfully()
    {
        // Arrange
        using var cts = new CancellationTokenSource();

        // Act
        var result = await _handler.ListMessagesAsync(cts.Token);

        // Assert
        Assert.NotNull(result);
        Assert.Empty(result);
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string? orderId = null)
    {
        return new Order
        {
            Id = orderId ?? $"ORDER-{Guid.NewGuid():N}",
            CustomerId = $"CUST-{Guid.NewGuid():N}",
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Total = 99.99m,
            Products =
            [
                new OrderProduct
                {
                    Id = $"PROD-{Guid.NewGuid():N}",
                    OrderId = orderId ?? "ORDER-1",
                    ProductId = "SKU-001",
                    ProductDescription = "Test Product",
                    Quantity = 1,
                    Price = 99.99m
                }
            ]
        };
    }

    private static IEnumerable<Order> CreateTestOrders(int count)
    {
        for (int i = 0; i < count; i++)
        {
            yield return CreateTestOrder($"ORDER-{i + 1}");
        }
    }

    private void VerifyLogInformationCalled()
    {
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.IsAny<It.IsAnyType>(),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.AtLeastOnce);
    }

    #endregion
}