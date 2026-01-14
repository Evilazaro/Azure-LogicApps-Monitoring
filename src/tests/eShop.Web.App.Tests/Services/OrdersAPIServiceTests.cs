// =============================================================================
// Unit Tests for OrdersAPIService
// Tests HTTP client layer for communicating with the Orders API
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Web.App.Components.Services;
using Microsoft.Extensions.Logging;
using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace eShop.Web.App.Tests.Services;

/// <summary>
/// Unit tests for the <see cref="OrdersAPIService"/> class.
/// Tests cover constructor validation, CRUD operations, error handling, and distributed tracing.
/// </summary>
[TestClass]
public sealed class OrdersAPIServiceTests
{
    private Mock<ILogger<OrdersAPIService>> _loggerMock = null!;
    private ActivitySource _activitySource = null!;
    private MockHttpMessageHandler _httpMessageHandler = null!;
    private HttpClient _httpClient = null!;
    private OrdersAPIService _service = null!;

    private const string BaseAddress = "https://test-api.example.com/";

    [TestInitialize]
    public void TestInitialize()
    {
        _loggerMock = new Mock<ILogger<OrdersAPIService>>();
        _activitySource = new ActivitySource("TestActivitySource");
        _httpMessageHandler = new MockHttpMessageHandler();
        _httpClient = new HttpClient(_httpMessageHandler)
        {
            BaseAddress = new Uri(BaseAddress)
        };
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _httpClient?.Dispose();
        _httpMessageHandler?.Dispose();
        _activitySource?.Dispose();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_WithValidParameters_CreatesInstance()
    {
        // Act
        var service = new OrdersAPIService(_httpClient, _loggerMock.Object, _activitySource);

        // Assert
        Assert.IsNotNull(service);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullHttpClient_ThrowsArgumentNullException()
    {
        // Act
        _ = new OrdersAPIService(null!, _loggerMock.Object, _activitySource);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Act
        _ = new OrdersAPIService(_httpClient, null!, _activitySource);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public void Constructor_WithNullActivitySource_ThrowsArgumentNullException()
    {
        // Act
        _ = new OrdersAPIService(_httpClient, _loggerMock.Object, null!);
    }

    #endregion

    #region PlaceOrderAsync Tests

    [TestMethod]
    public async Task PlaceOrderAsync_WithValidOrder_ReturnsCreatedOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        var expectedResponse = order;

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.Created,
            JsonSerializer.Serialize(expectedResponse));

        _service = CreateService();

        // Act
        var result = await _service.PlaceOrderAsync(order, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(order.Id, result.Id);
        Assert.AreEqual(order.CustomerId, result.CustomerId);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public async Task PlaceOrderAsync_WithNullOrder_ThrowsArgumentNullException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.PlaceOrderAsync(null!, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task PlaceOrderAsync_WithEmptyOrderId_ThrowsArgumentException()
    {
        // Arrange
        var order = new Order
        {
            Id = "",
            CustomerId = "customer-1",
            DeliveryAddress = "123 Test Street",
            Total = 99.99m,
            Products = [CreateTestOrderProduct()]
        };

        _service = CreateService();

        // Act
        await _service.PlaceOrderAsync(order, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task PlaceOrderAsync_WithWhitespaceOrderId_ThrowsArgumentException()
    {
        // Arrange
        var order = new Order
        {
            Id = "   ",
            CustomerId = "customer-1",
            DeliveryAddress = "123 Test Street",
            Total = 99.99m,
            Products = [CreateTestOrderProduct()]
        };

        _service = CreateService();

        // Act
        await _service.PlaceOrderAsync(order, CancellationToken.None);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithHttpError_ThrowsHttpRequestException()
    {
        // Arrange
        var order = CreateTestOrder();

        _httpMessageHandler.SetupResponse(HttpStatusCode.InternalServerError, "Server Error");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<HttpRequestException>(
            () => _service.PlaceOrderAsync(order, CancellationToken.None));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithBadRequest_ThrowsHttpRequestException()
    {
        // Arrange
        var order = CreateTestOrder();

        _httpMessageHandler.SetupResponse(HttpStatusCode.BadRequest, "Invalid request");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<HttpRequestException>(
            () => _service.PlaceOrderAsync(order, CancellationToken.None));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_LogsSuccessMessage()
    {
        // Arrange
        var order = CreateTestOrder();

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.Created,
            JsonSerializer.Serialize(order));

        _service = CreateService();

        // Act
        await _service.PlaceOrderAsync(order, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("placed successfully")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithNullResponseContent_ThrowsInvalidOperationException()
    {
        // Arrange
        var order = CreateTestOrder();

        _httpMessageHandler.SetupResponse(HttpStatusCode.Created, "null");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<InvalidOperationException>(
            () => _service.PlaceOrderAsync(order, CancellationToken.None));
    }

    #endregion

    #region PlaceOrdersBatchAsync Tests

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_WithValidOrders_ReturnsPlacedOrders()
    {
        // Arrange
        var orders = new List<Order>
        {
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2"),
            CreateTestOrder("order-3")
        };

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.OK,
            JsonSerializer.Serialize(orders));

        _service = CreateService();

        // Act
        var result = await _service.PlaceOrdersBatchAsync(orders, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(3, result.Count());
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public async Task PlaceOrdersBatchAsync_WithNullOrders_ThrowsArgumentNullException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.PlaceOrdersBatchAsync(null!, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task PlaceOrdersBatchAsync_WithEmptyOrders_ThrowsArgumentException()
    {
        // Arrange
        var orders = new List<Order>();

        _service = CreateService();

        // Act
        await _service.PlaceOrdersBatchAsync(orders, CancellationToken.None);
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_WithHttpError_ThrowsHttpRequestException()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };

        _httpMessageHandler.SetupResponse(HttpStatusCode.InternalServerError, "Server Error");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<HttpRequestException>(
            () => _service.PlaceOrdersBatchAsync(orders, CancellationToken.None));
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_WithNullResponse_ReturnsEmptyCollection()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };

        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "null");

        _service = CreateService();

        // Act
        var result = await _service.PlaceOrdersBatchAsync(orders, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_LogsSuccessMessage()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder(), CreateTestOrder("order-2") };

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.OK,
            JsonSerializer.Serialize(orders));

        _service = CreateService();

        // Act
        await _service.PlaceOrdersBatchAsync(orders, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("placed successfully")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region GetOrdersAsync Tests

    [TestMethod]
    public async Task GetOrdersAsync_ReturnsAllOrders()
    {
        // Arrange
        var orders = new List<Order>
        {
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2")
        };

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.OK,
            JsonSerializer.Serialize(orders));

        _service = CreateService();

        // Act
        var result = await _service.GetOrdersAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetOrdersAsync_WithEmptyResponse_ReturnsEmptyCollection()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "[]");

        _service = CreateService();

        // Act
        var result = await _service.GetOrdersAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task GetOrdersAsync_WithNullResponse_ReturnsEmptyCollection()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "null");

        _service = CreateService();

        // Act
        var result = await _service.GetOrdersAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task GetOrdersAsync_WithHttpError_ThrowsHttpRequestException()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.ServiceUnavailable, "Service unavailable");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<HttpRequestException>(
            () => _service.GetOrdersAsync(CancellationToken.None));
    }

    [TestMethod]
    public async Task GetOrdersAsync_LogsSuccessMessage()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.OK,
            JsonSerializer.Serialize(orders));

        _service = CreateService();

        // Act
        await _service.GetOrdersAsync(CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Successfully retrieved")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region GetOrderByIdAsync Tests

    [TestMethod]
    public async Task GetOrderByIdAsync_WithValidId_ReturnsOrder()
    {
        // Arrange
        var order = CreateTestOrder("order-123");

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.OK,
            JsonSerializer.Serialize(order));

        _service = CreateService();

        // Act
        var result = await _service.GetOrderByIdAsync("order-123", CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("order-123", result.Id);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task GetOrderByIdAsync_WithNullId_ThrowsArgumentException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.GetOrderByIdAsync(null!, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task GetOrderByIdAsync_WithEmptyId_ThrowsArgumentException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.GetOrderByIdAsync("", CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task GetOrderByIdAsync_WithWhitespaceId_ThrowsArgumentException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.GetOrderByIdAsync("   ", CancellationToken.None);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithNotFound_ReturnsNull()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.NotFound, "Not found");

        _service = CreateService();

        // Act
        var result = await _service.GetOrderByIdAsync("non-existent-order", CancellationToken.None);

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithNotFound_LogsWarning()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.NotFound, "Not found");

        _service = CreateService();

        // Act
        await _service.GetOrderByIdAsync("non-existent-order", CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("not found")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithServerError_ThrowsHttpRequestException()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.InternalServerError, "Server error");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<HttpRequestException>(
            () => _service.GetOrderByIdAsync("order-123", CancellationToken.None));
    }

    #endregion

    #region GetWeatherForecastAsync Tests

    [TestMethod]
    public async Task GetWeatherForecastAsync_ReturnsForecasts()
    {
        // Arrange
        var forecasts = new List<WeatherForecast>
        {
            new WeatherForecast { Date = DateOnly.FromDateTime(DateTime.UtcNow), TemperatureC = 25, Summary = "Warm" },
            new WeatherForecast { Date = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(1)), TemperatureC = 20, Summary = "Cool" }
        };

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.OK,
            JsonSerializer.Serialize(forecasts));

        _service = CreateService();

        // Act
        var result = await _service.GetWeatherForecastAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetWeatherForecastAsync_WithHttpError_ThrowsHttpRequestException()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.InternalServerError, "Error");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<HttpRequestException>(
            () => _service.GetWeatherForecastAsync(CancellationToken.None));
    }

    [TestMethod]
    public async Task GetWeatherForecastAsync_LogsSuccessMessage()
    {
        // Arrange
        var forecasts = new List<WeatherForecast>
        {
            new WeatherForecast { Date = DateOnly.FromDateTime(DateTime.UtcNow), TemperatureC = 25, Summary = "Warm" }
        };

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.OK,
            JsonSerializer.Serialize(forecasts));

        _service = CreateService();

        // Act
        await _service.GetWeatherForecastAsync(CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("weather forecasts")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.AtLeastOnce);
    }

    #endregion

    #region UpdateOrderAsync Tests

    [TestMethod]
    public async Task UpdateOrderAsync_WithValidOrder_ReturnsTrue()
    {
        // Arrange
        var order = CreateTestOrder("order-123");

        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "");

        _service = CreateService();

        // Act
        var result = await _service.UpdateOrderAsync("order-123", order, CancellationToken.None);

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_WithNotFound_ReturnsFalse()
    {
        // Arrange
        var order = CreateTestOrder("order-123");

        _httpMessageHandler.SetupResponse(HttpStatusCode.NotFound, "Not found");

        _service = CreateService();

        // Act
        var result = await _service.UpdateOrderAsync("order-123", order, CancellationToken.None);

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task UpdateOrderAsync_WithNullId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder();

        _service = CreateService();

        // Act
        await _service.UpdateOrderAsync(null!, order, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task UpdateOrderAsync_WithEmptyId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder();

        _service = CreateService();

        // Act
        await _service.UpdateOrderAsync("", order, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public async Task UpdateOrderAsync_WithNullOrder_ThrowsArgumentNullException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.UpdateOrderAsync("order-123", null!, CancellationToken.None);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_LogsSuccessMessage()
    {
        // Arrange
        var order = CreateTestOrder("order-123");

        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "");

        _service = CreateService();

        // Act
        await _service.UpdateOrderAsync("order-123", order, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Successfully updated")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_WithFailedUpdate_LogsWarning()
    {
        // Arrange
        var order = CreateTestOrder("order-123");

        _httpMessageHandler.SetupResponse(HttpStatusCode.BadRequest, "Invalid");

        _service = CreateService();

        // Act
        await _service.UpdateOrderAsync("order-123", order, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Failed to update")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region DeleteOrderAsync Tests

    [TestMethod]
    public async Task DeleteOrderAsync_WithValidId_ReturnsTrue()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.NoContent, "");

        _service = CreateService();

        // Act
        var result = await _service.DeleteOrderAsync("order-123", CancellationToken.None);

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithNotFound_ReturnsFalse()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.NotFound, "Not found");

        _service = CreateService();

        // Act
        var result = await _service.DeleteOrderAsync("order-123", CancellationToken.None);

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task DeleteOrderAsync_WithNullId_ThrowsArgumentException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.DeleteOrderAsync(null!, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task DeleteOrderAsync_WithEmptyId_ThrowsArgumentException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.DeleteOrderAsync("", CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task DeleteOrderAsync_WithWhitespaceId_ThrowsArgumentException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.DeleteOrderAsync("   ", CancellationToken.None);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_LogsSuccessMessage()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.NoContent, "");

        _service = CreateService();

        // Act
        await _service.DeleteOrderAsync("order-123", CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Successfully deleted")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithFailedDelete_LogsWarning()
    {
        // Arrange
        _httpMessageHandler.SetupResponse(HttpStatusCode.NotFound, "Not found");

        _service = CreateService();

        // Act
        await _service.DeleteOrderAsync("order-123", CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("Failed to delete")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region DeleteOrdersBatchAsync Tests

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_WithValidIds_ReturnsDeletedCount()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2", "order-3" };

        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "3");

        _service = CreateService();

        // Act
        var result = await _service.DeleteOrdersBatchAsync(orderIds, CancellationToken.None);

        // Assert
        Assert.AreEqual(3, result);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentNullException))]
    public async Task DeleteOrdersBatchAsync_WithNullIds_ThrowsArgumentNullException()
    {
        // Arrange
        _service = CreateService();

        // Act
        await _service.DeleteOrdersBatchAsync(null!, CancellationToken.None);
    }

    [TestMethod]
    [ExpectedException(typeof(ArgumentException))]
    public async Task DeleteOrdersBatchAsync_WithEmptyIds_ThrowsArgumentException()
    {
        // Arrange
        var orderIds = new List<string>();

        _service = CreateService();

        // Act
        await _service.DeleteOrdersBatchAsync(orderIds, CancellationToken.None);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_WithHttpError_ThrowsHttpRequestException()
    {
        // Arrange
        var orderIds = new List<string> { "order-1" };

        _httpMessageHandler.SetupResponse(HttpStatusCode.InternalServerError, "Error");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<HttpRequestException>(
            () => _service.DeleteOrdersBatchAsync(orderIds, CancellationToken.None));
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_LogsSuccessMessage()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2" };

        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "2");

        _service = CreateService();

        // Act
        await _service.DeleteOrdersBatchAsync(orderIds, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((o, t) => o.ToString()!.Contains("deleted successfully")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region Distributed Tracing Tests

    [TestMethod]
    public async Task PlaceOrderAsync_CreatesActivityWithCorrectTags()
    {
        // Arrange
        var order = CreateTestOrder("trace-test-order");
        Activity? capturedActivity = null;

        using var activityListener = new ActivityListener
        {
            ShouldListenTo = _ => true,
            Sample = (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllData,
            ActivityStarted = activity => capturedActivity = activity
        };
        ActivitySource.AddActivityListener(activityListener);

        _httpMessageHandler.SetupResponse(
            HttpStatusCode.Created,
            JsonSerializer.Serialize(order));

        _service = CreateService();

        // Act
        await _service.PlaceOrderAsync(order, CancellationToken.None);

        // Assert
        Assert.IsNotNull(capturedActivity);
        Assert.AreEqual("PlaceOrder", capturedActivity.OperationName);
    }

    [TestMethod]
    public async Task GetOrdersAsync_CreatesActivityWithCorrectKind()
    {
        // Arrange
        Activity? capturedActivity = null;

        using var activityListener = new ActivityListener
        {
            ShouldListenTo = _ => true,
            Sample = (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllData,
            ActivityStarted = activity => capturedActivity = activity
        };
        ActivitySource.AddActivityListener(activityListener);

        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "[]");

        _service = CreateService();

        // Act
        await _service.GetOrdersAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(capturedActivity);
        Assert.AreEqual(ActivityKind.Client, capturedActivity.Kind);
    }

    #endregion

    #region Error Handling Tests

    [TestMethod]
    public async Task PlaceOrderAsync_WithHttpError_LogsError()
    {
        // Arrange
        var order = CreateTestOrder();

        _httpMessageHandler.SetupResponse(HttpStatusCode.InternalServerError, "Server Error");

        _service = CreateService();

        // Act & Assert
        try
        {
            await _service.PlaceOrderAsync(order, CancellationToken.None);
        }
        catch (HttpRequestException)
        {
            // Expected
        }

        // Verify error logging
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Error,
                It.IsAny<EventId>(),
                It.IsAny<It.IsAnyType>(),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task GetOrdersAsync_WithUnexpectedException_LogsErrorAndRethrows()
    {
        // Arrange
        _httpMessageHandler.SetupException(new InvalidOperationException("Unexpected error"));

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<InvalidOperationException>(
            () => _service.GetOrdersAsync(CancellationToken.None));

        // Verify error logging
        _loggerMock.Verify(
            l => l.Log(
                LogLevel.Error,
                It.IsAny<EventId>(),
                It.IsAny<It.IsAnyType>(),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    #endregion

    #region Cancellation Tests

    [TestMethod]
    public async Task PlaceOrderAsync_WithCancellation_ThrowsOperationCanceledException()
    {
        // Arrange
        var order = CreateTestOrder();
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        _httpMessageHandler.SetupResponse(HttpStatusCode.OK, "{}");

        _service = CreateService();

        // Act & Assert
        await Assert.ThrowsExceptionAsync<TaskCanceledException>(
            () => _service.PlaceOrderAsync(order, cts.Token));
    }

    #endregion

    #region Helper Methods

    private OrdersAPIService CreateService()
    {
        return new OrdersAPIService(_httpClient, _loggerMock.Object, _activitySource);
    }

    private static Order CreateTestOrder(string? id = null)
    {
        var orderId = id ?? $"order-{Guid.NewGuid():N}"[..16];
        return new Order
        {
            Id = orderId,
            CustomerId = "customer-123",
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Total = 99.99m,
            Products = [CreateTestOrderProduct(orderId)]
        };
    }

    private static OrderProduct CreateTestOrderProduct(string? orderId = null)
    {
        return new OrderProduct
        {
            Id = $"product-item-{Guid.NewGuid():N}"[..20],
            OrderId = orderId ?? "order-test",
            ProductId = "product-1001",
            ProductDescription = "Test Product",
            Quantity = 2,
            Price = 49.99m
        };
    }

    #endregion

    #region MockHttpMessageHandler

    /// <summary>
    /// Mock HTTP message handler for testing HTTP client operations.
    /// </summary>
    private sealed class MockHttpMessageHandler : HttpMessageHandler
    {
        private HttpStatusCode _statusCode = HttpStatusCode.OK;
        private string _content = "{}";
        private Exception? _exception;

        public void SetupResponse(HttpStatusCode statusCode, string content)
        {
            _statusCode = statusCode;
            _content = content;
            _exception = null;
        }

        public void SetupException(Exception exception)
        {
            _exception = exception;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (_exception is not null)
            {
                throw _exception;
            }

            var response = new HttpResponseMessage(_statusCode)
            {
                Content = new StringContent(_content, System.Text.Encoding.UTF8, "application/json"),
                RequestMessage = request
            };

            return Task.FromResult(response);
        }
    }

    #endregion
}