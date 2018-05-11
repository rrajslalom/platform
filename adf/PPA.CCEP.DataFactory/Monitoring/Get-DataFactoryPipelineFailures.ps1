[cmdletbinding()]
param (
   $TenantId = 'bcace1c8-076d-40ee-818d-41c366765fdd'
   ,$ResourceGroupName = '138CCEP-DevInt'
)
trap {
    write-error $_
    return
}


Function Get-AzureRmDataFactoryFailedRuns {
	param (
		$dataFactory 
		,$Days = 1
	)
	$WarningPreference = 'SilentlyContinue'
	$RelativeStartTime = (get-date).adddays(-$Days).ToUniversalTime()
	$dataSets = Get-AzureRmDataFactoryDataSet -DataFactory $datafactory
	$slices = $dataSets | Get-AzureRmDataFactorySlice -StartDateTime $RelativeStartTime 
	$failedSlices = $slices|where-object{$_.state -match 'Failed'}
	$Runs = $failedSlices | Get-AzureRmDataFactoryRun -StartDateTime $RelativeStartTime
    $failedRuns = $Runs |Where-Object {$_.Status -match 'FailedExecution'}
    return $failedRuns
}


import-module AzureRm
if (!$loggedin){
    $loggedin = Login-AzureRmAccount -TenantId $TenantId
}

$datafactory = Get-AzureRmDataFactory -ResourceGroupName $ResourceGroupName
$Properties = @(
            'DataSliceStart'
            ,'DataSliceEnd'
            ,'ErrorMessage'
            ,'ActivityName'
            ,'PipelineName'
            )
$slices = Get-AzureRmDataFactoryFailedRuns $datafactory 1|Select-Object -Property $Properties
                                                                                                                                                                                           
return $slices
