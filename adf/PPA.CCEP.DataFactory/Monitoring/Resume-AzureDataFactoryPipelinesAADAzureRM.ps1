param(
    $TenantID          = "bcace1c8-076d-40ee-818d-41c366765fdd",
    $ClientID          = "138b3aae-f4e4-4f0e-bc1e-fd4841029298",
    $ClientSecret      = "M59Ht1+bLmGXvOF0r7mIo6LoTIY6yulIb/U3vjxNsD0=",
    $subscriptionId    = "756c704a-1366-447c-ba04-6ce33b08d1bb",
    $ResourceGroupName = "138-CCEP-DevInt-AppData",
    [switch] $UseAccessToken = $true,
    [validateset('daily','quarterly','monthly')] $frequency = "quarterly",
	[array] $PipelinesToResume = @(
		"P_Copy_ACCOUNT_CONTACTS"
		"P_Copy_ACCOUNT_SUMMARY",
		"P_Copy_WASH_SALE_COORDINATED",
		"P_Copy_PORTFOLIO_PERFORMANCE",
		"P_Copy_TOP_HOLDINGS",
		"P_Copy_SECTOR_WEIGHTS",
		"P_Copy_DIVIDEND_SWEPT",
		"P_Copy_CURRENT_REPORTING_YEAR_QUARTER",
		"P_Copy_COUNTRY_EXPOSURE",
		"P_Copy_MARKET_COMMENTARY",
		"P_Copy_ACCOUNT_INFO",
		"P_Copy_REALIZED_GAINS_LOSSES",
		"P_Copy_PORTFOLIO_CHARACTERISTICS",
		"P_Copy_PORTFOLIO_VALUE",
		"P_Copy_FormTypes",
		"P_Copy_IndexCategories"
		"P_Copy_IndexCategoryMapping",
		"P_Copy_IndexConstituentMapping",
		"P_Copy_IndexReturns",
		"P_Copy_Indices",
		"P_Copy_RestrictionCategories",
		"P_Copy_Restrictions",
		"P_Copy_Securities",
		"P_Copy_SecurityRestrictionMapping",
		"P_Copy_SecuritySectors",
		"P_Copy_ThorSummaries",
		"P_Copy_ThorSummaryRowTypes",
		"P_Copy_ThorSummarySetTypes",
		"P_Copy_ThorSummaryValues",
		"P_Copy_ToolTypes",
		"P_UpdateDaily_ACCOUNT_INFO",
		"P_UpdateDaily_ACCOUNT_SUMMARY"
	)
)
trap {
    Write-Error $_
    exit 1
}
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

function getDateRange {
    param(
       [parameter(mandatory=$true)] $frequency 
    )
    begin {
        $today = get-date
        $hash = @{
            StartDate = $null
            EndDate   = $null  
        }
        $daterange = New-Object -TypeName psobject -Property $hash
    }
    process{
        switch ($frequency) {
            'daily' {
                $start = (get-date "$($today.year)-$($today.Month)-$($today.Day)")
                $daterange.startDate = $start.AddDays(-1)
                $daterange.EndDate   = $start
            }
            'monthly' {
				$MonthBeginDate = get-date "$($today.year)-$($today.Month)-01"
                $daterange.startDate = $MonthBeginDate.AddMonths(-1)
                $daterange.EndDate   = $daterange.startDate.AddMonths(1)
			}
            'quarterly' {
                $MonthBeginDate = get-date "$($today.year)-$($today.Month)-01"
                $daterange.startDate = $MonthBeginDate.AddMonths(-3)
                $daterange.EndDate   = $daterange.startDate.AddMonths(3)
            }
        }
    }
    end {
        return $daterange
    }
}


function getAccessToken {
    param(
        $client_id     ,
        $client_secret ,
        $TokenEndpoint
    )
    begin {
        $Authfields = @{
            grant_type     = "client_credentials"
            resource       = "https://management.core.windows.net/"
            client_id      = $client_id
            client_secret  = $client_secret
        }
    } 
    process {
        $responseToken = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -Body $Authfields
        $props = @{
            NotePropertyName  = "ExpiresOnDateTimeUTC"
            NotePropertyValue = (get-date "1970-1-1 0:0").addseconds($accessToken.expires_on)
        }
        $responseToken = $responseToken| Add-Member @props -PassThru
    }
    end {
        return $responseToken
    }
}


