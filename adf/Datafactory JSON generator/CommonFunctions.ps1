Function SqlQuery {
    [CmdletBinding()]
    param(
		[parameter(mandatory=$true)][string]$queryText,
		[parameter(mandatory=$true)][string] $server,
		[parameter(mandatory=$true)][string] $database
    )
    process{
        Import-Module SQLPS
        $result = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $queryText
    }
    end{
        return $result
    }
}


Function Get-SqlDataSchema {
    [CmdletBinding()]
    param(
		[parameter(mandatory=$false)][string] $tableName,
		[parameter(mandatory=$true)][string] $server,
		[parameter(mandatory=$true)][string] $database
	)
    process {
		IF ($tableName){
			$queryText = "Select T.TABLE_SCHEMA,C.TABLE_NAME,C.COLUMN_NAME
	                            , C.DATA_TYPE, C.IS_NULLABLE
	                            , C.CHARACTER_MAXIMUM_LENGTH
	                            , C.NUMERIC_PRECISION, CT.CONSTRAINT_NAME
                            FROM information_schema.tables AS T
                            JOIN information_schema.columns AS C
                            ON C.TABLE_NAME = T.TABLE_NAME
                            JOIN (
	                            SELECT Tab.TABLE_NAME AS TABLE_NAME
	                            ,Col.Column_Name AS CONSTRAINT_NAME 
	                            from INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS Tab
	                            JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE AS Col 
	                            ON Col.Constraint_Name = Tab.Constraint_Name
	                            AND Col.Table_Name = Tab.Table_Name
	                            WHERE Constraint_Type = 'PRIMARY KEY'
                            ) AS CT
                            ON T.TABLE_NAME = CT.TABLE_NAME
							where table_name = ''$tableName''"
		}
		ELSE{
			$queryText = "SELECT 'DBO' AS TABLE_SCHEMA
                        , v.name AS TABLE_NAME
                        , C.NAME AS COLUMN_NAME
                        , t.name AS DATA_TYPE
                        , C.IS_NULLABLE
                        , C.MAX_LENGTH AS CHARACTER_MAXIMUM_LENGTH
                        , C.precision AS NUMERIC_PRECISION
                        , C.scale AS NUMERIC_SCALE
                        , NULL AS CONSTRAINT_NAME
                        FROM sys.views v
                        JOIN sys.columns c
                        ON v.object_id = c.object_id 
                        JOIN sys.types t
                        ON c.system_type_id = t.system_type_id"
		}
		$schema = SqlQuery -server $server -database $database -queryText $queryText
    }
    end {
        RETURN $schema
    }
}


function FilterFileList {
    param (
        $tableName
        ,$includeList
    )
    
    $includeList|%{
            if ($tableName -match $_) {
            return $tableName
        }
    }
}


function getDecryptedPasswordCredential {
	param (
			$credential
	)
	begin {}
	process {
		$password = $credential.password
		$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
		$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
		$newCred = $credential | Add-Member -NotePropertyName PlainPassword -NotePropertyValue $PlainPassword -Force -PassThru
	}
	end {
		return $newCred
	}
}

function getAuthentication {
	param (
		$authType
		,$serverName
		,$username
	)
	begin {}
	process {
		switch -Regex ($authType) {
			'(sql)' {
				$credentials = Get-Credential -Message "Enter credntials for $($serverName)" -UserName $username
				$credentials = getDecryptedPasswordCredential $credentials
			}
			'(windows)|(integrated)' {}
		}
	}
	end {
		return $credentials
	}
}