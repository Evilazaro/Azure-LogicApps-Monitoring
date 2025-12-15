$AZURE_SUBSCRIPTION_ID=$0
$env:AZURE_RESOURCE_GROUP=$1
$env:AZURE_LOCATION=$2

write-Information "Post-provisioning script started." -InformationAction Continue

$projectPath = ".\eShopOrders.AppHost\eShopOrders.AppHost.csproj"
write-Information "Configuring user secrets for project at $projectPath" -InformationAction Continue
dotnet user-secrets clear -p $projectPath
dotnet user-secrets set "Azure:AllowResourceGroupCreation" false -p $projectPath
dotnet user-secrets set "Azure:SubscriptionId" $env:AZURE_SUBSCRIPTION_ID -p $projectPath
dotnet user-secrets set "Azure:ResourceGroupName" $env:AZURE_RESOURCE_GROUP -p $projectPath
dotnet user-secrets set "Azure:Location" $env:AZURE_LOCATION -p $projectPath
dotnet user-secrets set "Azure:CredentialSource" AzureDeveloperCli -p $projectPath