function log {
    param (
        $message
    )
    write-verbose -verbose -message "$(get-date): $($message)"
}


function checkAuthTOken {
    param(
        $authresponse
    )
     
    if ($authresponse.ExpiresOnDateTimeUtC -le (get-date).ToUniversalTime().AddMinutes(2)) {
        $authresponse  = getAccessToken @AuthObject
        $loggedIn      = Add-AzureRmAccount -AccessToken $authresponse.access_token -AccountId $clientid
    }
}


Import-Module -Name AzureRM.DataFactories

if ($UseAccessToken) {
    $AuthObject = @{
        client_id         = $ClientID
        client_secret     = $ClientSecret
        TokenEndpoint     = "https://login.microsoftonline.com/${TenantID}/oauth2/token"
    }
    $authresponse   = getAccessToken @AuthObject
    $loggedIn      = Add-AzureRmAccount -AccessToken $authresponse.access_token -AccountId $clientid
} 
else {
    Login-AzurermAccount -tenantid $tenantid -SubscriptionId $subscriptionId 
}

$dateRange     = getDateRange -frequency $frequency
$DataFactory   = Get-AzureRmDataFactory -ResourceGroupName $ResourceGroupName
$pipelines     = Get-AzureRmDataFactoryPipeline -DataFactory $DataFactory
$pipelines     = $pipelines | where-object {$PipelinesToResume -contains $_.PipelineName}
$datasets      = $pipelines.properties.activities.outputs
$dataSets      = $dataSets | Get-AzureRmDataFactoryDataset -DataFactory $DataFactory

$sliceParams = @{
    DataFactory   = $DataFactory
    StartDateTime = $dateRange.StartDate 
    EndDateTime   = $dateRange.EndDate
}

$slices        = $datasets | Get-AzureRmDataFactorySlice @sliceParams 
$slices        = $slices |?{$_.SubState -notmatch 'ScheduledTime'}

Log "DataFactoryName: $($DataFactory.DataFactoryName  )"
Log "ResourceGroupName: $($DataFactory.ResourceGroupName)"
Log "Slice Start Date: $($daterange.StartDate)"
Log "Slice Start Date: $($daterange.EndDate)"

log "Resetting slice status"

$pipelines | Suspend-AzureRmDataFactoryPipeline|out-null

$slices  | Set-AzureRmDataFactorySliceStatus @sliceParams -Status Waiting -UpdateType UpstreamInPipeline |out-null

$onPremSlices = $pipelines.properties.activities.inputs|where-object {$_.name -match 'onpremsql'} 
$onPremSlices = $onPremSlices | Get-AzureRmDataFactoryDataset -DataFactory $DataFactory
$onPremSlices | Set-AzureRmDataFactorySliceStatus @sliceParams -Status Ready -UpdateType Individual |out-null

do {
    log "waiting for slice status update"
    $slices = $datasets | Get-AzureRmDataFactorySlice @sliceParams
    start-sleep -seconds 10
}
While ($slices.State -notmatch "waiting")

log "----------------------------------------------------------"

$pipelines | Resume-AzureRmDataFactoryPipeline|out-null

do {
    $slices | %{log "$($_.DatasetName): $($_.State -match 'ready')"}
    
    if ($UseAccessToken) {
        checkAuthTOken $authresponse
    }

    if ($slices.State -contains 'failed'){
        throw "Failed slices"
    }
    if ($slices.State -notmatch 'Ready'){
        Start-Sleep -Seconds 60
        $slices = $datasets | Get-AzureRmDataFactorySlice @sliceParams
    }
    log "----------------------------------------------------------"
} 
While ($slices.State -notmatch 'Ready')

$pipelines | Suspend-AzureRmDataFactoryPipeline|out-null