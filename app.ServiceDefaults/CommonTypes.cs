namespace app.ServiceDefaults.CommonTypes
{
    public class WeatherForecast
    {
        public DateOnly Date { get; set; }

        public int TemperatureC { get; set; }

        public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);

        public string? Summary { get; set; }
    }

    public record Order
    {
        public string Id { get; init; } = string.Empty;
        public string CustomerId { get; init; } = string.Empty;
        public DateTime Date { get; init; }
        public string DeliveryAddress { get; init; } = string.Empty;
        public decimal Total { get; init; }
        public List<OrderProduct> Products { get; init; } = new();
    }

    public record OrderProduct
    {
        public string Id { get; init; } = string.Empty;
        public string OrderId { get; init; } = string.Empty;
        public string ProductId { get; init; } = string.Empty;
        public string ProductDescription { get; init; } = string.Empty;
        public int Quantity { get; init; }
        public decimal Price { get; init; }
    }
}
