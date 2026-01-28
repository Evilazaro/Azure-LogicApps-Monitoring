// =============================================================================
// OrdersAPIService Unit Tests
// Comprehensive tests for the HTTP client service layer
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Web.App.Components.Services;
using Microsoft.Extensions.Logging;
using NSubstitute;
using RichardSzalay.MockHttp;
using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;

namespace eShop.Web.App.Tests.Services;

/// <summary>
/// Unit tests for <see cref="OrdersAPIService"/> covering HTTP client operations
/// for order management including CRUD operations, batch processing, and error handling.
/// </summary>
/// <remarks>
/// These tests use <see cref="MockHttpMessageHandler"/> to simulate HTTP responses
/// and <see cref="NSubstitute"/> for mocking the logger dependency.
/// </remarks>
[TestClass]
public sealed class OrdersAPIServiceTests
{
    private MockHttpMessageHandler _mockHttp = null!;
    private HttpClient _httpClient = null!;
    private ILogger<OrdersAPIService> _mockLogger = null!;
    private ActivitySource _activitySource = null!;
    private OrdersAPIService _sut = null!;

    private static readonly Uri BaseAddress = new("https://orders-api.test/");

    [TestInitialize]
    public void Setup()
    {
        _mockHttp = new MockHttpMessageHandler();
        _httpClient = _mockHttp.ToHttpClient();
        _httpClient.BaseAddress = BaseAddress;

        _mockLogger = Substitute.For<ILogger<OrdersAPIService>>();
        _activitySource = new ActivitySource("eShop.Web.App.Tests");

        _sut = new OrdersAPIService(_httpClient, _mockLogger, _activitySource);
    }

    [TestCleanup]
    public void Cleanup()
    {
        _httpClient?.Dispose();
        _mockHttp?.Dispose();
        _activitySource?.Dispose();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_NullHttpClient_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => new OrdersAPIService(null!, _mockLogger, _activitySource));

