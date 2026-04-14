// =============================================================================
// FluentDesignSystem Unit Tests
// Tests for the design system constants and configuration
// =============================================================================

using eShop.Web.App.Shared;

namespace eShop.Web.App.Tests.Shared;

[TestClass]
public sealed class FluentDesignSystemTests
{
    #region Spacing Tests

    [TestMethod]
    [DataRow(nameof(FluentDesignSystem.Spacing.XSmall), "4")]
    [DataRow(nameof(FluentDesignSystem.Spacing.Small), "8")]
    [DataRow(nameof(FluentDesignSystem.Spacing.Medium), "12")]
    [DataRow(nameof(FluentDesignSystem.Spacing.Large), "16")]
    [DataRow(nameof(FluentDesignSystem.Spacing.XLarge), "20")]
    [DataRow(nameof(FluentDesignSystem.Spacing.XXLarge), "24")]
    [DataRow(nameof(FluentDesignSystem.Spacing.XXXLarge), "32")]
    public void Spacing_HasExpectedValues(string propertyName, string expectedValue)
    {
        // Arrange
        var actualValue = GetSpacingValue(propertyName);

        // Assert
        Assert.AreEqual(expectedValue, actualValue, $"Spacing.{propertyName} should be {expectedValue}");
    }

    [TestMethod]
    public void Spacing_ValuesAreInAscendingOrder()
    {
        // Arrange
        var spacingValues = new[]
        {
            int.Parse(GetSpacingValue(nameof(FluentDesignSystem.Spacing.XSmall))),
            int.Parse(GetSpacingValue(nameof(FluentDesignSystem.Spacing.Small))),
            int.Parse(GetSpacingValue(nameof(FluentDesignSystem.Spacing.Medium))),
            int.Parse(GetSpacingValue(nameof(FluentDesignSystem.Spacing.Large))),
            int.Parse(GetSpacingValue(nameof(FluentDesignSystem.Spacing.XLarge))),
            int.Parse(GetSpacingValue(nameof(FluentDesignSystem.Spacing.XXLarge))),
            int.Parse(GetSpacingValue(nameof(FluentDesignSystem.Spacing.XXXLarge)))
        };

        // Act & Assert
        for (int i = 1; i < spacingValues.Length; i++)
        {
            Assert.IsGreaterThan(spacingValues[i - 1], spacingValues[i],
                $"Spacing value at index {i} ({spacingValues[i]}) should be greater than {spacingValues[i - 1]}");
        }
    }

    private static string GetSpacingValue(string propertyName) => propertyName switch
    {
        nameof(FluentDesignSystem.Spacing.XSmall) => FluentDesignSystem.Spacing.XSmall,
        nameof(FluentDesignSystem.Spacing.Small) => FluentDesignSystem.Spacing.Small,
        nameof(FluentDesignSystem.Spacing.Medium) => FluentDesignSystem.Spacing.Medium,
        nameof(FluentDesignSystem.Spacing.Large) => FluentDesignSystem.Spacing.Large,
        nameof(FluentDesignSystem.Spacing.XLarge) => FluentDesignSystem.Spacing.XLarge,
        nameof(FluentDesignSystem.Spacing.XXLarge) => FluentDesignSystem.Spacing.XXLarge,
        nameof(FluentDesignSystem.Spacing.XXXLarge) => FluentDesignSystem.Spacing.XXXLarge,
        _ => throw new ArgumentException($"Unknown spacing property: {propertyName}")
    };

    #endregion

    #region FontSizes Tests

    [TestMethod]
    [DataRow(nameof(FluentDesignSystem.FontSizes.Caption), "11px")]
    [DataRow(nameof(FluentDesignSystem.FontSizes.Body), "13px")]
    [DataRow(nameof(FluentDesignSystem.FontSizes.BodyLarge), "14px")]
    [DataRow(nameof(FluentDesignSystem.FontSizes.Subtitle), "15px")]
    [DataRow(nameof(FluentDesignSystem.FontSizes.Title), "16px")]
    [DataRow(nameof(FluentDesignSystem.FontSizes.LargeTitle), "18px")]
    public void FontSizes_HasExpectedValues(string propertyName, string expectedValue)
    {
        // Arrange
        var actualValue = GetFontSizeValue(propertyName);

        // Assert
        Assert.AreEqual(expectedValue, actualValue, $"FontSizes.{propertyName} should be {expectedValue}");
    }

