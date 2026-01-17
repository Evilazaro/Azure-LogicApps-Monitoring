namespace eShop.Web.App.Shared;

/// <summary>
/// Centralized Fluent UI design tokens and constants for consistent styling
/// </summary>
public static class FluentDesignSystem
{
    // Spacing Scale
    public static class Spacing
    {
        public const string XSmall = "4";
        public const string Small = "8";
        public const string Medium = "12";
        public const string Large = "16";
        public const string XLarge = "20";
        public const string XXLarge = "24";
        public const string XXXLarge = "32";
    }

    // Typography Sizes
    public static class FontSizes
    {
        public const string Caption = "11px";
        public const string Body = "13px";
        public const string BodyLarge = "14px";
        public const string Subtitle = "15px";
        public const string Title = "16px";
        public const string LargeTitle = "18px";
    }

    // Font Weights
    public static class FontWeights
    {
        public const string Regular = "400";
        public const string SemiBold = "600";
        public const string Bold = "700";
    }

    // Layout Constraints
    public static class MaxWidths
    {
        public const string Small = "800px";
        public const string Medium = "1000px";
        public const string Large = "1400px";
    }

    // Padding
    public static class Padding
    {
        public const string Small = "16px";
        public const string Medium = "20px";
        public const string Large = "24px";
    }

    // DataGrid Column Templates (harmonious proportions)
    public static class DataGridColumns
    {
        public const string ProductsGrid = "100px 1fr 80px 120px 120px";
        public const string OrdersHeader = "20px 90px 110px 150px 1fr 100px 32px";
    }
}