$appHostProjectPath=".\app.AppHost\"
$eShopOrdersApiProjectPath=".\src\eShop.Orders.API\"
$eShopWebAppProjectPath=".\src\eShop.Web.App\"

dotnet user-secrets clear -p $appHostProjectPath
dotnet user-secrets clear -p $eShopOrdersApiProjectPath
dotnet user-secrets clear -p $eShopWebAppProjectPath