        Assert.AreEqual("httpClient", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => new OrdersAPIService(_httpClient, null!, _activitySource));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullActivitySource_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => new OrdersAPIService(_httpClient, _mockLogger, null!));

        Assert.AreEqual("activitySource", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_ValidParameters_CreatesInstance()
    {
        // Arrange & Act
        var service = new OrdersAPIService(_httpClient, _mockLogger, _activitySource);

        // Assert
        Assert.IsNotNull(service);
    }

    #endregion

    #region PlaceOrderAsync Tests

    [TestMethod]
    public async Task PlaceOrderAsync_NullOrder_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _sut.PlaceOrderAsync(null!));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_NullOrderId_ThrowsArgumentException()
    {
        // Arrange - Create an order with null ID to test validation
        var order = new Order
        {
            Id = null!, // Intentionally null to test validation
            CustomerId = "customer-001",
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Products =
            [
                new OrderProduct
                {
                    Id = "product-item-1",
                    OrderId = "test",
                    ProductId = "product-001",
                    ProductDescription = "Test Product",
                    Quantity = 2,
                    Price = 49.995m
                }
            ]
        };

        // Act & Assert - The service validates order.Id with string.IsNullOrWhiteSpace
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.PlaceOrderAsync(order));

        Assert.AreEqual("order", exception.ParamName);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder(id: "");

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.PlaceOrderAsync(order));

        Assert.AreEqual("order", exception.ParamName);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WhitespaceOrderId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder(id: "   ");

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.PlaceOrderAsync(order));

        Assert.AreEqual("order", exception.ParamName);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_ValidOrder_ReturnsCreatedOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.Created, JsonContent.Create(order));

        // Act
        var result = await _sut.PlaceOrderAsync(order);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(order.Id, result.Id);
        Assert.AreEqual(order.CustomerId, result.CustomerId);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_ApiReturnsServerError_ThrowsHttpRequestException()
    {
        // Arrange
        var order = CreateTestOrder();
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.InternalServerError);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<HttpRequestException>(
            () => _sut.PlaceOrderAsync(order));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_ApiReturnsBadRequest_ThrowsHttpRequestException()
    {
        // Arrange
        var order = CreateTestOrder();
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.BadRequest);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<HttpRequestException>(
            () => _sut.PlaceOrderAsync(order));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var order = CreateTestOrder();
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.Created, JsonContent.Create(order));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.PlaceOrderAsync(order, cts.Token));
    }

    /// <summary>
    /// Verifies that <see cref="OrdersAPIService.PlaceOrderAsync"/> throws an
    /// <see cref="InvalidOperationException"/> when the API returns a null response body.
    /// </summary>
    [TestMethod]
    public async Task PlaceOrderAsync_ApiReturnsNullBody_ThrowsInvalidOperationException()
    {
        // Arrange
        var order = CreateTestOrder();
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.Created, JsonContent.Create<Order?>(null));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<InvalidOperationException>(
            () => _sut.PlaceOrderAsync(order));
    }

    #endregion

    #region PlaceOrdersBatchAsync Tests

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_NullOrders_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _sut.PlaceOrdersBatchAsync(null!));
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_EmptyOrders_ThrowsArgumentException()
    {
        // Arrange
        var orders = Array.Empty<Order>();

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.PlaceOrdersBatchAsync(orders));

        Assert.AreEqual("orders", exception.ParamName);
        Assert.IsTrue(exception.Message.Contains("Orders collection cannot be empty"));
    }

    /// <summary>
    /// Verifies that <see cref="OrdersAPIService.PlaceOrdersBatchAsync"/> successfully
    /// submits multiple orders and returns the collection of created orders with correct IDs.
    /// </summary>
    [TestMethod]
    public async Task PlaceOrdersBatchAsync_ValidOrders_ReturnsPlacedOrders()
    {
        // Arrange
        var orders = new List<Order>
        {
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2"),
            CreateTestOrder("order-3")
        };

        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch")
            .Respond(HttpStatusCode.Created, JsonContent.Create(orders));

        // Act
        var result = await _sut.PlaceOrdersBatchAsync(orders);

        // Assert
        var resultList = result.ToList();
        Assert.AreEqual(3, resultList.Count);
        Assert.AreEqual("order-1", resultList[0].Id);
        Assert.AreEqual("order-2", resultList[1].Id);
        Assert.AreEqual("order-3", resultList[2].Id);
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_SingleOrder_ReturnsPlacedOrder()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder("single-order") };

        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch")
            .Respond(HttpStatusCode.Created, JsonContent.Create(orders));

        // Act
        var result = await _sut.PlaceOrdersBatchAsync(orders);

        // Assert
        Assert.AreEqual(1, result.Count());
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_ApiReturnsServerError_ThrowsHttpRequestException()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch")
            .Respond(HttpStatusCode.InternalServerError);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<HttpRequestException>(
            () => _sut.PlaceOrdersBatchAsync(orders));
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_ApiReturnsNull_ReturnsEmptyCollection()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch")
            .Respond(HttpStatusCode.OK, JsonContent.Create<IEnumerable<Order>?>(null));

        // Act
        var result = await _sut.PlaceOrdersBatchAsync(orders);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch")
            .Respond(HttpStatusCode.Created, JsonContent.Create(orders));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.PlaceOrdersBatchAsync(orders, cts.Token));
    }

    #endregion

    #region GetOrdersAsync Tests

    [TestMethod]
    public async Task GetOrdersAsync_ApiReturnsOrders_ReturnsOrderCollection()
    {
        // Arrange
        var orders = new List<Order>
        {
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2")
        };

        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.OK, JsonContent.Create(orders));

        // Act
        var result = await _sut.GetOrdersAsync();

        // Assert
        var resultList = result.ToList();
        Assert.AreEqual(2, resultList.Count);
    }

    [TestMethod]
    public async Task GetOrdersAsync_ApiReturnsEmptyArray_ReturnsEmptyCollection()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.OK, JsonContent.Create(Array.Empty<Order>()));

        // Act
        var result = await _sut.GetOrdersAsync();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task GetOrdersAsync_ApiReturnsNull_ReturnsEmptyCollection()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.OK, JsonContent.Create<IEnumerable<Order>?>(null));

        // Act
        var result = await _sut.GetOrdersAsync();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task GetOrdersAsync_ApiReturnsServerError_ThrowsHttpRequestException()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.InternalServerError);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<HttpRequestException>(
            () => _sut.GetOrdersAsync());
    }

    [TestMethod]
    public async Task GetOrdersAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders")
            .Respond(HttpStatusCode.OK, JsonContent.Create(Array.Empty<Order>()));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.GetOrdersAsync(cts.Token));
    }

    #endregion

    #region GetOrderByIdAsync Tests

    [TestMethod]
    public async Task GetOrderByIdAsync_NullOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.GetOrderByIdAsync(null!));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.GetOrderByIdAsync(""));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WhitespaceOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.GetOrderByIdAsync("   "));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_ExistingOrder_ReturnsOrder()
    {
        // Arrange
        var order = CreateTestOrder("test-order-123");
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders/test-order-123")
            .Respond(HttpStatusCode.OK, JsonContent.Create(order));

        // Act
        var result = await _sut.GetOrderByIdAsync("test-order-123");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("test-order-123", result.Id);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_NonExistentOrder_ReturnsNull()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders/non-existent")
            .Respond(HttpStatusCode.NotFound);

        // Act
        var result = await _sut.GetOrderByIdAsync("non-existent");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_ApiReturnsServerError_ThrowsHttpRequestException()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.InternalServerError);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<HttpRequestException>(
            () => _sut.GetOrderByIdAsync("test-order"));
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.OK, JsonContent.Create(CreateTestOrder()));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.GetOrderByIdAsync("test-order", cts.Token));
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_OrderIdWithSpecialCharacters_SanitizesForLogging()
    {
        // Arrange - Order ID with newline characters that could be used for log forging
        var orderId = "order\r\n123";
        var order = CreateTestOrder(orderId);
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}api/orders/{orderId}")
            .Respond(HttpStatusCode.OK, JsonContent.Create(order));

        // Act
        var result = await _sut.GetOrderByIdAsync(orderId);

        // Assert - Should complete without throwing
        Assert.IsNotNull(result);
    }

    #endregion

    #region GetWeatherForecastAsync Tests

    [TestMethod]
    public async Task GetWeatherForecastAsync_ApiReturnsForecasts_ReturnsForecastCollection()
    {
        // Arrange
        var forecasts = new List<WeatherForecast>
        {
            new() { Date = DateOnly.FromDateTime(DateTime.Today), TemperatureC = 20, Summary = "Sunny" },
            new() { Date = DateOnly.FromDateTime(DateTime.Today.AddDays(1)), TemperatureC = 22, Summary = "Cloudy" }
        };

        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}WeatherForecast")
            .Respond(HttpStatusCode.OK, JsonContent.Create(forecasts));

        // Act
        var result = await _sut.GetWeatherForecastAsync();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetWeatherForecastAsync_ApiReturnsNull_ReturnsNull()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}WeatherForecast")
            .Respond(HttpStatusCode.OK, JsonContent.Create<IEnumerable<WeatherForecast>?>(null));

        // Act
        var result = await _sut.GetWeatherForecastAsync();

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetWeatherForecastAsync_ApiReturnsServerError_ThrowsHttpRequestException()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}WeatherForecast")
            .Respond(HttpStatusCode.InternalServerError);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<HttpRequestException>(
            () => _sut.GetWeatherForecastAsync());
    }

    [TestMethod]
    public async Task GetWeatherForecastAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Get, $"{BaseAddress}WeatherForecast")
            .Respond(HttpStatusCode.OK, JsonContent.Create(Array.Empty<WeatherForecast>()));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.GetWeatherForecastAsync(cts.Token));
    }

    #endregion

    #region UpdateOrderAsync Tests

    [TestMethod]
    public async Task UpdateOrderAsync_NullId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.UpdateOrderAsync(null!, order));

        Assert.AreEqual("id", exception.ParamName);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_EmptyId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.UpdateOrderAsync("", order));

        Assert.AreEqual("id", exception.ParamName);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_WhitespaceId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.UpdateOrderAsync("   ", order));

        Assert.AreEqual("id", exception.ParamName);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_NullOrder_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _sut.UpdateOrderAsync("test-id", null!));
    }

    [TestMethod]
    public async Task UpdateOrderAsync_SuccessfulUpdate_ReturnsTrue()
    {
        // Arrange
        var order = CreateTestOrder("test-order");
        _mockHttp.When(HttpMethod.Put, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.OK);

        // Act
        var result = await _sut.UpdateOrderAsync("test-order", order);

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_ApiReturnsNotFound_ReturnsFalse()
    {
        // Arrange
        var order = CreateTestOrder("test-order");
        _mockHttp.When(HttpMethod.Put, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.NotFound);

        // Act
        var result = await _sut.UpdateOrderAsync("test-order", order);

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_ApiReturnsBadRequest_ReturnsFalse()
    {
        // Arrange
        var order = CreateTestOrder("test-order");
        _mockHttp.When(HttpMethod.Put, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.BadRequest);

        // Act
        var result = await _sut.UpdateOrderAsync("test-order", order);

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public async Task UpdateOrderAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var order = CreateTestOrder("test-order");
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Put, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.OK);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.UpdateOrderAsync("test-order", order, cts.Token));
    }

    #endregion

    #region DeleteOrderAsync Tests

    [TestMethod]
    public async Task DeleteOrderAsync_NullId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.DeleteOrderAsync(null!));

        Assert.AreEqual("id", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_EmptyId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.DeleteOrderAsync(""));

        Assert.AreEqual("id", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WhitespaceId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.DeleteOrderAsync("   "));

        Assert.AreEqual("id", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_SuccessfulDelete_ReturnsTrue()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Delete, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.NoContent);

        // Act
        var result = await _sut.DeleteOrderAsync("test-order");

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_ApiReturnsNotFound_ReturnsFalse()
    {
        // Arrange
        _mockHttp.When(HttpMethod.Delete, $"{BaseAddress}api/orders/non-existent")
            .Respond(HttpStatusCode.NotFound);

        // Act
        var result = await _sut.DeleteOrderAsync("non-existent");

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Delete, $"{BaseAddress}api/orders/test-order")
            .Respond(HttpStatusCode.NoContent);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.DeleteOrderAsync("test-order", cts.Token));
    }

    #endregion

    #region DeleteOrdersBatchAsync Tests

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_NullOrderIds_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _sut.DeleteOrdersBatchAsync(null!));
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_EmptyOrderIds_ThrowsArgumentException()
    {
        // Arrange
        var orderIds = Array.Empty<string>();

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _sut.DeleteOrdersBatchAsync(orderIds));

        Assert.AreEqual("orderIds", exception.ParamName);
        Assert.IsTrue(exception.Message.Contains("Order IDs collection cannot be empty"));
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_ValidOrderIds_ReturnsDeletedCount()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2", "order-3" };
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch/delete")
            .Respond(HttpStatusCode.OK, JsonContent.Create(3));

        // Act
        var result = await _sut.DeleteOrdersBatchAsync(orderIds);

        // Assert
        Assert.AreEqual(3, result);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_SingleOrderId_ReturnsDeletedCount()
    {
        // Arrange
        var orderIds = new List<string> { "order-1" };
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch/delete")
            .Respond(HttpStatusCode.OK, JsonContent.Create(1));

        // Act
        var result = await _sut.DeleteOrdersBatchAsync(orderIds);

        // Assert
        Assert.AreEqual(1, result);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_PartialDeletion_ReturnsActualDeletedCount()
    {
        // Arrange - 3 IDs requested but only 2 deleted (one might not exist)
        var orderIds = new List<string> { "order-1", "order-2", "non-existent" };
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch/delete")
            .Respond(HttpStatusCode.OK, JsonContent.Create(2));

        // Act
        var result = await _sut.DeleteOrdersBatchAsync(orderIds);

        // Assert
        Assert.AreEqual(2, result);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_ApiReturnsServerError_ThrowsHttpRequestException()
    {
        // Arrange
        var orderIds = new List<string> { "order-1" };
        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch/delete")
            .Respond(HttpStatusCode.InternalServerError);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<HttpRequestException>(
            () => _sut.DeleteOrdersBatchAsync(orderIds));
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_CancellationRequested_ThrowsTaskCanceledException()
    {
        // Arrange
        var orderIds = new List<string> { "order-1" };
        var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _mockHttp.When(HttpMethod.Post, $"{BaseAddress}api/orders/batch/delete")
            .Respond(HttpStatusCode.OK, JsonContent.Create(1));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<TaskCanceledException>(
            () => _sut.DeleteOrdersBatchAsync(orderIds, cts.Token));
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string? id = null)
    {
        var orderId = id ?? $"order-{Guid.NewGuid():N}";
        return new Order
        {
            Id = orderId,
            CustomerId = "customer-001",
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Date = DateTime.UtcNow,
            Total = 99.99m,
            Products =
            [
                new OrderProduct
                {
                    Id = $"product-item-{Guid.NewGuid():N}",
                    OrderId = orderId,
                    ProductId = "product-001",
                    ProductDescription = "Test Product",
                    Quantity = 2,
                    Price = 49.995m
                }
            ]
        };
    }

    #endregion
}