    [TestMethod]
    public void FontSizes_AllValuesEndWithPx()
    {
        // Arrange
        var fontSizeProperties = new[]
        {
            nameof(FluentDesignSystem.FontSizes.Caption),
            nameof(FluentDesignSystem.FontSizes.Body),
            nameof(FluentDesignSystem.FontSizes.BodyLarge),
            nameof(FluentDesignSystem.FontSizes.Subtitle),
            nameof(FluentDesignSystem.FontSizes.Title),
            nameof(FluentDesignSystem.FontSizes.LargeTitle)
        };

        // Act & Assert
        foreach (var propertyName in fontSizeProperties)
        {
            var fontSize = GetFontSizeValue(propertyName);
            Assert.IsTrue(fontSize.EndsWith("px", StringComparison.Ordinal),
                $"Font size '{propertyName}' with value '{fontSize}' should end with 'px'");
        }
    }

    private static string GetFontSizeValue(string propertyName) => propertyName switch
    {
        nameof(FluentDesignSystem.FontSizes.Caption) => FluentDesignSystem.FontSizes.Caption,
        nameof(FluentDesignSystem.FontSizes.Body) => FluentDesignSystem.FontSizes.Body,
        nameof(FluentDesignSystem.FontSizes.BodyLarge) => FluentDesignSystem.FontSizes.BodyLarge,
        nameof(FluentDesignSystem.FontSizes.Subtitle) => FluentDesignSystem.FontSizes.Subtitle,
        nameof(FluentDesignSystem.FontSizes.Title) => FluentDesignSystem.FontSizes.Title,
        nameof(FluentDesignSystem.FontSizes.LargeTitle) => FluentDesignSystem.FontSizes.LargeTitle,
        _ => throw new ArgumentException($"Unknown font size property: {propertyName}")
    };

    #endregion

    #region FontWeights Tests

    [TestMethod]
    [DataRow(nameof(FluentDesignSystem.FontWeights.Regular), "400")]
    [DataRow(nameof(FluentDesignSystem.FontWeights.SemiBold), "600")]
    [DataRow(nameof(FluentDesignSystem.FontWeights.Bold), "700")]
    public void FontWeights_HasExpectedValues(string propertyName, string expectedValue)
    {
        // Arrange
        var actualValue = GetFontWeightValue(propertyName);

        // Assert
        Assert.AreEqual(expectedValue, actualValue, $"FontWeights.{propertyName} should be {expectedValue}");
    }

    [TestMethod]
    public void FontWeights_ValuesAreValidCssFontWeights()
    {
        // Arrange
        var fontWeightProperties = new[]
        {
            nameof(FluentDesignSystem.FontWeights.Regular),
            nameof(FluentDesignSystem.FontWeights.SemiBold),
            nameof(FluentDesignSystem.FontWeights.Bold)
        };

        // Act & Assert
        foreach (var propertyName in fontWeightProperties)
        {
            var weight = GetFontWeightValue(propertyName);
            Assert.IsTrue(int.TryParse(weight, out int parsedWeight),
                $"Font weight '{propertyName}' with value '{weight}' should be a valid integer");
            Assert.IsTrue(parsedWeight >= 100 && parsedWeight <= 900,
                $"Font weight {parsedWeight} should be between 100 and 900");
            Assert.AreEqual(0, parsedWeight % 100,
                $"Font weight {parsedWeight} should be a multiple of 100");
        }
    }

    private static string GetFontWeightValue(string propertyName) => propertyName switch
    {
        nameof(FluentDesignSystem.FontWeights.Regular) => FluentDesignSystem.FontWeights.Regular,
        nameof(FluentDesignSystem.FontWeights.SemiBold) => FluentDesignSystem.FontWeights.SemiBold,
        nameof(FluentDesignSystem.FontWeights.Bold) => FluentDesignSystem.FontWeights.Bold,
        _ => throw new ArgumentException($"Unknown font weight property: {propertyName}")
    };

    #endregion

    #region MaxWidths Tests

    [TestMethod]
    [DataRow(nameof(FluentDesignSystem.MaxWidths.Small), "800px")]
    [DataRow(nameof(FluentDesignSystem.MaxWidths.Medium), "1000px")]
    [DataRow(nameof(FluentDesignSystem.MaxWidths.Large), "1400px")]
    public void MaxWidths_HasExpectedValues(string propertyName, string expectedValue)
    {
        // Arrange
        var actualValue = GetMaxWidthValue(propertyName);

        // Assert
        Assert.AreEqual(expectedValue, actualValue, $"MaxWidths.{propertyName} should be {expectedValue}");
    }

