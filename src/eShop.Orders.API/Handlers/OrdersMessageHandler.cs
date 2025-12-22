using app.ServiceDefaults.CommonTypes;
using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Services.Interfaces;

namespace eShop.Orders.API.Handlers
{
    public class OrdersMessageHandler
    {
        private readonly ServiceBusClient _client;

        public OrdersMessageHandler(ServiceBusClient client)
        {
            _client = client;
        }

    }
}
