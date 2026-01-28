// =============================================================================
// CommonTypes Unit Tests
// Tests for shared domain models: Order, OrderProduct, WeatherForecast
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using System.ComponentModel.DataAnnotations;

namespace eShop.Web.App.Tests.Models;

[TestClass]
public sealed class OrderTests
{
    #region Order Property Tests

    [TestMethod]
    public void Order_ValidProperties_CreatesInstance()
    {
        // Arrange & Act
        var order = CreateValidOrder();

        // Assert
        Assert.IsNotNull(order);
        Assert.AreEqual("order-123", order.Id);
        Assert.AreEqual("customer-456", order.CustomerId);
        Assert.AreEqual("123 Main St", order.DeliveryAddress);
        Assert.AreEqual(99.99m, order.Total);
        Assert.IsNotNull(order.Products);
        Assert.HasCount(1, order.Products);
    }

    [TestMethod]
    public void Order_DefaultDate_IsSetToUtcNow()
    {
        // Arrange
        var beforeCreation = DateTime.UtcNow;

        // Act
        var order = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Products = new List<OrderProduct> { CreateValidOrderProduct("order-123") }
        };

        var afterCreation = DateTime.UtcNow;

        // Assert
        Assert.IsTrue(order.Date >= beforeCreation);
        Assert.IsTrue(order.Date <= afterCreation);
    }

    [TestMethod]
    public void Order_CustomDate_IsPreserved()
    {
        // Arrange
        var specificDate = new DateTime(2025, 6, 15, 10, 30, 0, DateTimeKind.Utc);

        // Act
        var order = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Date = specificDate,
            Products = new List<OrderProduct> { CreateValidOrderProduct("order-123") }
        };

        // Assert
        Assert.AreEqual(specificDate, order.Date);
    }

    [TestMethod]
    public void Order_ZeroTotal_IsValid()
    {
        // Arrange & Act
        var order = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Total = 0m,
            Products = new List<OrderProduct> { CreateValidOrderProduct("order-123") }
        };

        // Assert
        Assert.AreEqual(0m, order.Total);
    }

    [TestMethod]
    public void Order_MultipleProducts_SupportsCollection()
    {
        // Arrange & Act
        var products = new List<OrderProduct>
        {
            CreateValidOrderProduct("order-123", "prod-1"),
            CreateValidOrderProduct("order-123", "prod-2"),
            CreateValidOrderProduct("order-123", "prod-3")
        };

        var order = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Products = products
        };

        // Assert
        Assert.HasCount(3, order.Products);
    }

    #endregion

    #region Order Validation Tests

    [TestMethod]
    public void Order_EmptyId_FailsValidation()
    {
        // Arrange
        var order = new Order
        {
            Id = "",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Products = new List<OrderProduct> { CreateValidOrderProduct("") }
        };

        // Act
        var validationResults = ValidateModel(order);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Id")));
    }

    [TestMethod]
    public void Order_IdExceedsMaxLength_FailsValidation()
    {
        // Arrange
        var longId = new string('x', 101); // MaxLength is 100

        var order = new Order
        {
            Id = longId,
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Products = new List<OrderProduct> { CreateValidOrderProduct(longId) }
        };

        // Act
        var validationResults = ValidateModel(order);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Id")));
    }

    [TestMethod]
    public void Order_DeliveryAddressTooShort_FailsValidation()
    {
        // Arrange - MinimumLength is 5
        var order = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "1234", // Only 4 characters
            Products = new List<OrderProduct> { CreateValidOrderProduct("order-123") }
        };

        // Act
        var validationResults = ValidateModel(order);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("DeliveryAddress")));
    }

    [TestMethod]
    public void Order_NegativeTotal_FailsValidation()
    {
        // Arrange - Range requires > 0.01
        var order = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Total = -10m,
            Products = new List<OrderProduct> { CreateValidOrderProduct("order-123") }
        };

        // Act
        var validationResults = ValidateModel(order);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Total")));
    }

    [TestMethod]
    public void Order_EmptyProducts_FailsValidation()
    {
        // Arrange
        var order = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Products = new List<OrderProduct>()
        };

        // Act
        var validationResults = ValidateModel(order);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Products")));
    }

    #endregion

    #region Order Record Equality Tests

    [TestMethod]
    public void Order_SameProperties_AreEqual()
    {
        // Arrange
        var date = DateTime.UtcNow;
        var order1 = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Date = date,
            Total = 99.99m,
            Products = new List<OrderProduct> { CreateValidOrderProduct("order-123") }
        };

        var order2 = new Order
        {
            Id = "order-123",
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Date = date,
            Total = 99.99m,
            Products = order1.Products // Same reference
        };

        // Assert
        Assert.AreEqual(order1, order2);
    }

    [TestMethod]
    public void Order_DifferentIds_AreNotEqual()
    {
        // Arrange
        var order1 = CreateValidOrder("order-123");
        var order2 = CreateValidOrder("order-456");

        // Assert
        Assert.AreNotEqual(order1, order2);
    }

    #endregion

    #region Helper Methods

    private static Order CreateValidOrder(string? id = null)
    {
        var orderId = id ?? "order-123";
        return new Order
        {
            Id = orderId,
            CustomerId = "customer-456",
            DeliveryAddress = "123 Main St",
            Total = 99.99m,
            Products = new List<OrderProduct> { CreateValidOrderProduct(orderId) }
        };
    }

    private static OrderProduct CreateValidOrderProduct(string orderId, string? productId = null)
    {
        return new OrderProduct
        {
            Id = $"item-{Guid.NewGuid():N}",
            OrderId = orderId,
            ProductId = productId ?? "product-001",
            ProductDescription = "Test Product Description",
            Quantity = 1,
            Price = 99.99m
        };
    }

    private static List<ValidationResult> ValidateModel(object model)
    {
        var validationResults = new List<ValidationResult>();
        var context = new ValidationContext(model);
        Validator.TryValidateObject(model, context, validationResults, validateAllProperties: true);
        return validationResults;
    }

    #endregion
}

