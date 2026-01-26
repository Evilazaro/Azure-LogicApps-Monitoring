// =============================================================================
// WeatherForecast Unit Tests
// Tests for the WeatherForecast class including property validation and calculations
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using System.ComponentModel.DataAnnotations;

namespace app.ServiceDefaults.Tests.CommonTypes;

[TestClass]
public sealed class WeatherForecastTests
{
    #region TemperatureF Calculation Tests

    [TestMethod]
    [DataRow(0, 32)]
    [DataRow(100, 212)]
    [DataRow(-40, -40)]
    [DataRow(37, 98)]
    [DataRow(-273, -459)]
    public void TemperatureF_GivenTemperatureC_ReturnsCorrectFahrenheit(int celsius, int expectedFahrenheit)
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = celsius
        };

        // Act
        var result = forecast.TemperatureF;

        // Assert
        Assert.AreEqual(expectedFahrenheit, result);
    }

    [TestMethod]
    public void TemperatureF_FreezingPoint_Returns32()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = 0
        };

        // Act
        var result = forecast.TemperatureF;

        // Assert
        Assert.AreEqual(32, result, "0°C should equal 32°F (freezing point)");
    }

    [TestMethod]
    public void TemperatureF_BoilingPoint_Returns212()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = 100
        };

        // Act
        var result = forecast.TemperatureF;

        // Assert
        Assert.AreEqual(212, result, "100°C should equal 212°F (boiling point)");
    }

    #endregion

    #region Property Assignment Tests

    [TestMethod]
    public void Date_WhenSet_ReturnsCorrectValue()
    {
        // Arrange
        var expectedDate = new DateOnly(2024, 6, 15);
        var forecast = new WeatherForecast
        {
            Date = expectedDate,
            TemperatureC = 25
        };

        // Act & Assert
        Assert.AreEqual(expectedDate, forecast.Date);
    }

    [TestMethod]
    public void Summary_WhenSet_ReturnsCorrectValue()
    {
        // Arrange
        const string expectedSummary = "Sunny with clear skies";
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = 25,
            Summary = expectedSummary
        };

        // Act & Assert
        Assert.AreEqual(expectedSummary, forecast.Summary);
    }

    [TestMethod]
    public void Summary_WhenNotSet_IsNull()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = 25
        };

        // Act & Assert
        Assert.IsNull(forecast.Summary);
    }

    #endregion

    #region Validation Tests

    [TestMethod]
    [DataRow(-273, true, "Minimum valid temperature")]
    [DataRow(200, true, "Maximum valid temperature")]
    [DataRow(0, true, "Zero temperature")]
    [DataRow(-274, false, "Below minimum")]
    [DataRow(201, false, "Above maximum")]
    public void TemperatureC_Validation_ReturnsExpectedResult(int temperature, bool expectedValid, string scenario)
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = temperature
        };
        var context = new ValidationContext(forecast) { MemberName = nameof(WeatherForecast.TemperatureC) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(forecast.TemperatureC, context, results);

        // Assert
        Assert.AreEqual(expectedValid, isValid, $"Validation failed for scenario: {scenario}");
    }

    [TestMethod]
    public void Summary_ExceedsMaxLength_ValidationFails()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = 25,
            Summary = new string('A', 101) // Exceeds 100 character limit
        };
        var context = new ValidationContext(forecast) { MemberName = nameof(WeatherForecast.Summary) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(forecast.Summary, context, results);

        // Assert
        Assert.IsFalse(isValid, "Summary exceeding 100 characters should fail validation");
        Assert.IsNotEmpty(results, "Should have validation error");
    }

    [TestMethod]
    public void Summary_ExactlyMaxLength_ValidationPasses()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = 25,
            Summary = new string('A', 100) // Exactly at limit
        };
        var context = new ValidationContext(forecast) { MemberName = nameof(WeatherForecast.Summary) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(forecast.Summary, context, results);

        // Assert
        Assert.IsTrue(isValid, "Summary at exactly 100 characters should pass validation");
    }

    [TestMethod]
    public void FullObject_ValidProperties_ValidationPasses()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = 25,
            Summary = "Partly cloudy"
        };
        var context = new ValidationContext(forecast);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(forecast, context, results, validateAllProperties: true);

        // Assert
        Assert.IsTrue(isValid, "Valid forecast should pass full validation");
    }

    #endregion

    #region Edge Cases

    [TestMethod]
    public void TemperatureF_AbsoluteZeroCelsius_ReturnsCorrectFahrenheit()
    {
        // Arrange - Absolute zero is -273.15°C, we use -273 for int
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = -273
        };

        // Act
        var result = forecast.TemperatureF;

        // Assert
        // -273 * 1.8 + 32 = -491.4 + 32 = -459.4 → truncated to -459
        Assert.AreEqual(-459, result);
    }

    [TestMethod]
    public void TemperatureF_NegativeTemperature_ReturnsNegativeFahrenheit()
    {
        // Arrange
        var forecast = new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.UtcNow),
            TemperatureC = -20
        };

        // Act
        var result = forecast.TemperatureF;

        // Assert
        // -20 * 1.8 + 32 = -36 + 32 = -4
        Assert.AreEqual(-4, result);
    }

    #endregion
}
