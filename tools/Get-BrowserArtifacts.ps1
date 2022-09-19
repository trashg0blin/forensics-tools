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
        .NOTES
            ###################################################################
            Author:     @ms-smithch
            Version:    0.1a
            ###################################################################
            License:    GPLv3
            ###################################################################
        #>

        param (
            [Parameter][bool]
            $Quiet,
            [Parameter][string]
            $Browser,
            [Parameter][string]
            $Outpath = 'C:\Temp\BrowserArtifacts',
            [Parameter][string]
            $TargetUser
        )

        #TODO: De-jankify....Just need the folder path for the Users directory
        $UserProfile = if($TargetUser -like "*@*"){
            Get-LocalUserFromAlias -TargetUser $TargetUser
            }else{
                return "C:\Users\$TargetUser"
            }
        
        $IsConstrained = $ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage'
        $AppDataPath = "$Profile\AppData"

        if (!(Get-Item $Outpath)){
            New-Item -Path $Outpath -ItemType Directory
        }
        switch ($browser) {
            condition { 
                Chrome {
                    Get-ChromeArtifacts -Outpath $Outpath -UserProfile $UserProfile -AppDataPath $AppDataPath
                }
                Firefox {
                    Get-FirefoxArtifacts -Outpath $Outpath -UserProfile $UserProfile -AppDataPath $AppDataPath
                }
                Edge {
                    Get-EdgeArtifacts -Outpath $Outpath -UserProfile $UserProfile -AppDataPath $AppDataPath
                }
                InternetExplorer {
                    Get-InternetExplorerArtifacts -Outpath $Outpath -UserProfile $UserProfile 
                }
                Default {
                    Get-FirefoxArtifacts -Outpath $Outpath -UserProfile $Profile
                    Get-EdgeArtifacts -Outpath $Outpath -UserProfile $Profile
                    Get-ChromeArtifacts -Outpath $Outpath -UserProfile $Profile
                    Get-InternetExplorerArtifacts -Outpath $Outpath -UserProfile $Profile
                }
            }
        }

        Write-Log -Message "Compressing browser artifacts for download"
        $Compressed = Compress-Archive -Path $Outpath -DestinationPath "$Outpath.zip" -Force
        Write-Log -Message "Archive available at $Outpath.zip"

        #TODO: Test
        function Get-UserSid{
            $SID = Get-LocalUser $TargetUser | Select-Object Sid
            return $SID
        }

        #TODO: Works in test
        function Get-LocalUserFromAlias{
            [CmdletBinding()]
            param (
            [Parameter(Mandatory=$true)][string]
            $TargetUser
            )
            $UserProfiles = (Get-ChildItem "C:\Users" -ErrorAction Ignore).FullName
            $TargetUserProfile = foreach($i in $UserProfiles){
                $AADPlugin = (Get-ChildItem "$i\AppData\Local\Packages" -Filter "Microsoft.AAD.BrokerPlugin*" -ErrorAction Ignore).FullName
                $AADSettings = "$AADPlugin\Settings\settings.dat"
                if(Select-String -Pattern $TargetUser -Path $AADSettings -ErrorAction Ignore){ 
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
            $isValid = $TargetUser -like '^([\w\.\-]+)@([\w\-]+)((\.(\w){2,3})+)$' ###looking for _@_._
            return $isValid
        }
        #TODO: Test
        function Get-AppdataPath{
            [CmdletBinding()]
            param (
                [Parameter(Mandatory=$true)][string]
                $SID
            )
            $AppdataKey = "REG:\\HKEY_USERS\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
            $AppDataPath = Get-ChildItem $AppDataKey
            return $appDataPath
        }
        #TODO: Test
        function Get-EdgeArtifacts{
            [CmdletBinding()]
            param (
            [Parameter][string]
            $OutFolder = 'C:\Temp',
            [Parameter(Mandatory=$True)][string]
            $AppDataPath
            )

            $destFolder = $OutFolder + "\Edge"
            $dataPath = "$AppDataPath\Local\Microsoft\Edge\User Data\Default"
            $profiles = Get-ChildItem -Path $dataPath -Filter "Profile*"
            
            if ($profiles){
                Write-Log -Level 0 "Multiple profiles detected, grabbing all profiles."
                foreach($p in $profiles){
                    $profilePath = "$dataPath/$p"
                    Write-Log -Level 0 -Message "Grabbing $p"
                    Get-ChromiumArtifacts -SourcePath $profilePath -DestinationPath "$destFolder/$p"
                }
            }

            Get-ChromiumArtifacts -SourcePath $dataPath -DestinationPath $folder
            return $result
        }
        #TODO: Test
        function Get-ChromeArtifacts{   
            [CmdletBinding()]
            param (
            [Parameter][string]
            $OutFolder = 'C:\Temp',
            [Parameter(Mandatory=$True)][string]
            $AppDataPath
            )

            $destFolder = $OutFolder + "\Chrome"
            $dataPath = "$AppDataPath\Local\Google\Chrome\User Data\Default"
            $profiles = Get-ChildItem -Path $dataPath -Filter "Profile*"
            $result = $false
            
            try {
                if ($profiles){
                    Write-Log -Level 0 "Multiple profiles detected, grabbing all profiles."
                    foreach($p in $profiles){
                        $profilePath = "$dataPath/$p"
                        Write-Log -Level 0 -Message "Grabbing $p"
                        Get-ChromiumArtifacts -SourcePath $profilePath -DestinationPath "$destFolder/$p"
                    }
                }
    
                Get-ChromiumArtifacts -SourcePath $dataPath -DestinationPath $destFolder
                $result = $true
            }
            catch {
                Write-Log -Level 2 "Error fetching Chrome Artifacts"
            }

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
            [CmdletBinding()]
            param (
            [Parameter][string]
            $Outpath = 'C:\Temp',
            [Parameter(Mandatory=$True)][string]
            $AppDataPath,
            [Parameter][string]
            $TargetUser
            )
            $folder = $Outpath + "\Firefox"
            $dataPath = "$AppData\Roaming\Mozilla\Firefox\Profiles"
            $targetArtifacts = {
                "places.sqlite", 
                "formhistory.sqlite", 
                "downloads.sqlite", 
                "cookies.sqlite", 
                "search.sqlite",
                "signons.sqlite",
                "extensions.json"
            }

            if ($TargetUser){
                $profiles = Get-ChildItem $dataPath

                foreach($p in $profiles.Name){
                    Write-Log "Scanning profile folders for $TargetUser's profile"

                    if (Select-String -Pattern $TargetUser -InputObject "$dataPath\$p\signedInUser.json"){
                        Write-Log "$TargerUser's profile found at $dataPath\$p"
                        Get-TargetArtifacts -SourcePath "$dataPath\$p" -DestinationPath "$Outpath\$p" -TargetArtifacts $targetArtifacts
                    } else {
                        Write-Log "$TargetUser not found in $dataPath\$p"
                    }
                }
            } else{
                $profiles = Get-ChildItem $dataPath
                foreach($p in $profiles){
                    $profileFolder = New-Item -Path $folder + $p.Name -ItemType Directory
                    Get-TargetArtifacts -SourcePath "$dataPath\$p" -DestinationPath "$Outpath\$p" `
                    -TargetArtifacts $targetArtifacts
                }
            }

        }

        #TODO: Test
        function Get-Targetrtifacts{
            [cmdletbinding()]
            param (        
                [Parameter(Mandatory=$true)][string]
                $SourcePath,
                [Parameter(Mandatory=$true)][string]
                $DestinationPath,
                [Parameter(Mandatory=$true)][array]
                $TargetArtifacts
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
