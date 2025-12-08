using Azure.Storage.Queues;

namespace PoWebApp.Components
{
    public class Orders
    {
        private readonly QueueServiceClient _queueServiceClient;

        // Inject via constructor
        public Orders(QueueServiceClient queueServiceClient)
        {
            _queueServiceClient = queueServiceClient;
        }

        public async Task AddOrderMessageToQueueAsync()
        {
            try
            {
                var queueName = "orders-queue";
                
                var orderNumber = Guid.NewGuid().ToString();
                var message = $"New order {orderNumber} placed at : {DateTime.UtcNow.ToString("o")}";

                var queueClient = _queueServiceClient.GetQueueClient(queueName);

                await queueClient.CreateIfNotExistsAsync();
                await queueClient.SendMessageAsync(message);
            }
            catch (Exception)
            {
                throw;
            }
        }
    }
}

