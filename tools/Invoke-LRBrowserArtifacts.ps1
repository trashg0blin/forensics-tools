function Invoke-LRBrowserArtifacts{
    param (
    [Parameter(Mandatory=$true)] 
    [ValidateNotNullorEmpty()]
    [String]$DeviceId,
    [Parameter(Mandatory=$true)]
    [String]$Browser,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [String]$TargetUser
    )
    Disconnect-AzAccount | Out-null
    Connect-AzAccount -Tenant  -WarningAction Ignore | Out-null # Add your tenant ID here
    $AccessToken = Get-AzAccessToken -ResourceUrl "https://api.securitycenter.microsoft.com/"
    $header = @{
                'Authorization' = "$($AccessToken.type) $($AccessToken.Token)"
                'Content-type'  = "application/json"
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
                          "value" = "-Browser ${Browser} -TargetUser ${TargetUser}"
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
        Completed{
          Write-Host "Action completed, Gathering file"
          Start-Sleep -Seconds $SleepSeconds # pausing to let the API catch up
          $DownloadLinkUri = "https://api.securitycenter.microsoft.com/api/machineactions/$($MachineActionResponse.id)/GetLiveResponseResultDownloadLink(index=1)"
          $downloadLink = (Invoke-WebRequest -Uri "${DownloadLinkUri}" -Method GET -Headers $header | ConvertFrom-Json).value
          Invoke-WebRequest -uri $downloadLink -Method GET -OutFile .\BrowserArtifacts.zip
          Write-Host "File available at $(Get-Location)\BrowserArtifacts.zip.gz"
          $complete = $true
          return
        }
      }
      $SleepSeconds += 30 # increasing sleep time to reduce API calls
    }
  }