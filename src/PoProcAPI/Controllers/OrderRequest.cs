namespace PoProcAPI.Controllers
{
    public class OrderRequest
    {
        public string OrderId { get; set; } = string.Empty;
        public string CustomerId { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string? Description { get; set; }
    }
}