[TestClass]
public sealed class OrderProductTests
{
    #region OrderProduct Property Tests

    [TestMethod]
    public void OrderProduct_ValidProperties_CreatesInstance()
    {
        // Arrange & Act
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 5,
            Price = 19.99m
        };

        // Assert
        Assert.AreEqual("item-123", product.Id);
        Assert.AreEqual("order-456", product.OrderId);
        Assert.AreEqual("product-789", product.ProductId);
        Assert.AreEqual("Test Product", product.ProductDescription);
        Assert.AreEqual(5, product.Quantity);
        Assert.AreEqual(19.99m, product.Price);
    }

    [TestMethod]
    public void OrderProduct_DefaultQuantity_IsZero()
    {
        // Arrange & Act
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product"
        };

        // Assert
        Assert.AreEqual(0, product.Quantity);
    }

    [TestMethod]
    public void OrderProduct_DefaultPrice_IsZero()
    {
        // Arrange & Act
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product"
        };

        // Assert
        Assert.AreEqual(0m, product.Price);
    }

    #endregion

    #region OrderProduct Validation Tests

    [TestMethod]
    public void OrderProduct_ZeroQuantity_FailsValidation()
    {
        // Arrange - Range requires >= 1
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 0,
            Price = 19.99m
        };

        // Act
        var validationResults = ValidateModel(product);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Quantity")));
    }

    [TestMethod]
    public void OrderProduct_NegativeQuantity_FailsValidation()
    {
        // Arrange
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = -1,
            Price = 19.99m
        };

        // Act
        var validationResults = ValidateModel(product);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Quantity")));
    }

    [TestMethod]
    public void OrderProduct_ZeroPrice_FailsValidation()
    {
        // Arrange - Range requires > 0.01
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 1,
            Price = 0m
        };

        // Act
        var validationResults = ValidateModel(product);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Price")));
    }

    [TestMethod]
    public void OrderProduct_NegativePrice_FailsValidation()
    {
        // Arrange
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 1,
            Price = -9.99m
        };

        // Act
        var validationResults = ValidateModel(product);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Price")));
    }

    [TestMethod]
    public void OrderProduct_EmptyDescription_FailsValidation()
    {
        // Arrange
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "",
            Quantity = 1,
            Price = 19.99m
        };

        // Act
        var validationResults = ValidateModel(product);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("ProductDescription")));
    }

    [TestMethod]
    public void OrderProduct_DescriptionExceedsMaxLength_FailsValidation()
    {
        // Arrange - MaxLength is 500
        var product = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = new string('x', 501),
            Quantity = 1,
            Price = 19.99m
        };

        // Act
        var validationResults = ValidateModel(product);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("ProductDescription")));
    }

    #endregion

    #region OrderProduct Record Equality Tests

    [TestMethod]
    public void OrderProduct_SameProperties_AreEqual()
    {
        // Arrange
        var product1 = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 5,
            Price = 19.99m
        };

        var product2 = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 5,
            Price = 19.99m
        };

        // Assert
        Assert.AreEqual(product1, product2);
    }

    [TestMethod]
    public void OrderProduct_DifferentPrices_AreNotEqual()
    {
        // Arrange
        var product1 = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 5,
            Price = 19.99m
        };

        var product2 = new OrderProduct
        {
            Id = "item-123",
            OrderId = "order-456",
            ProductId = "product-789",
            ProductDescription = "Test Product",
            Quantity = 5,
            Price = 29.99m
        };

        // Assert
        Assert.AreNotEqual(product1, product2);
    }

    #endregion

    #region Helper Methods

    private static List<ValidationResult> ValidateModel(object model)
    {
        var validationResults = new List<ValidationResult>();
        var context = new ValidationContext(model);
        Validator.TryValidateObject(model, context, validationResults, validateAllProperties: true);
        return validationResults;
    }

    #endregion
}

