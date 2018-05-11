Param(
    $TenantId = 'bcace1c8-076d-40ee-818d-41c366765fdd'
    ,$ResourceGroupName = '138CCEP-DevInt'
)


function Get-AzureDataFactoryLinkedServiceConnectionString {
    param (
        [parameter(ValueFromPipeline=$true)] $linkedServices
        ,$LS_Name
    )
    $expand0 = @{
        ExpandProperty = 'Properties'
    }
    $expand1 = @{
        ExpandProperty = 'TypeProperties'
    }
    $expand2 = @{
        ExpandProperty = 'connectionstring'
    }
    $config = $linkedServices|%{
        @{
            $_.LinkedServiceName = $_|Select-Object @expand0 |Select-Object @expand1|Select-Object @expand2
        }
    }
    if ($LS_Name) {
        $config[$LS_Name]
    }
    else{
        $config
    }
}

if((get-module | ?{$_.name -match 'AzureRM'}).Count -lt 1){
    import-module AzureRm
}
if (!$loggedin){
    $loggedin = Login-AzureRmAccount -TenantId $TenantId
}
if (!$datafactory){
    $datafactory = Get-AzureRmDataFactory -ResourceGroupName $ResourceGroupName
}

$linkedServices = Get-AzureRmDataFactoryLinkedService -DataFactory $datafactory 
Get-AzureDataFactoryLinkedServiceConnectionString -linkedServices $linkedServices