[cmdletbinding()]
param (
   $TenantId           = "bcace1c8-076d-40ee-818d-41c366765fdd"
   ,$ResourceGroupName = "138-CCEP-DevInt-AppData"
   ,$TemplateFilePath  = ".\CCEP-ADFAlertFailedSlice.json"
   ,$emailRecipient    = "cking@paraport.com"
   ,$AzureLocation     = "West US"
)
trap {
    write-error $_
    return
}
import-module AzureRm
if (!$loggedin){
    $loggedin = Login-AzureRmAccount -TenantId $TenantId
}

$configValues = @{
	'%location%' = $AzureLocation 
	'%email%'    = $webConnectionString     
}
$file = Get-ChildItem -Path $TemplateFilePath
$script = Get-Content $file.FullName
$configValues.GetEnumerator() | ForEach-Object {
	$script = $script -replace $_.Key, $_.Value
}
$MonitoringConfigFilePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath $file.name
Set-Content -path $MonitoringConfigFilePath -Value $script
Write-Verbose -Verbose -Message "Deploying $MonitoringConfigFilePath"
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $MonitoringConfigFilePath
Remove-Item -Path $MonitoringConfigFilePath