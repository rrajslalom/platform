param(
    $TenantID          = "bcace1c8-076d-40ee-818d-41c366765fdd",
    $ClientID          = "74db1c6f-288b-421a-aaeb-187830f33c35",
    $ClientSecret      = "M59Ht1+bLmGXvOF0r7mIo6LoTIY6yulIb/U3vjxNsD0=",
    $ResourceGroupName = "138-CCEP-DevInt-AppData"
)
trap {
    throw $_
}
$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

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
    }
    end {
        return $responseToken.access_token
    }
}


$AuthObject = @{
    client_id         = $ClientID
    client_secret     = $ClientSecret
    TokenEndpoint     = "https://login.microsoftonline.com/${TenantID}/oauth2/token"
}

$accessToken   = getAccessToken @AuthObject
Import-Module -Name AzureRM.Profile
$loggedIn      = Add-AzureRmAccount -AccessToken $accessToken -AccountId $clientid

return $loggedIn