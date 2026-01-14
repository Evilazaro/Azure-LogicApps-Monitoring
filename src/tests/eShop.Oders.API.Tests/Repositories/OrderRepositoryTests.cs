// =============================================================================
// Unit Tests for OrderRepository
// Tests Entity Framework Core-based persistence operations for order data
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Data;
using eShop.Orders.API.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace eShop.Orders.API.Tests.Repositories;

[TestClass]
public sealed class OrderRepositoryTests : IDisposable
{
    private OrderDbContext _dbContext = null!;
    private Mock<ILogger<OrderRepository>> _loggerMock = null!;
    private OrderRepository _repository = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _dbContext = new OrderDbContext(options);
        _loggerMock = new Mock<ILogger<OrderRepository>>();
        _repository = new OrderRepository(_loggerMock.Object, _dbContext);
    }

    [TestCleanup]
    public void TestCleanup()
    {
        Dispose();
    }

    public void Dispose()
    {
        _dbContext?.Dispose();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => new OrderRepository(null!, _dbContext));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_WithNullDbContext_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => new OrderRepository(_loggerMock.Object, null!));

        Assert.AreEqual("dbContext", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_WithValidParameters_CreatesInstance()
    {
        // Arrange & Act
        var repository = new OrderRepository(_loggerMock.Object, _dbContext);

        // Assert
        Assert.IsNotNull(repository);
    }

    #endregion

    #region SaveOrderAsync Tests

    [TestMethod]
    public async Task SaveOrderAsync_WithValidOrder_SavesOrderToDatabase()
    {
        // Arrange
        var order = CreateTestOrder("order-1", "customer-1");

        // Act
        await _repository.SaveOrderAsync(order);

        // Assert
        var savedEntity = await _dbContext.Orders
            .Include(o => o.Products)
            .FirstOrDefaultAsync(o => o.Id == order.Id);

        Assert.IsNotNull(savedEntity);
        Assert.AreEqual(order.Id, savedEntity.Id);
        Assert.AreEqual(order.CustomerId, savedEntity.CustomerId);
        Assert.AreEqual(order.DeliveryAddress, savedEntity.DeliveryAddress);
        Assert.AreEqual(order.Total, savedEntity.Total);
        Assert.AreEqual(order.Products.Count, savedEntity.Products.Count);
    }

    [TestMethod]
    public async Task SaveOrderAsync_WithNullOrder_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _repository.SaveOrderAsync(null!));
    }

    [TestMethod]
    public async Task SaveOrderAsync_WithDuplicateOrderId_ThrowsException()
    {
        // Arrange
        var order = CreateTestOrder("duplicate-order", "customer-1");
        await _repository.SaveOrderAsync(order);

        // Detach the tracked entity to allow adding a new one with the same key
        _dbContext.ChangeTracker.Clear();

        var duplicateOrder = CreateTestOrder("duplicate-order", "customer-2");

        // Act & Assert
        // Note: InMemory provider throws ArgumentException for duplicate keys,
        // whereas SQL Server would cause DbUpdateException leading to InvalidOperationException
        // from the repository's duplicate key handling
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.SaveOrderAsync(duplicateOrder));

        Assert.IsTrue(exception.Message.Contains("duplicate-order") ||
                      exception.Message.Contains("same key", StringComparison.OrdinalIgnoreCase));
    }

    [TestMethod]
    public async Task SaveOrderAsync_WithOrderProducts_SavesProductsToDatabase()
    {
        // Arrange
        var order = CreateTestOrderWithMultipleProducts("order-products", "customer-1", 3);

        // Act
        await _repository.SaveOrderAsync(order);

        // Assert
        var savedEntity = await _dbContext.Orders
            .Include(o => o.Products)
            .FirstOrDefaultAsync(o => o.Id == order.Id);

        Assert.IsNotNull(savedEntity);
        Assert.AreEqual(3, savedEntity.Products.Count);
    }

    #endregion

    #region GetAllOrdersAsync Tests

    [TestMethod]
    public async Task GetAllOrdersAsync_WithNoOrders_ReturnsEmptyCollection()
    {
        // Act
        var orders = await _repository.GetAllOrdersAsync();

        // Assert
        Assert.IsNotNull(orders);
        Assert.AreEqual(0, orders.Count());
    }

    [TestMethod]
    public async Task GetAllOrdersAsync_WithMultipleOrders_ReturnsAllOrders()
    {
        // Arrange
        await SeedOrdersAsync(5);

        // Act
        var orders = await _repository.GetAllOrdersAsync();

        // Assert
        Assert.IsNotNull(orders);
        Assert.AreEqual(5, orders.Count());
    }

    [TestMethod]
    public async Task GetAllOrdersAsync_IncludesProducts_ReturnsOrdersWithProducts()
    {
        // Arrange
        var order = CreateTestOrderWithMultipleProducts("order-with-products", "customer-1", 2);
        await _repository.SaveOrderAsync(order);

        // Act
        var orders = await _repository.GetAllOrdersAsync();

        // Assert
        var retrievedOrder = orders.First();
        Assert.AreEqual(2, retrievedOrder.Products.Count);
    }

    [TestMethod]
    public async Task GetAllOrdersAsync_WithCancellation_RespectsCancellationToken()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        // Act & Assert
        await Assert.ThrowsExactlyAsync<OperationCanceledException>(
            () => _repository.GetAllOrdersAsync(cts.Token));
    }

    #endregion

    #region GetOrderByIdAsync Tests

    [TestMethod]
    public async Task GetOrderByIdAsync_WithExistingOrder_ReturnsOrder()
    {
        // Arrange
        var order = CreateTestOrder("existing-order", "customer-1");
        await _repository.SaveOrderAsync(order);

        // Act
        var result = await _repository.GetOrderByIdAsync("existing-order");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("existing-order", result.Id);
        Assert.AreEqual("customer-1", result.CustomerId);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithNonExistingOrder_ReturnsNull()
    {
        // Act
        var result = await _repository.GetOrderByIdAsync("non-existing-order");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithNullOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.GetOrderByIdAsync(null!));
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithEmptyOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.GetOrderByIdAsync(string.Empty));
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithWhitespaceOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.GetOrderByIdAsync("   "));
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_IncludesProducts_ReturnsOrderWithProducts()
    {
        // Arrange
        var order = CreateTestOrderWithMultipleProducts("order-with-products", "customer-1", 3);
        await _repository.SaveOrderAsync(order);

        // Act
        var result = await _repository.GetOrderByIdAsync("order-with-products");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(3, result.Products.Count);
    }

    #endregion

    #region DeleteOrderAsync Tests

    [TestMethod]
    public async Task DeleteOrderAsync_WithExistingOrder_ReturnsTrue()
    {
        // Arrange
        var order = CreateTestOrder("order-to-delete", "customer-1");
        await _repository.SaveOrderAsync(order);

        // Act
        var result = await _repository.DeleteOrderAsync("order-to-delete");

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithExistingOrder_RemovesOrderFromDatabase()
    {
        // Arrange
        var order = CreateTestOrder("order-to-delete", "customer-1");
        await _repository.SaveOrderAsync(order);

        // Act
        await _repository.DeleteOrderAsync("order-to-delete");

        // Assert
        var deletedOrder = await _dbContext.Orders.FindAsync("order-to-delete");
        Assert.IsNull(deletedOrder);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithNonExistingOrder_ReturnsFalse()
    {
        // Act
        var result = await _repository.DeleteOrderAsync("non-existing-order");

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithNullOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.DeleteOrderAsync(null!));
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithEmptyOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.DeleteOrderAsync(string.Empty));
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithWhitespaceOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.DeleteOrderAsync("   "));
    }

    [TestMethod]
    public async Task DeleteOrderAsync_CascadeDeletesProducts()
    {
        // Arrange
        var order = CreateTestOrderWithMultipleProducts("order-with-products", "customer-1", 3);
        await _repository.SaveOrderAsync(order);

        var productCountBefore = await _dbContext.OrderProducts.CountAsync();
        Assert.AreEqual(3, productCountBefore);

        // Act
        await _repository.DeleteOrderAsync("order-with-products");

        // Assert
        var productCountAfter = await _dbContext.OrderProducts.CountAsync();
        Assert.AreEqual(0, productCountAfter);
    }

    #endregion

    #region OrderExistsAsync Tests

    [TestMethod]
    public async Task OrderExistsAsync_WithExistingOrder_ReturnsTrue()
    {
        // Arrange
        var order = CreateTestOrder("existing-order", "customer-1");
        await _repository.SaveOrderAsync(order);

        // Act
        var result = await _repository.OrderExistsAsync("existing-order");

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task OrderExistsAsync_WithNonExistingOrder_ReturnsFalse()
    {
        // Act
        var result = await _repository.OrderExistsAsync("non-existing-order");

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public async Task OrderExistsAsync_WithNullOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.OrderExistsAsync(null!));
    }

    [TestMethod]
    public async Task OrderExistsAsync_WithEmptyOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.OrderExistsAsync(string.Empty));
    }

    [TestMethod]
    public async Task OrderExistsAsync_WithWhitespaceOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.OrderExistsAsync("   "));
    }

    #endregion

    #region GetExistingOrderIdsAsync Tests

    [TestMethod]
    public async Task GetExistingOrderIdsAsync_WithExistingOrders_ReturnsMatchingIds()
    {
        // Arrange
        await SeedOrdersAsync(5);
        var idsToCheck = new[] { "order-0", "order-1", "order-2", "non-existing-1", "non-existing-2" };

        // Act
        var result = await _repository.GetExistingOrderIdsAsync(idsToCheck);

        // Assert
        Assert.AreEqual(3, result.Count);
        Assert.IsTrue(result.Contains("order-0"));
        Assert.IsTrue(result.Contains("order-1"));
        Assert.IsTrue(result.Contains("order-2"));
        Assert.IsFalse(result.Contains("non-existing-1"));
        Assert.IsFalse(result.Contains("non-existing-2"));
    }

    [TestMethod]
    public async Task GetExistingOrderIdsAsync_WithNoMatchingOrders_ReturnsEmptySet()
    {
        // Arrange
        await SeedOrdersAsync(3);
        var idsToCheck = new[] { "non-existing-1", "non-existing-2" };

        // Act
        var result = await _repository.GetExistingOrderIdsAsync(idsToCheck);

        // Assert
        Assert.AreEqual(0, result.Count);
    }

    [TestMethod]
    public async Task GetExistingOrderIdsAsync_WithEmptyInput_ReturnsEmptySet()
    {
        // Arrange
        await SeedOrdersAsync(3);
        var idsToCheck = Array.Empty<string>();

        // Act
        var result = await _repository.GetExistingOrderIdsAsync(idsToCheck);

        // Assert
        Assert.AreEqual(0, result.Count);
    }

    [TestMethod]
    public async Task GetExistingOrderIdsAsync_WithNullInput_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _repository.GetExistingOrderIdsAsync(null!));
    }

    [TestMethod]
    public async Task GetExistingOrderIdsAsync_WithAllMatchingOrders_ReturnsAllIds()
    {
        // Arrange
        await SeedOrdersAsync(3);
        var idsToCheck = new[] { "order-0", "order-1", "order-2" };

        // Act
        var result = await _repository.GetExistingOrderIdsAsync(idsToCheck);

        // Assert
        Assert.AreEqual(3, result.Count);
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string orderId, string customerId)
    {
        return new Order
        {
            Id = orderId,
            CustomerId = customerId,
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Total = 99.99m,
            Products =
            [
                new OrderProduct
                {
                    Id = $"{orderId}-product-1",
                    OrderId = orderId,
                    ProductId = "product-1",
                    ProductDescription = "Test Product 1",
                    Quantity = 1,
                    Price = 99.99m
                }
            ]
        };
    }

    private static Order CreateTestOrderWithMultipleProducts(string orderId, string customerId, int productCount)
    {
        var products = Enumerable.Range(1, productCount)
            .Select(i => new OrderProduct
            {
                Id = $"{orderId}-product-{i}",
                OrderId = orderId,
                ProductId = $"product-{i}",
                ProductDescription = $"Test Product {i}",
                Quantity = i,
                Price = 10.00m * i
            })
            .ToList();

        return new Order
        {
            Id = orderId,
            CustomerId = customerId,
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Total = products.Sum(p => p.Price * p.Quantity),
            Products = products
        };
    }

    private async Task SeedOrdersAsync(int count)
    {
        for (int i = 0; i < count; i++)
        {
            var order = CreateTestOrder($"order-{i}", $"customer-{i}");
            await _repository.SaveOrderAsync(order);
        }
    }

    #endregion
}