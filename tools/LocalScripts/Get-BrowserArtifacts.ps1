function Get-BrowserArtifacts{
#     <#
#         .SYNOPSIS
#             Executes the Get-BrowserArtifacts script on a remote 
#             device via Live Response.
#         .DESCRIPTION
#             Fetches Chrome, Edge, and Firefox artifacts.
#         .PARAMETER DeviceId
#             Identifies DeviceId to retrieve artifacts from.
#         .PARAMETER Browser
#             Identifies which Browser to retrieve artifacts from
#         .PARAMETER TargetUser
#             Indicates which local user to retrieve browser data from.
#         .PARAMETER IncludeCache
#             Modifies collection to grab browser cache
#         .EXAMPLE
#             Get-BrowserArtifacts -Browser Edge -TargetUser john -DeviceId e76f35b8546c99916f96a37d1b22b265cbb315e2
#         .EXAMPLE
#             Get-BrowserArtifacts -Browser Edge -TargetUser john -DeviceId e76f35b8546c99916f96a37d1b22b265cbb315e2 -IncludeCache 
#         .NOTES
#             ###################################################################
#             Author:     @trashg0blin
#             Version:    1.0
#             ###################################################################
#             License:    GPLv3
#             ###################################################################
#     #>
  param (
  [Parameter(Mandatory=$true)] 
  [ValidateNotNullorEmpty()]
  [String]$DeviceId,
  [Parameter(Mandatory=$true)]
  [String]$Browser,
  [Parameter(Mandatory=$true)]
  [ValidateNotNullorEmpty()]
  [String]$TargetUser,
  [Parameter()]
  [Switch]$IncludeCache
  )
  Disconnect-AzAccount | Out-null
  Connect-AzAccount -Tenant XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX -WarningAction Ignore | Out-null 
  $AccessToken = Get-AzAccessToken -ResourceUrl "https://api.securitycenter.microsoft.com/"
  $header = @{
              'Authorization' = "$($AccessToken.type) $($AccessToken.Token)"
              'Content-type'  = "application/json"
              }

  if ($IncludeCache){
  $args = "-Browser ${Browser} -TargetUser ${TargetUser} -IncludeCache"
  } else{
  $args = "-Browser ${Browser} -TargetUser ${TargetUser}"
  }

  $postParams = (@{
                    "Commands"= @(
                    [ordered]@{
                    "type"= "RunScript"
                    "params"= @(
                      @{
                        "key"= "ScriptName"
                        "value"= "Get-BrowserArtifacts.ps1"
                      },
                      @{
                        "key" = "Args"
                        "value" = "$args"
                      }
                    )
                  },
                  @{
                    "type"= "GetFile"
                    "params"= @(
                      @{
                        "key" = "Path"
                        "value"= "C:\WINDOWS\TEMP\BrowserArtifacts.zip"
                      }
                    )
                  }
                )
                "Comment"= "Gathering Browser Artifacts"
              } | ConvertTo-Json -Depth 4)

  $RunActionUri = "https://api.securitycenter.microsoft.com/api/machines/${DeviceId}/runliveresponse"
  try{  
    $RunActionResponse = (Invoke-WebRequest -Uri "${RunActionUri}" -Method POST -Body $postParams -Headers $header | ConvertFrom-Json)
  }
  catch{
    write-host $RunActionResponse
    Write-Error "Failed to initiate live response session"
    break
  }

  write-host "Response Action ID = $($RunActionResponse.id)"
  Write-Host "Gathering artifacts..."
  Start-Sleep -Seconds 30

  $MachineActionUri = "https://api.securitycenter.microsoft.com/api/machineactions/$($RunActionResponse.id)"
  $complete = $false
  $SleepSeconds = 30
  while($complete -eq $false){
    $MachineActionResponse = (Invoke-WebRequest -Uri "${MachineActionUri}" -Method GET -Headers $header | ConvertFrom-Json)
    switch ($MachineActionResponse.status){
      Created{
        Write-Host "Action created, waiting for execution."
        Start-Sleep -Seconds $SleepSeconds
      }
      Failed{
        Write-Error "Failed to retrieve artifacts."
        return
      }
      Pending{
        Write-Host "Waiting for file."
        Start-Sleep -Seconds $SleepSeconds
      }
      Succeeded{
        Write-Host "Action completed, Gathering file"
        Start-Sleep -Seconds $SleepSeconds # pausing to let the API catch up
        $DownloadLinkUri = "https://api.securitycenter.microsoft.com/api/machineactions/$($MachineActionResponse.id)/GetLiveResponseResultDownloadLink(index=1)"
        $downloadLink = (Invoke-WebRequest -Uri "${DownloadLinkUri}" -Method GET -Headers $header | ConvertFrom-Json).value
        Invoke-WebRequest -Method GET -Uri "${downloadLink}" -Outfile .\${DeviceId}BrowserArtifacts.zip.gz
        Write-Host "File available at $(Get-Location)\${DeviceId}BrowserArtifacts.zip.gz"
        $complete = $true
        return
      }
    }
    $SleepSeconds += 30
  }
}