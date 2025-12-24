$appHostPath="$(Get-Item -Path $PSScriptRoot\..\app.AppHost\AppHost.cs).FullName"
dotnet user-secrets clear $appHostPath
dotnet user-secrets remove $appHostPath