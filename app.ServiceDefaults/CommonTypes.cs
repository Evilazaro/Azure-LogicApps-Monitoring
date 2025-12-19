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
        public DateTime Date { get; init; }
        public int Quantity { get; init; }
        public decimal Total { get; init; }
        public string Message { get; init; } = string.Empty;
    }

}