[TestClass]
public sealed class WeatherForecastTests
{
    #region WeatherForecast Property Tests

    [TestMethod]
    public void WeatherForecast_ValidProperties_CreatesInstance()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 25,
            Summary = "Sunny"
        };

        // Assert
        Assert.AreEqual(DateOnly.FromDateTime(DateTime.Today), forecast.Date);
        Assert.AreEqual(25, forecast.TemperatureC);
        Assert.AreEqual("Sunny", forecast.Summary);
    }

    [TestMethod]
    public void WeatherForecast_TemperatureF_CalculatesCorrectly()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 0
        };

        // Assert - 0°C = 32°F
        Assert.AreEqual(32, forecast.TemperatureF);
    }

    [TestMethod]
    public void WeatherForecast_TemperatureF_CalculatesCorrectlyForPositive()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 100
        };

        // Assert - 100°C = 212°F
        Assert.AreEqual(212, forecast.TemperatureF);
    }

    [TestMethod]
    public void WeatherForecast_TemperatureF_CalculatesCorrectlyForNegative()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = -40
        };

        // Assert - -40°C = -40°F (they converge at this point)
        Assert.AreEqual(-40, forecast.TemperatureF);
    }

    [TestMethod]
    public void WeatherForecast_TemperatureF_CalculatesRoomTemperature()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 20
        };

        // Assert - 20°C = 68°F
        Assert.AreEqual(68, forecast.TemperatureF);
    }

    [TestMethod]
    public void WeatherForecast_NullSummary_IsAllowed()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 25,
            Summary = null
        };

        // Assert
        Assert.IsNull(forecast.Summary);
    }

    #endregion

    #region WeatherForecast Validation Tests

    [TestMethod]
    public void WeatherForecast_TemperatureBelowAbsoluteZero_FailsValidation()
    {
        // Arrange - Range is -273 to 200
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = -274
        };

        // Act
        var validationResults = ValidateModel(forecast);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("TemperatureC")));
    }

    [TestMethod]
    public void WeatherForecast_TemperatureAboveMax_FailsValidation()
    {
        // Arrange - Range is -273 to 200
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 201
        };

        // Act
        var validationResults = ValidateModel(forecast);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("TemperatureC")));
    }

    [TestMethod]
    public void WeatherForecast_TemperatureAtAbsoluteZero_PassesValidation()
    {
        // Arrange - -273°C (absolute zero rounded)
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = -273
        };

        // Act
        var validationResults = ValidateModel(forecast);

        // Assert
        Assert.IsFalse(validationResults.Any(v => v.MemberNames.Contains("TemperatureC")));
    }

    [TestMethod]
    public void WeatherForecast_TemperatureAtMax_PassesValidation()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 200
        };

        // Act
        var validationResults = ValidateModel(forecast);

        // Assert
        Assert.IsFalse(validationResults.Any(v => v.MemberNames.Contains("TemperatureC")));
    }

    [TestMethod]
    public void WeatherForecast_SummaryExceedsMaxLength_FailsValidation()
    {
        // Arrange - MaxLength is 100
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 25,
            Summary = new string('x', 101)
        };

        // Act
        var validationResults = ValidateModel(forecast);

        // Assert
        Assert.IsTrue(validationResults.Any(v => v.MemberNames.Contains("Summary")));
    }

    [TestMethod]
    public void WeatherForecast_SummaryAtMaxLength_PassesValidation()
    {
        // Arrange - MaxLength is 100
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 25,
            Summary = new string('x', 100)
        };

        // Act
        var validationResults = ValidateModel(forecast);

        // Assert
        Assert.IsFalse(validationResults.Any(v => v.MemberNames.Contains("Summary")));
    }

    #endregion

    #region WeatherForecast Temperature Conversion Edge Cases

    [TestMethod]
    public void WeatherForecast_FreezingPoint_ConvertedCorrectly()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 0
        };

        // Assert
        Assert.AreEqual(32, forecast.TemperatureF);
    }

    [TestMethod]
    public void WeatherForecast_BoilingPoint_ConvertedCorrectly()
    {
        // Arrange & Act
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 100
        };

        // Assert
        Assert.AreEqual(212, forecast.TemperatureF);
    }

    [TestMethod]
    public void WeatherForecast_BodyTemperature_ConvertedCorrectly()
    {
        // Arrange & Act - 37°C is normal body temperature
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Today),
            TemperatureC = 37
        };

        // Assert - 37°C ≈ 98.6°F, but with int conversion: 32 + (37 * 1.8) = 98.6 → 98
        Assert.AreEqual(98, forecast.TemperatureF);
    }

    #endregion

    #region Helper Methods

    private static List<ValidationResult> ValidateModel(object model)
    {
        var validationResults = new List<ValidationResult>();
        var context = new ValidationContext(model);
        Validator.TryValidateObject(model, context, validationResults, validateAllProperties: true);
        return validationResults;
    }

    #endregion
}
