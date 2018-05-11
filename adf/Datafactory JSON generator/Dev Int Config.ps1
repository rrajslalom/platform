# Catch all exceptions
Trap {
	$message = "Exception encountered during execution `n" + $_.exception.message + "`n" + $_.ScriptStackTrace
	Write-Verbose -Verbose -Message $message
	Return
}
# everything is an exception
$ErrorActionPreference = 'Stop'

$sourceDatabase = "CCEP_UAT"
$sourceServer   = "SEA-4400-04"
$includeTablesNames = @(
    "ACCOUNT_INFO"
    ,"ACCOUNT_SUMMARY"
    ,"COUNTRY_EXPOSURE"
    ,"DIVIDEND_SWEPT"
    ,"MARKET_COMMENTARY"
    ,"PORTFOLIO_CHARACTERISTICS"
    ,"PORTFOLIO_PERFORMANCE"
    ,"PORTFOLIO_VALUE"
    ,"REALIZED_GAINS_LOSSES"
    ,"SECTOR_WEIGHTS"
    ,"TOP_HOLDINGS"
    ,"WASH_SALE_COORDINATED"
    ,"ACCOUNT_CONTACTS"
	,"CURRENT_REPORTING_YEAR_QUARTER"
)
$SourceSchemaName = 'CustomCoreStage'
$DestSchemaName   = 'CustomCoreWeb'

$now = (Get-date ).ToUniversalTime()

# pipelines configured to run on the 11th of every month
$PipelineStartDateTime = Get-Date -format o (get-date "9/1/2016")
$PipelineEndDateTime   = Get-Date -format o (get-date "1/1/$($now.AddYears(2).Year)")

$sourceControlRoot = 'C:\Users\ChrisK\Source\Repos\CCEP2'
$commonFunctionsPath = Join-Path $sourceControlRoot -childpath "Datafactory JSON generator\CommonFunctions.ps1"
$OutputDirectory = Join-Path $sourceControlRoot "PPA.CCEP.DataFactory\DataFactory"


# load template files, each template is preconfigured for deployment, sans the table/column names
$pipelineTemplate                    = Get-Content "$sourceControlRoot\Datafactory JSON generator\ADF Templates\PipeLineTemplate.txt"
$OnPremtableTemplate                 = Get-Content "$sourceControlRoot\Datafactory JSON generator\ADF Templates\OnPremSql_Table_Template.txt"
$AzureSqlStageTableTemplate          = Get-Content "$sourceControlRoot\Datafactory JSON generator\ADF Templates\AzureSql_Stage_Table_Template.txt"
$AzureSqlStageTruncatedTableTemplate = Get-Content "$sourceControlRoot\Datafactory JSON generator\ADF Templates\AzureSql_StageTruncated_Table_Template.txt"
$AzureSqlWebTableTemplate            = Get-Content "$sourceControlRoot\Datafactory JSON generator\ADF Templates\AzureSql_Web_Table_Template.txt"

.$commonFunctionsPath

# this is where we load in the source schema so we know which tables to produce in Azure
# Could be refactored to source from an excel type file, or through another input function for different technologies
$tableSchema = Get-SqlDataSchema -server $sourceServer -database $sourceDatabase

$tables = $tableSchema |?{$includeTablesNames -contains $_.table_name }
$tableAndSchema    = $tables | select -Unique -Property TABLE_NAME,TABLE_SCHEMA
$tablecolumnSchema = $tables | Group-Object -Property table_name

$properties = @{
	PipelineStartDateTime               = $PipelineStartDateTime
	PipelineEndDateTime                 = $PipelineEndDateTime  
	pipelineTemplate                    = $pipelineTemplate                    
	OnPremtableTemplate                 = $OnPremtableTemplate                 
	AzureSqlStageTableTemplate          = $AzureSqlStageTableTemplate          
	AzureSqlStageTruncatedTableTemplate = $AzureSqlStageTruncatedTableTemplate 
	AzureSqlWebTableTemplate            = $AzureSqlWebTableTemplate            
	tableAndSchema                      = $tableAndSchema     
	tablecolumnSchema                   = $tablecolumnSchema 
	SourceSchemaName                    = $SourceSchemaName 
	DestSchemaName                      = $DestSchemaName  
    OutputDirectory                     = $OutputDirectory
}

& "$sourceControlRoot\Datafactory JSON generator\adf template tool.ps1" @properties

