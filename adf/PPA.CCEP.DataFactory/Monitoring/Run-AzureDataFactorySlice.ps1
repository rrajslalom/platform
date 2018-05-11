[cmdletbinding()]
param (
   $TenantId = 'bcace1c8-076d-40ee-818d-41c366765fdd'
   ,$ResourceGroupName = '138-CCEP-DevInt-AppData'
   ,$DataSets = @(
        "T_AzureSql_PORTFOLIO_PERFORMANCE_Web"
        ,"T_AzureSql_ACCOUNT_CONTACTS_Web"   
        ,"T_AzureSql_WASH_SALE_COORDINATED_Web"
        ,"T_AzureSql_ADVISORS_Web"   
        ,"T_AzureSql_PORTFOLIO_CHARACTERISTICS_Web"
        ,"T_AzureSql_SALES_REPRESENTATIVES_Web"
        ,"T_AzureSql_REALIZED_GAINS_LOSSES_Web"
        ,"T_AzureSql_TOP_HOLDINGS_Web"
        ,"T_AzureSql_DIVIDEND_SWEPT_Web"
        ,"T_AzureSql_SECTOR_WEIGHTS_Web"
        ,"T_AzureSql_MARKET_COMMENTARY_Web"
        ,"T_AzureSql_PORTFOLIO_VALUE_Web"
        ,"T_AzureSql_COUNTRY_EXPOSURE_Web"
        ,"T_AzureSql_ACCOUNT_INFO_Web"
        ,"T_AzureSql_ACCOUNT_SUMMARY_Web"
   )
   ,[switch] $ReRunFailedSliceOnly = $false
)
trap {
    throw $_
}
$ErrorActionPreference = "Stop"
Import-Module AzureRM

function LoginAzureRMAccount {
    param (
        [parameter(mandatory=$true)] $tenantId 
    )
    begin {}
    process {
        if (-not $loggedin -or (Get-AzureRmTenant).TenantId -ne $TenantId){
            Login-AzureRmAccount -TenantId $TenantId
        }
    }
}


function UnpauseAzurePipelines {
    param (
        [parameter(mandatory=$true)] $Activities
        ,[parameter(mandatory=$true)] $dataFactory
        
    )
    begin {
        $Activity = $Activites |?{$_.OutputDatasets -contains $dataset.DataSetName }
        $pipeline = Get-AzureRmDataFactoryPipeline $datafactory -Name $Activity.pipelinename
        $pipelineDetails = $pipeline|Select -ExpandProperty properties
    }
    process {
        if ($pipelineDetails.ispaused -eq "True"){
            Resume-AzureRmDataFactoryPipeline -DataFactory $datafactory -Name $Activity.pipelinename -Confirm
        }
    }
}


function GetRecentDataSlice {
    param (
        [parameter(mandatory=$true)] $dataFactory
        ,[parameter(mandatory=$true)] $dataSetName
        ,[switch] $FailedSliceOnly
        
    )
    begin {
        $props = @{
            DataFactory   = $datafactory
            DatasetName   = $DataSetName 
            StartDateTime = (get-date).AddMonths(-1).ToUniversalTime()
            EndDateTime   = (get-date).ToUniversalTime()
        }
    }
    process {
        $slice = Get-AzureRmDataFactorySlice @props
        if ($FailedSliceOnly){
            $recentSlice = $slice |Where-Object {$_.State -eq "Failed" }|Sort-Object -Property End -Descending|Select-Object -First 1
        }
        else {
            $recentSlice = $slice |Where-Object {$_.End -lt (get-date).ToUniversalTime() }
        }
        $props.StartDateTime = $recentSlice.Start
        $props.EndDateTime   = $recentSlice.End
    }
    end {
        return $props
    }
}


function GetAzureDatafactorySliceRun {
    param (
        [parameter(mandatory=$true)] $dataFactory
        ,[parameter(mandatory=$true)] $slice
    )
    begin {
        if ($slice.StartDateTime -eq $null -or $slice.EndDateTime -eq $null){
            throw "No slices to run! Dataset name = $($slice.DataSetName)"
        }
    }
    process {
        $props = @{
            DataSetName   = $slice.DatasetName
            EndDateTime   = $slice.EndDateTime
            StartDateTime = $slice.StartDateTime 
            UpdateType    = "UpstreamInPipeline"
            Status        = "Waiting"
        }
    }
    end {
        return $props
    }
}
LoginAzureRMAccount $TenantId

$DataFactory = Get-AzureRmDataFactory -ResourceGroupName $ResourceGroupName
$allDataDsets = Get-AzureRmDataFactoryDataset -DataFactory $datafactory
$stringDatasetsToRun = [string]::join("|" ,$DataSets)
$DataSetstoRun = $allDataDsets |Where-Object {$_.DatasetName -match $stringDatasetsToRun}
$Activities = Get-AzureRmDataFactoryActivityWindow -DataFactory $datafactory


foreach ($dataSet in $datasetsToRun){
    
    UnpauseAzurePipelines $Activities $DataFactory

    if (-not $ReRunFailedSliceOnly) {
        $slice = GetRecentDataSlice -dataFactory $DataFactory -dataSetName $dataset.DataSetName
    }
    else {
        $slice = GetRecentDataSlice -dataFactory $DataFactory -dataSetName $dataset.DataSetName -FailedSliceOnly
    }

    $props = GetAzureDatafactorySliceRun $DataFactory $slice
    
    $result = Set-AzureRmDataFactorySliceStatus $DataFactory @props
    if ($result -ne "True"){
        throw "Pipeline operation not successful. See exception details. Dataset name = $($props.DataSetName)"
    } 
    else {
        $props
    }
}