param (
    [parameter(mandatory=$false)] [string] $tenantId                = 'bcace1c8-076d-40ee-818d-41c366765fdd',
    [parameter(mandatory=$false)] [string] $DataFactoryName         = '138-CCEP-DevInt-AppData-DataFactory',
	[parameter(mandatory=$true)]  [string] $DMGName,
    [parameter(mandatory=$false)] [string] $ResourceGroupName       = '138-CCEP-DevInt-AppData',
    [parameter(mandatory=$false)] [string] $JsonScriptDir           = 'C:\Users\rashi.raj\Documents\CCEP.DataFactory\PPA.CCEP.DataFactory\DataFactory',
	[parameter(mandatory=$false)] [string] $stageConnectionString   = '',
	[parameter(mandatory=$false)] [string] $webConnectionString     = '',
	[parameter(mandatory=$false)] [string] $onPremConnectionString  = '',
	[parameter(mandatory=$false)] [string] $onPremUserName          = '',
	[parameter(mandatory=$false)] [string] $onPremPassword          = '',
    [parameter(mandatory=$false)] [switch] $cleanInstall            = $false,
	[parameter(mandatory=$false)] [switch] $pipelineOnly            = $false,
	[parameter(mandatory=$false)] [switch] $installLinkedServices   = $false,
    [parameter(mandatory=$false)] [array] $includeTablesNames       = @(
        "ACCOUNT_CONTACTS"
		"ACCOUNT_SUMMARY",
		"WASH_SALE_COORDINATED",
		"PORTFOLIO_PERFORMANCE",
		"TOP_HOLDINGS",
		"SECTOR_WEIGHTS",
		"DIVIDEND_SWEPT",
		"CURRENT_REPORTING_YEAR_QUARTER",
		"COUNTRY_EXPOSURE",
		"MARKET_COMMENTARY",
		"ACCOUNT_INFO",
		"REALIZED_GAINS_LOSSES",
		"PORTFOLIO_CHARACTERISTICS",
		"PORTFOLIO_VALUE",
		"FormTypes",
		"IndexCategories"
		"IndexCategoryMapping",
		"IndexConstituentMapping",
		"IndexReturns",
		"Indices",
		"RestrictionCategories",
		"Restrictions",
		"Securities",
		"SecurityRestrictionMapping",
		"SecuritySectors",
		"ThorSummaries",
		"ThorSummaryRowTypes",
		"ThorSummarySetTypes",
		"ThorSummaryValues",
		"ToolTypes"
    )        
)
# Catch all exceptions
Trap {
	$message = "Exception encountered during execution `n" + $_.exception.message + "`n" + $_.ScriptStackTrace
	Write-Verbose -Verbose -Message $message
	Return
}
# everything is an exception
$ErrorActionPreference = 'Stop'

if ((Get-Module).Name -notcontains 'AzureRM.datafactories') {
    import-module AzureRM.datafactories
}
if (-not($loggedIn)) {
    $loggedIn = Login-AzureRmAccount -TenantId  $tenantId
}

$DataFactory = Get-AzureRmDataFactory -ResourceGroupName $ResourceGroupName -Name $DataFactoryName
$DataFactoryScripts = Get-ChildItem -Path $JsonScriptDir -Filter *.json

$includeTablesNamesString = [System.String]::Join(")|(",$includeTablesNames)

if ($installLinkedServices) {
    $LinkedServiceTemplates = $DataFactoryScripts | Where-Object {$_.Name -match '^LS_'}
    $LinkedService = Get-AzureRmDataFactoryLinkedService -DataFactory $DataFactory
    $LinkedService | Remove-AzureRmDataFactoryLinkedService -Force
}

if ($cleanInstall) {
    $Pipeline = Get-AzureRmDataFactoryPipeline -DataFactory $DataFactory
    $Dataset  = Get-AzureRmDataFactoryDataset  -DataFactory $DataFactory

    $Pipeline = $Pipeline |?{$_.PipelineName -match "($includeTablesNamesString)" }
    $Dataset  = $Dataset  |?{$_.DatasetName  -match "($includeTablesNamesString)" }
    
    $Pipeline | Remove-AzureRmDataFactoryPipeline -Force
    $Dataset  | Remove-AzureRmDataFactoryDataset  -Force
}   

$DataFactoryScripts = $DataFactoryScripts |?{$_.fullname -match "($includeTablesNamesString)" }

if (-not($pipelineOnly)) {
    $TableScripts = $DataFactoryScripts | Where-Object {$_.Name -match '^T_'}
}
$PipelineScripts = $DataFactoryScripts | Where-Object {$_.Name -match '^P_'}

$configValues = @{
	'%stageConnectionString%'  = $stageConnectionString 
	'%webConnectionString%'    = $webConnectionString   
	'%onPremConnectionString%' = $onPremConnectionString
	'%onPremUserName%'         = $onPremUserName        
	'%onPremPassword%'         = $onPremPassword      
	'%DMGName%'                = $DMGName  
}

foreach ($file in $LinkedServiceTemplates){
	$script = Get-Content $file.fullname
	$configValues.GetEnumerator() | ForEach-Object {
		$script = $script -replace $_.Key, $_.Value
	}
	$LinkedServiceScript = Join-Path -Path $env:LOCALAPPDATA -ChildPath $file.name
	Set-Content -path $LinkedServiceScript -Value $script
    Write-Verbose -Verbose -Message "Deploying $LinkedServiceScript"
	$result = New-AzureRmDataFactoryLinkedService -DataFactory $DataFactory -File $LinkedServiceScript -Force
	Write-Verbose -Verbose -Message "$($LinkedServiceScript): $($result.ProvisioningState)"
    Remove-Item -Path $LinkedServiceScript
}

foreach ($TableScript in $TableScripts) {
	$Path = $TableScript.fullname
    Write-Verbose -Verbose -Message "$($Path): Deploying"
	$result = New-AzureRmDataFactoryDataset -DataFactory $DataFactory -File $Path -Force
    Write-Verbose -Verbose -Message "$($Path): $($result.ProvisioningState)"
}

foreach ($PipelineScript in $PipelineScripts) {
	$Path = $PipelineScript.fullname
    Write-Verbose -Verbose -Message "$($Path): Deploying"
	$result = New-AzureRmDataFactoryPipeline -DataFactory $DataFactory -File $Path -Force
    Write-Verbose -Verbose -Message "$($Path): $($result.ProvisioningState)"
}
