// =============================================================================
// Unit Tests for OrderRepository
// Tests Entity Framework Core-based persistence for order data
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Data;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using NSubstitute;

namespace eShop.Orders.API.Tests.Repositories;

/// <summary>
/// Unit tests for <see cref="OrderRepository"/> class.
/// Verifies Entity Framework Core-based persistence behavior using in-memory database.
/// </summary>
[TestClass]
public sealed class OrderRepositoryTests
{
    private OrderDbContext _dbContext = null!;
    private ILogger<OrderRepository> _logger = null!;
    private OrderRepository _repository = null!;

    private const string TestOrderId = "order-12345";
    private const string TestCustomerId = "customer-67890";
    private const string TestDeliveryAddress = "123 Test Street, Test City, TC 12345";

    [TestInitialize]
    public void TestInitialize()
    {
        var options = new DbContextOptionsBuilder<OrderDbContext>()
            .UseInMemoryDatabase(databaseName: $"TestOrderDb_{Guid.NewGuid()}")
            .Options;

        _dbContext = new OrderDbContext(options);
        _logger = Substitute.For<ILogger<OrderRepository>>();
        _repository = new OrderRepository(_logger, _dbContext);
    }

    [TestCleanup]
    public async Task TestCleanup()
    {
        await _dbContext.DisposeAsync();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderRepository(null!, _dbContext));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullDbContext_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderRepository(_logger, null!));

        Assert.AreEqual("dbContext", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_ValidParameters_CreatesInstance()
    {
        // Arrange & Act
        var repository = new OrderRepository(_logger, _dbContext);

        // Assert
        Assert.IsNotNull(repository);
        Assert.IsInstanceOfType<IOrderRepository>(repository);
    }

    #endregion

    #region SaveOrderAsync Tests

    [TestMethod]
    public async Task SaveOrderAsync_ValidOrder_SavesSuccessfully()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Assert
        var savedOrder = await _dbContext.Orders
            .Include(o => o.Products)
            .FirstOrDefaultAsync(o => o.Id == order.Id);

        Assert.IsNotNull(savedOrder);
        Assert.AreEqual(order.Id, savedOrder.Id);
        Assert.AreEqual(order.CustomerId, savedOrder.CustomerId);
        Assert.AreEqual(order.DeliveryAddress, savedOrder.DeliveryAddress);
        Assert.AreEqual(order.Total, savedOrder.Total);
        Assert.HasCount(order.Products.Count, savedOrder.Products);
    }

    [TestMethod]
    public async Task SaveOrderAsync_NullOrder_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _repository.SaveOrderAsync(null!, CancellationToken.None));

        Assert.AreEqual("order", exception.ParamName);
    }

    [TestMethod]
    public async Task SaveOrderAsync_OrderWithProducts_SavesProductsCorrectly()
    {
        // Arrange
        var order = CreateTestOrder(productCount: 3);

        // Act
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Assert
        var savedOrder = await _dbContext.Orders
            .Include(o => o.Products)
            .FirstOrDefaultAsync(o => o.Id == order.Id);

        Assert.IsNotNull(savedOrder);
        Assert.HasCount(3, savedOrder.Products);

        foreach (var product in order.Products)
        {
            var savedProduct = savedOrder.Products.FirstOrDefault(p => p.Id == product.Id);
            Assert.IsNotNull(savedProduct);
            Assert.AreEqual(product.ProductDescription, savedProduct.ProductDescription);
            Assert.AreEqual(product.Quantity, savedProduct.Quantity);
            Assert.AreEqual(product.Price, savedProduct.Price);
        }
    }

    [TestMethod]
    public async Task SaveOrderAsync_MultipleDifferentOrders_SavesAllSuccessfully()
    {
        // Arrange
        var order1 = CreateTestOrder("order-1");
        var order2 = CreateTestOrder("order-2");
        var order3 = CreateTestOrder("order-3");

        // Act
        await _repository.SaveOrderAsync(order1, CancellationToken.None);
        await _repository.SaveOrderAsync(order2, CancellationToken.None);
        await _repository.SaveOrderAsync(order3, CancellationToken.None);

        // Assert
        var count = await _dbContext.Orders.CountAsync();
        Assert.AreEqual(3, count);
    }

    #endregion

    #region GetAllOrdersAsync Tests

    [TestMethod]
    public async Task GetAllOrdersAsync_NoOrders_ReturnsEmptyCollection()
    {
        // Arrange - Empty database

        // Act
        var orders = await _repository.GetAllOrdersAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(orders);
        Assert.HasCount(0, orders);
    }

    [TestMethod]
    public async Task GetAllOrdersAsync_WithOrders_ReturnsAllOrders()
    {
        // Arrange
        await SeedTestOrders(3);

        // Act
        var orders = await _repository.GetAllOrdersAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(orders);
        Assert.HasCount(3, orders);
    }

    [TestMethod]
    public async Task GetAllOrdersAsync_WithOrders_IncludesProducts()
    {
        // Arrange
        var order = CreateTestOrder(productCount: 2);
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        var orders = await _repository.GetAllOrdersAsync(CancellationToken.None);

        // Assert
        var retrievedOrder = orders.First();
        Assert.HasCount(2, retrievedOrder.Products);
    }

    [TestMethod]
    public async Task GetAllOrdersAsync_ReturnsCorrectOrderData()
    {
        // Arrange
        var originalOrder = CreateTestOrder();
        await _repository.SaveOrderAsync(originalOrder, CancellationToken.None);

        // Act
        var orders = await _repository.GetAllOrdersAsync(CancellationToken.None);

        // Assert
        var retrievedOrder = orders.First();
        Assert.AreEqual(originalOrder.Id, retrievedOrder.Id);
        Assert.AreEqual(originalOrder.CustomerId, retrievedOrder.CustomerId);
        Assert.AreEqual(originalOrder.DeliveryAddress, retrievedOrder.DeliveryAddress);
        Assert.AreEqual(originalOrder.Total, retrievedOrder.Total);
    }

    #endregion

    #region GetOrdersPagedAsync Tests

    [TestMethod]
    public async Task GetOrdersPagedAsync_DefaultParameters_ReturnsFirstPage()
    {
        // Arrange
        await SeedTestOrders(25);

        // Act
        var (orders, totalCount) = await _repository.GetOrdersPagedAsync(cancellationToken: CancellationToken.None);

        // Assert
        Assert.AreEqual(25, totalCount);
        Assert.AreEqual(20, orders.Count()); // Default page size is 20
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_SecondPage_ReturnsCorrectOrders()
    {
        // Arrange
        await SeedTestOrders(25);

        // Act
        var (orders, totalCount) = await _repository.GetOrdersPagedAsync(
            pageNumber: 2,
            pageSize: 10,
            cancellationToken: CancellationToken.None);

        // Assert
        Assert.AreEqual(25, totalCount);
        Assert.AreEqual(10, orders.Count());
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_LastPagePartialResults_ReturnsRemainingOrders()
    {
        // Arrange
        await SeedTestOrders(25);

        // Act
        var (orders, totalCount) = await _repository.GetOrdersPagedAsync(
            pageNumber: 3,
            pageSize: 10,
            cancellationToken: CancellationToken.None);

        // Assert
        Assert.AreEqual(25, totalCount);
        Assert.AreEqual(5, orders.Count()); // Only 5 remaining on page 3
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_PageBeyondTotal_ReturnsEmptyCollection()
    {
        // Arrange
        await SeedTestOrders(10);

        // Act
        var (orders, totalCount) = await _repository.GetOrdersPagedAsync(
            pageNumber: 5,
            pageSize: 10,
            cancellationToken: CancellationToken.None);

        // Assert
        Assert.AreEqual(10, totalCount);
        Assert.AreEqual(0, orders.Count());
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_ZeroOrNegativePageNumber_NormalizesToOne()
    {
        // Arrange
        await SeedTestOrders(10);

        // Act
        var (ordersZero, _) = await _repository.GetOrdersPagedAsync(
            pageNumber: 0,
            pageSize: 5,
            cancellationToken: CancellationToken.None);

        var (ordersNegative, _) = await _repository.GetOrdersPagedAsync(
            pageNumber: -1,
            pageSize: 5,
            cancellationToken: CancellationToken.None);

        // Assert - Both should return first page (normalized)
        Assert.AreEqual(5, ordersZero.Count());
        Assert.AreEqual(5, ordersNegative.Count());
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_PageSizeExceedsMax_ClampedTo100()
    {
        // Arrange
        await SeedTestOrders(150);

        // Act
        var (orders, totalCount) = await _repository.GetOrdersPagedAsync(
            pageNumber: 1,
            pageSize: 200, // Exceeds max of 100
            cancellationToken: CancellationToken.None);

        // Assert
        Assert.AreEqual(150, totalCount);
        Assert.AreEqual(100, orders.Count()); // Should be clamped to 100
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_ZeroOrNegativePageSize_NormalizesToOne()
    {
        // Arrange
        await SeedTestOrders(10);

        // Act
        var (ordersZero, _) = await _repository.GetOrdersPagedAsync(
            pageNumber: 1,
            pageSize: 0,
            cancellationToken: CancellationToken.None);

        var (ordersNegative, _) = await _repository.GetOrdersPagedAsync(
            pageNumber: 1,
            pageSize: -5,
            cancellationToken: CancellationToken.None);

        // Assert - Both should return 1 item (normalized)
        Assert.AreEqual(1, ordersZero.Count());
        Assert.AreEqual(1, ordersNegative.Count());
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_EmptyDatabase_ReturnsEmptyCollectionWithZeroTotal()
    {
        // Arrange - Empty database

        // Act
        var (orders, totalCount) = await _repository.GetOrdersPagedAsync(cancellationToken: CancellationToken.None);

        // Assert
        Assert.AreEqual(0, totalCount);
        Assert.AreEqual(0, orders.Count());
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_IncludesProducts()
    {
        // Arrange
        var order = CreateTestOrder(productCount: 3);
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        var (orders, _) = await _repository.GetOrdersPagedAsync(cancellationToken: CancellationToken.None);

        // Assert
        var retrievedOrder = orders.First();
        Assert.HasCount(3, retrievedOrder.Products);
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_OrdersByDateDescending()
    {
        // Arrange - Create orders with different dates
        var order1 = CreateTestOrder("order-1") with { Date = DateTime.UtcNow.AddDays(-2) };
        var order2 = CreateTestOrder("order-2") with { Date = DateTime.UtcNow.AddDays(-1) };
        var order3 = CreateTestOrder("order-3") with { Date = DateTime.UtcNow };

        await _repository.SaveOrderAsync(order1, CancellationToken.None);
        await _repository.SaveOrderAsync(order2, CancellationToken.None);
        await _repository.SaveOrderAsync(order3, CancellationToken.None);

        // Act
        var (orders, _) = await _repository.GetOrdersPagedAsync(
            pageNumber: 1,
            pageSize: 10,
            cancellationToken: CancellationToken.None);

        // Assert - Most recent first
        var ordersList = orders.ToList();
        Assert.AreEqual("order-3", ordersList[0].Id);
        Assert.AreEqual("order-2", ordersList[1].Id);
        Assert.AreEqual("order-1", ordersList[2].Id);
    }

    [TestMethod]
    public async Task GetOrdersPagedAsync_SingleItem_ReturnsCorrectly()
    {
        // Arrange
        await SeedTestOrders(1);

        // Act
        var (orders, totalCount) = await _repository.GetOrdersPagedAsync(
            pageNumber: 1,
            pageSize: 10,
            cancellationToken: CancellationToken.None);

        // Assert
        Assert.AreEqual(1, totalCount);
        Assert.AreEqual(1, orders.Count());
    }

    #endregion

    #region GetOrderByIdAsync Tests

    [TestMethod]
    public async Task GetOrderByIdAsync_ExistingOrder_ReturnsOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        var result = await _repository.GetOrderByIdAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(order.Id, result.Id);
        Assert.AreEqual(order.CustomerId, result.CustomerId);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_NonExistingOrder_ReturnsNull()
    {
        // Arrange
        await SeedTestOrders(1);

        // Act
        var result = await _repository.GetOrderByIdAsync("non-existing-id", CancellationToken.None);

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_NullOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.GetOrderByIdAsync(null!, CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.GetOrderByIdAsync("", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WhitespaceOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.GetOrderByIdAsync("   ", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_ExistingOrder_IncludesProducts()
    {
        // Arrange
        var order = CreateTestOrder(productCount: 3);
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        var result = await _repository.GetOrderByIdAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.HasCount(3, result.Products);
    }

    #endregion

    #region DeleteOrderAsync Tests

    [TestMethod]
    public async Task DeleteOrderAsync_ExistingOrder_ReturnsTrue()
    {
        // Arrange
        var order = CreateTestOrder();
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        var result = await _repository.DeleteOrderAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_ExistingOrder_RemovesFromDatabase()
    {
        // Arrange
        var order = CreateTestOrder();
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        await _repository.DeleteOrderAsync(order.Id, CancellationToken.None);

        // Assert
        var deletedOrder = await _dbContext.Orders.FindAsync(order.Id);
        Assert.IsNull(deletedOrder);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_NonExistingOrder_ReturnsFalse()
    {
        // Arrange - Empty database

        // Act
        var result = await _repository.DeleteOrderAsync("non-existing-id", CancellationToken.None);

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_NullOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.DeleteOrderAsync(null!, CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.DeleteOrderAsync("", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_ExistingOrder_DeletesProductsCascade()
    {
        // Arrange
        var order = CreateTestOrder(productCount: 3);
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        await _repository.DeleteOrderAsync(order.Id, CancellationToken.None);

        // Assert - Products should also be deleted due to cascade
        var productCount = await _dbContext.OrderProducts.CountAsync();
        Assert.AreEqual(0, productCount);
    }

    #endregion

    #region OrderExistsAsync Tests

    [TestMethod]
    public async Task OrderExistsAsync_ExistingOrder_ReturnsTrue()
    {
        // Arrange
        var order = CreateTestOrder();
        await _repository.SaveOrderAsync(order, CancellationToken.None);

        // Act
        var exists = await _repository.OrderExistsAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsTrue(exists);
    }

    [TestMethod]
    public async Task OrderExistsAsync_NonExistingOrder_ReturnsFalse()
    {
        // Arrange - Empty database

        // Act
        var exists = await _repository.OrderExistsAsync("non-existing-id", CancellationToken.None);

        // Assert
        Assert.IsFalse(exists);
    }

    [TestMethod]
    public async Task OrderExistsAsync_NullOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.OrderExistsAsync(null!, CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task OrderExistsAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.OrderExistsAsync("", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task OrderExistsAsync_WhitespaceOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _repository.OrderExistsAsync("   ", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task OrderExistsAsync_AfterDeletion_ReturnsFalse()
    {
        // Arrange
        var order = CreateTestOrder();
        await _repository.SaveOrderAsync(order, CancellationToken.None);
        await _repository.DeleteOrderAsync(order.Id, CancellationToken.None);

        // Act
        var exists = await _repository.OrderExistsAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsFalse(exists);
    }

    #endregion

    #region Integration Scenarios

    [TestMethod]
    public async Task Repository_SaveThenRetrieve_DataIntegrity()
    {
        // Arrange
        var originalOrder = CreateTestOrder(productCount: 2);

        // Act
        await _repository.SaveOrderAsync(originalOrder, CancellationToken.None);
        var retrievedOrder = await _repository.GetOrderByIdAsync(originalOrder.Id, CancellationToken.None);

        // Assert
        Assert.IsNotNull(retrievedOrder);
        Assert.AreEqual(originalOrder.Id, retrievedOrder.Id);
        Assert.AreEqual(originalOrder.CustomerId, retrievedOrder.CustomerId);
        Assert.AreEqual(originalOrder.DeliveryAddress, retrievedOrder.DeliveryAddress);
        Assert.AreEqual(originalOrder.Total, retrievedOrder.Total);
        Assert.HasCount(originalOrder.Products.Count, retrievedOrder.Products);

        for (var i = 0; i < originalOrder.Products.Count; i++)
        {
            var originalProduct = originalOrder.Products[i];
            var retrievedProduct = retrievedOrder.Products.First(p => p.Id == originalProduct.Id);
            Assert.AreEqual(originalProduct.ProductDescription, retrievedProduct.ProductDescription);
            Assert.AreEqual(originalProduct.Quantity, retrievedProduct.Quantity);
            Assert.AreEqual(originalProduct.Price, retrievedProduct.Price);
        }
    }

    [TestMethod]
    public async Task Repository_SaveDeleteCheckExists_CorrectLifecycle()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act & Assert - Save
        await _repository.SaveOrderAsync(order, CancellationToken.None);
        Assert.IsTrue(await _repository.OrderExistsAsync(order.Id, CancellationToken.None));

        // Act & Assert - Delete
        var deleted = await _repository.DeleteOrderAsync(order.Id, CancellationToken.None);
        Assert.IsTrue(deleted);

        // Act & Assert - Verify gone
        Assert.IsFalse(await _repository.OrderExistsAsync(order.Id, CancellationToken.None));
        Assert.IsNull(await _repository.GetOrderByIdAsync(order.Id, CancellationToken.None));
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string? orderId = null, int productCount = 1)
    {
        var id = orderId ?? TestOrderId;
        return new Order
        {
            Id = id,
            CustomerId = TestCustomerId,
            Date = DateTime.UtcNow,
            DeliveryAddress = TestDeliveryAddress,
            Total = productCount * 25.99m,
            Products = Enumerable.Range(1, productCount)
                .Select(i => new OrderProduct
                {
                    Id = $"{id}-product-{i}",
                    OrderId = id,
                    ProductId = $"product-{i}",
                    ProductDescription = $"Test Product {i}",
                    Quantity = i,
                    Price = 25.99m
                })
                .ToList()
        };
    }

    private async Task SeedTestOrders(int count)
    {
        for (var i = 1; i <= count; i++)
        {
            var order = CreateTestOrder($"seeded-order-{i}");
            await _repository.SaveOrderAsync(order, CancellationToken.None);
        }
    }

    #endregion
}