#
#  Azure Data Factory - Table and Pipeline template generator
#  Produces JSON files in '.\ADF Script\' from templates in '.\ADF Templates\'
#
#  2016 - Chris King (Slalom)
#
################################################################################################
param (
	$PipelineStartDateTime 
	,$PipelineEndDateTime   
	,$pipelineTemplate                    
	,$OnPremtableTemplate                 
	,$AzureSqlStageTableTemplate          
	,$AzureSqlStageTruncatedTableTemplate 
	,$AzureSqlWebTableTemplate            
	,$SourceSchemaName
	,$DestSchemaName  
	,$tableAndSchema   
	,$tablecolumnSchema
    ,$OutputDirectory
)
# Catch all exceptions
Trap {
	$message = "Exception encountered during execution `n" + $_.exception.message + "`n" + $_.ScriptStackTrace
	Write-Verbose -Verbose -Message $message
	Return
}
# everything is an exception
$ErrorActionPreference = 'Stop'


Function New-ADFTableJSON {
    [CmdletBinding()]
    param (
        [parameter(mandatory=$true)]$tableTemplate,
        [parameter(mandatory=$true)]$tableSchema,
        [parameter(mandatory=$true)]$schemaName
    )
    process{

        ForEach ($table in $tableSchema) {
            $lookupTable = @{
                '%Table_Name%' = $table.TABLE_NAME;
                '%Table_Schema%' = $schemaName;
            }
            $TableFile = $tableTemplate
            $lookupTable.GetEnumerator() | ForEach-Object {
                $TableFile = $TableFile -replace $_.Key, $_.Value
            }
            
        }
    }
    end {
        return $TableFile
    }
}

Function New-ADFPipelineJSON {
    [CmdletBinding()]
    param (
        [parameter(mandatory=$true)]$PipelineTemplate,
        [parameter(mandatory=$true)]$tablecolumnSchema,
		[parameter(mandatory=$true)]$PipelineStartDateTime,
		[parameter(mandatory=$true)]$PipelineEndDateTime,
        [parameter(mandatory=$true)]$StageSchemaName,
        [parameter(mandatory=$true)]$DestSchemaName
    )
    
    process {
        ForEach ($table in $tablecolumnSchema) {
			$expandedTableSchema = $table | Select-Object -ExpandProperty group
            $columns = $expandedTableSchema | Select-Object -Unique -ExpandProperty column_name
            $sourceSchemaName = $expandedTableSchema | Select-Object -Unique -ExpandProperty table_schema
            $columnList = [System.String]::Join(",",$columns)
            $lookupTable = @{
                '%source_Table_Name%'    = $table.name;
                '%source_Schema_name%'   = $sourceSchemaName;
                '%stage_Schema_name%'    = $stageSchemaName;
                '%dest_Schema_name%'     = $DestSchemaName
                '%dest_table_name%'      = $table.name.Replace('VW_','');
                '%table_columns%'        = $columnList;
				'%start_time%'           = $PipelineStartDateTime;
				'%end_time%'             = $PipelineEndDateTime;
				'%activity_time_out%'    = '0.15:00:00';
				'%retry_count%'          = '0';
            }
            $PipelineFile = $PipelineTemplate
            $lookupTable.GetEnumerator() | ForEach-Object {
                $PipelineFile = $PipelineFile -replace $_.Key, $_.Value
            }
            
        }
    } 
    end {
        return $PipelineFile
    }
}


function Generate-AdfTableJsonScript {
	param (
		$Type,
		$table,
		$Template,
        $schemaName
	)
	begin {
		[string] $SourceName = $table.table_Name
        [string] $tableName = $SourceName.replace('VW_','')
	}
	process {
		switch ($type) {
				OnPremTableJson {
					$TableName = "$OutputDirectory\T_OnPremSql_${tableName}.json"
                }
				AzureSqlStageTableJson {
					$TableName = "$OutputDirectory\T_AzureSql_${tableName}_Stage.json"
                }
				AzureSqlStageTruncatedTable {
					$TableName = "$OutputDirectory\T_AzureSql_${tableName}_StageTruncated.json"
                }
				AzureSqlWebTable {
					$TableName = "$OutputDirectory\T_AzureSql_${tableName}_Web.json" 
                }
		}
	}
	end {
		$TableJSon = New-ADFTableJSON -tableTemplate $Template -tableSchema $table -schemaName $schemaName
		Write-Verbose -Verbose -Message "Saving $TableName"
		Set-Content -Value $TableJSon -Path $TableName
	}
}



# We have to iterate over the schema definition for table in the  the azure pipeline, so on prem, them a truncated
# stage table, load stage table, and a loaded web table.  

foreach ($table in $tableAndSchema) {

	# generate on premise SQl table definition scripts
    Generate-AdfTableJsonScript -Type OnPremTableJson -table $table -Template $OnPremtableTemplate -schemaName 'DBO'
    
    # generate Azure SQl stage table definition scripts
	Generate-AdfTableJsonScript -Type AzureSqlStageTableJson -table $table -Template $AzureSqlStageTableTemplate -schemaName $SourceSchemaName
  
    # generate on Azure SQl Stage Truncated table definition scripts
    Generate-AdfTableJsonScript -Type AzureSqlStageTruncatedTable -table $table -Template $AzureSqlStageTruncatedTableTemplate -schemaName $SourceSchemaName
     
    # generate on Azure SQl Web table definition scripts
    Generate-AdfTableJsonScript -Type AzureSqlWebTable -table $table -Template $AzureSqlWebTableTemplate -schemaName $DestSchemaName
 }

foreach ($tableref in $tablecolumnSchema) {
    # generate copy pipleine definition scripts
    $props = @{
		PipelineTemplate = $pipelineTemplate;
		tablecolumnSchema = $tableref;
		pipelineStartDateTime = $pipelineStartDateTime;
		PipelineEndDateTime = $PipelineEndDateTime;
        StageSchemaName = $SourceSchemaName;
        DestSchemaName   = $DestSchemaName  ;
	}
    $PipelineJson = New-Object -TypeName psobject -Property @{
        PipelineName = 'P_Copy_'+$tableref.name; 
        PipelineJSon = New-ADFPipelineJSON @props
    }
    $props = @{
        Path = "$OutputDirectory\$($PipelineJson.PipelineName.replace('VW_','')).json";
        Value = $PipelineJson.PipelineJson;
    }
    Write-Verbose -Verbose -Message "Saving $($props.path)"
    Set-Content @props
}

