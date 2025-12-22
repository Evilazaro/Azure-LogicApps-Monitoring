using app.ServiceDefaults.CommonTypes;
using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Interfaces;

namespace eShop.Orders.API.Handlers
{
    public class OrdersMessageHandler : IOrdersMessageHandler
    {
        private readonly ILogger _logger;
        private readonly ServiceBusClient _seviceBusClient;
        private readonly string _topicName = "OrdersPlaced";

        public OrdersMessageHandler(ILogger<IOrdersMessageHandler> logger, ServiceBusClient serviceBusClient)
        {
            _logger = logger;
            _seviceBusClient = serviceBusClient;
        }

        public async Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken)
        {
            var sender = _seviceBusClient.CreateSender(_topicName);
            var message = new ServiceBusMessage(System.Text.Json.JsonSerializer.Serialize(order));
            await sender.SendMessageAsync(message, cancellationToken);
        }

        public async Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken)
        {
            var sender = _seviceBusClient.CreateSender("orders-topic");
            var messages = orders.Select(order => new ServiceBusMessage(System.Text.Json.JsonSerializer.Serialize(order))).ToList();
            await sender.SendMessagesAsync(messages, cancellationToken);
        }
        public async Task CloseAsync()
        {
            await _seviceBusClient.DisposeAsync();
        }
    }
}
