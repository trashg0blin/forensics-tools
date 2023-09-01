function Get-BrowserArtifacts{
    <#
        .SYNOPSIS
            Gets browser artifacts.
        .DESCRIPTION
            Fetches Chrome, Edge, Firefox artifacts.
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
        $Outpath = "$ENV:Temp\BrowserCollection\",
        [Parameter][string]
        $TargetUser,
        [Parameter][string]
        $AppDataPath = "$TargetUser\Appdata\"
    )

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

    function Get-ChromiumArtifacts{   
        [CmdletBinding()]
        param (
        [Parameter(Mandatory=$True)][string]
        $ProfilePath,
        [Parameter][array]
        $OptArtifacts
        )
        $targetArtifacts = {
            "history",
            "cookies",
            "cache",
            "web data",
            "extensions"
        }
        if ($OptArtifacts){
            foreach ($i in $OptArtifacts){
                $targetArtifacts.Add($i)
            }
        }
        foreach ($a in $targetArtifacts){
            Get-TargetArtifacts -SourcePath $dataPath+$p -DestinationPath $outpath+$p `
                -TargetArtifacts $targetArtifacts
        }
    }

    function Get-ChromeArtifacts{   
        $outPath = (New-Item -ItemType Directory -Path $OutPath+"Chrome\").FullName
        $dataPath = "$AppDataPath\Local\Google\Chrome\User Data\"
        $profiles = Get-ChildItem -Path $dataPath -Filter "Profile*"
        $profiles = $profile.add("Default")
        try{
            foreach($p in $profiles){
                $profilePath = "$dataPath/$p"
                Write-Host "Grabbing $p"
                Get-ChromiumArtifacts -SourcePath $profilePath -DestinationPath "$destFolder/$p"
            }
        }
        catch {
            Write-Host "Error fetching Chrome Artifacts"
        }
    }

    function Get-EdgeArtifacts{
        $outPath = (New-Item -ItemType Directory -Path $OutPath+"Edge\").FullName
        $dataPath = "$AppDataPath\Local\Microsoft\Edge\User Data\"
        $profiles = Get-ChildItem -Path $dataPath -Filter "Profile*"
        $profiles = $profiles.add("Default")
        $optArtifacts = {'load_statistics.db'}
        try{
            foreach($p in $profiles){
                $profilePath = $dataPath+$p.Name
                Write-Host "Grabbing profile - $p"
                Get-ChromiumArtifacts -SourcePath $profilePath -DestinationPath "$outPath\$p\" -OptArtifacts $optArtifacts
            }
        }
        catch {
            Write-Host "Error fetching Edge Artifacts"
        }
    }

    function Get-FirefoxArtifacts{
        [CmdletBinding()]
        param (
        [Parameter(Mandatory=$True)][string]
        $AppDataPath,
        [Parameter][string]
        $TargetUser
        )

        $outPath = (New-Item -ItemType Directory -Path $OutPath+"Firefox\").FullName
        $dataPath = "$AppData\Roaming\Mozilla\Firefox\Profiles\"
        $targetArtifacts = {
            "places.sqlite", 
            "formhistory.sqlite", 
            "downloads.sqlite", 
            "cookies.sqlite", 
            "search.sqlite",
            "signons.sqlite",
            "extensions.json"
        }
        
        $profiles = Get-ChildItem $dataPath
        
        try{
            foreach($p in $profiles){
                Write-Host "Grabbing profile - $p"
                New-Item -Path $Outpath+$p.Name -ItemType Directory
                Get-TargetArtifacts -SourcePath $dataPath+$p -DestinationPath $outpath+$p `
                    -TargetArtifacts $targetArtifacts
            }
        }
        catch {
            Write-Host "Error fetching Firefox Artifacts"
        }
    }

    #Get user SID from alias
    function Get-LocalUserFromAlias{
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)][string]
            $TargetUser
        )
        $user = Get-LocalUser -Name $TargetUser
        $SID = $user.SID
        return $SID
    }

    function Get-TargetArtifacts{
        [cmdletbinding()]
        param (        
            [Parameter(Mandatory=$true)][string]
            $SourcePath,
            [Parameter(Mandatory=$true)][array]
            $TargetArtifacts,
            [Parameter(Mandatory=$true)][array]
            $DestPath
        )

        foreach($i in $TargetArtifacts){
            try{
                Write-Host "Fetching $i artifact"
                Copy-Item -Path "$SourcePath\$i" -Destination $DestPath
                Write-Host "$i artifact successfully gathered." 
            }
            catch{
                Write-Host "$i artifact not found"
            }
        }
    }

    $ProfilePath = "C:\Users\$TargetUser"
    $AppDataPath = "$ProfilePath\AppData"

    if (!(Get-Item $Outpath)){
        New-Item -Path $Outpath -ItemType Directory
    }

    switch ($browser) {
        condition { 
            Chrome {
                Get-ChromeArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
            }
            Firefox {
                Get-FirefoxArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
            }
            Edge {
                Get-EdgeArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
            }
            Default {
                Get-FirefoxArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
                Get-EdgeArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
                Get-ChromeArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
            }
        }
    }

    Write-Host "Compressing browser artifacts for download"
    Compress-Archive -Path $Outpath -DestinationPath $Outpath+"BrowserArtifacts.zip" -Force
    Write-Host "Archive available at " $Outpath+"BrowserArtifacts.zip"

    
}
