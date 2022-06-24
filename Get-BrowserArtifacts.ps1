function Get-BrowserArtifacts{
        <#
        .SYNOPSIS
            Gets browser artifacts.
        .DESCRIPTION
            Fetches Chrome, Edge, Firefox and IE forensic artifacts.
        .PARAMETER Quiet
            Disables terminal output.
        .PARAMETER Browser
            Identifies browser to retrieve artifacts from.
        .PARAMETER TargetUser
            Indicates which local user to retrieve browser data from.
        .PARAMETER Outpath
            Identifies output directory 
        .EXAMPLE
            Get-BrowserArtifacts
        .EXAMPLE
            Get-BrowserArtifacts -Browser Edge -TargetUser john 
        .INPUTS
            System.Object
        .NOTES
            ###################################################################
            Author:     @ms-smithch
            Version:    0.1a
            ###################################################################
            License:    GPLv3
            ###################################################################
        #>
        [CmdletBinding()]
        param (
            [Parameter][bool]
            $Quiet,
            [Parameter][string]
            $Browser,
            [Parameter][outpath]
            $Outpath = "C:\Temp\",
            [Parameter][string]
            $TargetUser
        )

        #TODO: De-jankify....Just need the folder path for the Users directory
        $Profile = if($TargetUser -like "*@*"){
            Get-LocalUserFromAlias -TargetUser $TargetUser
            }else{
                return "C:\Users\$TargetUser"
            }
        $IsConstrained = $ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage'

        switch ($browser) {
            condition { 
                Chrome {
                    Get-ChromeArtifacts -Outpath $Outpath -UserProfile $Profile
                }
                Firefox {
                    Get-FirefoxArtifacts -Outpath $Outpath -UserProfile $Profile
                }
                Edge {
                    Get-EdgeArtifacts -Outpath $Outpath -UserProfile $Profile
                }
                InternetExplorer {
                    Get-InternetExplorerArtifacts -Outpath $Outpath -UserProfile $Profile
                }
                Default {
                    Get-FirefoxArtifacts -Outpath $Outpath -UserProfile $Profile
                    Get-EdgeArtifacts -Outpath $Outpath -UserProfile $Profile
                    Get-ChromeArtifacts -Outpath $Outpath -UserProfile $Profile
                    Get-InternetExplorerArtifacts -Outpath $Outpath -UserProfile $Profile
                }
            }
        }

        #TODO: Test
        function Get-UserSid{
            $SID = Get-LocalUser $TargetUser | Select-Object Sid
            return $SID
        }

        #TODO: Test
        function Get-LocalUserFromAlias{
            [CmdletBinding()]
            param (
            [Parameter(Mandatory=$true)][string]
            $TargetUser
            )
            $UserProfiles = (Get-ChildItem "C:\Users").FullName
            $TargetUserProfile = foreach($i in $UserProfiles){
                $AADPlugin = (Get-ChildItem "$i\AppData\Local\Packages" -Filter "Microsoft.AAD.BrokerPlugin*" -ErrorAction Continue).FullName
                $AADSettings = "$AADPlugin\Settings\settings.dat"
                if(Select-String -Pattern $TargetUser -Path $AADSettings){ 
                    return $i
                }
            }
            return $TargetUserProfile
        }

        #TODO: Test
        function Get-ValidEmail{
            [CmdletBinding()]
            param (
            [Parameter(Mandatory=$true)][string]
            $TargetUser
            )
            $isValid = $TargetUser -like "^([\w\.\-]+)@([\w\-]+)((\.(\w){2,3})+)$" ###looking for _@_._
            return $isValid
        }
        #TODO: Test
        function Get-AppdataPath{
            [CmdletBinding()]
            param (
                [string(Mandatory=$true)]
                $SID
            )
            $AppdataKey = "HKEY_USERS\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
            $AppDataPath = Get-ChildObject $AppDataKey
            return $AppDataPath
        }
        #TODO: Test
        function Get-EdgeArtifacts{
            $folder = $Outpath + "\Edge"
            $dataPath = "AppData\Local\Microsoft\Edge\User Data\Default"
            Get-ChromiumHistory -DestinationPath $folder
            return $result
        }
        #TODO: Test
        function Get-ChromeArtifacts{   
            $folder = $Outpath + "\Chrome"
            $dataPath = "AppData\Local\Google\Chrome\User Data\Default"
            Get-ChromiumHistory -DestinationPath $folder
            return $result
        }

        #TODO: Identify necessary artifacts....which I'm pretty sure are all stored in the ntuser.dat
        function Get-InternetExplorerArtifacts{
            $folder = $Outpath + "\InternetExplorer"
            $dataPath = "AppData\Local\Microsoft\Edge\User Data\Default"
            return $result
        }

        #TODO: Identify Necessary Artifacts
        function Get-FirefoxArtifacts{
            $folder = $Outpath + "\Firefox"
            $dataPath = "$AppData\Local\Mozilla\Firefox\Profiles"
        }

        #TODO: Test
        function Get-ChromiumArtifacts{
            [cmdletbinding()]
            param (        
                [Parameter(Mandatory=$true)][string]
                $SourcePath,
                [Parameter(Mandatory=$true)][string]
                $DestinationPath
            )
            $TargetArtifacts = @(
                "History",
                "Cookies",
                "Cache",
                "Web Data",
                "Login Data",
                "Current Session",
                "Tabs",
                "Last Session",
                "Last Tabs",
                "Extensions",
                "Thumbnails"
                )
            foreach($i in $TargetArtifacts){
                try{
                    Write-Log "Fetching $i artifact"
                    Copy-Item -Path "$SourcePath\$i" -Destination $DestinationPath
                    Write-Log "$i artifact successfully gathered." -Level "Info"
                }
                catch{
                    Write-Log -Level 1 -Message "$i artifact not found"
                }
            }
        return $result
        }

        #TODO: Finish incorporating Logging.
        function Write-Log{
            [cmdletbinding()]
            param (        
                [Parameter(Mandatory=$true)][string]
                $Message,
                [Parameter][int]
                $Level = 0,
                [Parameter][string]
                $LogFile
            )
            $LogLevel = @{
                0 = "Info"
                1 = "Warning"
                2 = "Error"
            }
            $Now = Get-Date -Format "yyyyMMddHHmmSSZ" -AsUTC
            $LoggedMessage = $LogLevel.$Level + "|$Now|$Message"
            Set-Content -Path $LogFile
        }

        #TODO: Incorporate compression function

}
