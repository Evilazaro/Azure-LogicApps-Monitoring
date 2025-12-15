using System.Text.Json.Serialization;

namespace eShop.Orders.API.Controllers
{
    public class Order
    {
        [JsonPropertyName("Id")]
        public int Id { get; set; }

        [JsonPropertyName("Date")]
        public DateTime Date { get; set; }

        [JsonPropertyName("Quantity")]
        public int Quantity { get; set; }

        [JsonPropertyName("Total")]
        public double Total { get; set; }

        [JsonPropertyName("Message")]
        public string Message { get; set; } = string.Empty;
    }
}
