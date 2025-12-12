using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace eShopOrders.AppHost
{
    public static class Constants
    {
        public const string APPLICATIONINSIGHTS_CONNECTION_STRING = "{{ .Env.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING }}";
    }
}