    [TestMethod]
    public void MaxWidths_AllValuesEndWithPx()
    {
        // Arrange
        var maxWidthProperties = new[]
        {
            nameof(FluentDesignSystem.MaxWidths.Small),
            nameof(FluentDesignSystem.MaxWidths.Medium),
            nameof(FluentDesignSystem.MaxWidths.Large)
        };

        // Act & Assert
        foreach (var propertyName in maxWidthProperties)
        {
            var width = GetMaxWidthValue(propertyName);
            Assert.IsTrue(width.EndsWith("px", StringComparison.Ordinal),
                $"Max width '{propertyName}' with value '{width}' should end with 'px'");
        }
    }

    private static string GetMaxWidthValue(string propertyName) => propertyName switch
    {
        nameof(FluentDesignSystem.MaxWidths.Small) => FluentDesignSystem.MaxWidths.Small,
        nameof(FluentDesignSystem.MaxWidths.Medium) => FluentDesignSystem.MaxWidths.Medium,
        nameof(FluentDesignSystem.MaxWidths.Large) => FluentDesignSystem.MaxWidths.Large,
        _ => throw new ArgumentException($"Unknown max width property: {propertyName}")
    };

    #endregion

    #region Padding Tests

    [TestMethod]
    [DataRow(nameof(FluentDesignSystem.Padding.Small), "16px")]
    [DataRow(nameof(FluentDesignSystem.Padding.Medium), "20px")]
    [DataRow(nameof(FluentDesignSystem.Padding.Large), "24px")]
    public void Padding_HasExpectedValues(string propertyName, string expectedValue)
    {
        // Arrange
        var actualValue = GetPaddingValue(propertyName);

        // Assert
        Assert.AreEqual(expectedValue, actualValue, $"Padding.{propertyName} should be {expectedValue}");
    }

    [TestMethod]
    public void Padding_AllValuesEndWithPx()
    {
        // Arrange
        var paddingProperties = new[]
        {
            nameof(FluentDesignSystem.Padding.Small),
            nameof(FluentDesignSystem.Padding.Medium),
            nameof(FluentDesignSystem.Padding.Large)
        };

        // Act & Assert
        foreach (var propertyName in paddingProperties)
        {
            var padding = GetPaddingValue(propertyName);
            Assert.IsTrue(padding.EndsWith("px", StringComparison.Ordinal),
                $"Padding '{propertyName}' with value '{padding}' should end with 'px'");
        }
    }

    private static string GetPaddingValue(string propertyName) => propertyName switch
    {
        nameof(FluentDesignSystem.Padding.Small) => FluentDesignSystem.Padding.Small,
        nameof(FluentDesignSystem.Padding.Medium) => FluentDesignSystem.Padding.Medium,
        nameof(FluentDesignSystem.Padding.Large) => FluentDesignSystem.Padding.Large,
        _ => throw new ArgumentException($"Unknown padding property: {propertyName}")
    };

    #endregion

    #region DataGridColumns Tests

    [TestMethod]
    [DataRow(nameof(FluentDesignSystem.DataGridColumns.ProductsGrid), "100px 1fr 80px 120px 120px")]
    [DataRow(nameof(FluentDesignSystem.DataGridColumns.OrdersHeader), "20px 90px 110px 150px 1fr 100px 32px")]
    public void DataGridColumns_HasExpectedValues(string propertyName, string expectedValue)
    {
        // Arrange
        var actualValue = GetDataGridColumnsValue(propertyName);

        // Assert
        Assert.AreEqual(expectedValue, actualValue, $"DataGridColumns.{propertyName} should be {expectedValue}");
    }

    [TestMethod]
    [DataRow(nameof(FluentDesignSystem.DataGridColumns.ProductsGrid), 5)]
    [DataRow(nameof(FluentDesignSystem.DataGridColumns.OrdersHeader), 7)]
    public void DataGridColumns_HasCorrectColumnCount(string propertyName, int expectedCount)
    {
        // Arrange
        var columns = GetDataGridColumnsValue(propertyName).Split(' ');

        // Assert
        Assert.HasCount(expectedCount, columns, $"DataGridColumns.{propertyName} should have {expectedCount} columns");
    }

    private static string GetDataGridColumnsValue(string propertyName) => propertyName switch
    {
        nameof(FluentDesignSystem.DataGridColumns.ProductsGrid) => FluentDesignSystem.DataGridColumns.ProductsGrid,
        nameof(FluentDesignSystem.DataGridColumns.OrdersHeader) => FluentDesignSystem.DataGridColumns.OrdersHeader,
        _ => throw new ArgumentException($"Unknown data grid columns property: {propertyName}")
    };

    #endregion
}
