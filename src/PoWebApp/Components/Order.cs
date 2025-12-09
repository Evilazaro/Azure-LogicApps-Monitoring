using System.Text.Json.Serialization;

namespace PoWebApp.Components
{
    public class Order
    {
        [JsonPropertyName("OrderId")]
        public int Id { get; set; }
        
        [JsonPropertyName("OrderDate")]
        public DateTime Date { get; set; }
        
        [JsonPropertyName("OrderQuantity")]
        public int Quantity { get; set; }
        
        [JsonPropertyName("OrderTotal")]
        public double Total { get; set; }
        
        [JsonPropertyName("OrderMessage")]
        public string Message { get; set; } = string.Empty;
    }
}
