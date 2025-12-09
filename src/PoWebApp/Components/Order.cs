namespace PoWebApp.Components
{
    public class Order
    {
        public int Id { get; set; }
        public DateTime Date { get; set; }
        public int Quantity { get; set; }
        public double Total { get; set; }
        public string Message { get; set; }
    }
}
