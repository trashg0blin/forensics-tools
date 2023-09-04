
#     <#
#         .SYNOPSIS
#             Gets browser artifacts.
#         .DESCRIPTION
#             Fetches Chrome, Edge, and Firefox artifacts.
#         .PARAMETER Browser
#             Identifies browser to retrieve artifacts from.
#         .PARAMETER TargetUser
#             Indicates which local user to retrieve browser data from.
#         .PARAMETER Outpath
#             Identifies output directory 
#         .EXAMPLE
#             Get-BrowserArtifacts
#         .EXAMPLE
#             Get-BrowserArtifacts -Browser Edge -TargetUser john 
#         .NOTES
#             ###################################################################
#             Author:     @trashg0blin
#             Version:    1.0
#             ###################################################################
#             License:    GPLv3
#             ###################################################################
#     #>

param (
    [string]
    $Browser,
    [string]
    $Outpath = "$ENV:Temp\BrowserCollection\",
    [string]
    $TargetUser
)

function Get-ChromiumArtifacts{   
    [CmdletBinding()]
    param (
    [string]
    $ProfilePath,
    [array]
    $OptArtifacts,
    [string]
    $DestinationPath
    )
    $TargetArtifacts = @(
        "History",
        "Network",
        "Cache",
        "Web data",
        "Extensions",
        "Preferences"
    )
    if ($OptArtifacts){
        foreach ($i in $OptArtifacts){
            $TargetArtifacts += $i
        }
    }
    Get-TargetArtifacts -SourcePath $ProfilePath -DestinationPath $DestinationPath `
            -TargetArtifacts $TargetArtifacts
}

function Get-ChromeArtifacts{   
    $OutPath = (New-Item -ItemType Directory -Path "${OutPath}Chrome").FullName
    $DataPath = "$AppDataPath\Local\Google\Chrome\User Data\"
    $Profiles = Get-ChildItem -Path $dataPath | Where-Object {$_.Name -like "Profile*" -or $_.Name -like "Default"}
    try{
        foreach($p in $Profiles.Name){
            $profilePath = "${DataPath}${p}\"
            $destinationPath = (New-Item -ItemType Directory -Path "${CollectionPath}\${p}").FullName
            Write-Host "Grabbing profile - ${p}"
            Get-ChromiumArtifacts -ProfilePath $profilePath -DestinationPath $destinationPath `
                -OptArtifacts $OptArtifacts
        }
    }
    catch {
        Write-Error "Error fetching Chrome Artifacts"
    }
}

function Get-EdgeArtifacts{
    $CollectionPath = (New-Item -ItemType Directory -Path "${OutPath}Edge").FullName
    $DataPath = "${AppDataPath}\Local\Microsoft\Edge\User Data\"
    $Profiles = Get-ChildItem -Path $dataPath | Where-Object {$_.Name -like "Profile*" -or $_.Name -like "Default"}
    $OptArtifacts = @('load_statistics.db')
    try{
        foreach($p in $Profiles.Name){
            $profilePath = "${DataPath}${p}\"
            $destinationPath = (New-Item -ItemType Directory -Path "${CollectionPath}\${p}").FullName
            Write-Host "Grabbing profile - ${p}"
            Get-ChromiumArtifacts -ProfilePath $profilePath -DestinationPath $destinationPath `
                -OptArtifacts $OptArtifacts
        }
    }
    catch {
        Write-Error "Error fetching Edge Artifacts"
    }
}

function Get-FirefoxArtifacts{
    $CollectionPath = (New-Item -ItemType Directory -Path "${OutPath}Firefox").FullName
    $DataPath = "$AppDataPath\Roaming\Mozilla\Firefox\Profiles\"
    $TargetArtifacts = {
        "places.sqlite", 
        "formhistory.sqlite", 
        "downloads.sqlite", 
        "cookies.sqlite", 
        "search.sqlite",
        "signons.sqlite",
        "extensions.json",
        "cache"
    }
    
    $Profiles = Get-ChildItem $dataPath
    
    try{
        foreach($p in $Profiles.Name){
            $profilePath = "${DataPath}${p}\"
            $destinationPath = (New-Item -ItemType Directory -Path "${CollectionPath}\${p}").FullName
            Write-Host "Grabbing profile - $p"
            Get-TargetArtifacts -SourcePath $profilePath -DestinationPath $destinationPath `
                -TargetArtifacts $TargetArtifacts
        }
    }
    catch {
        Write-Error "Error fetching Firefox Artifacts"
    }
}

function Get-TargetArtifacts{
    [cmdletbinding()]
    param (        
        [string]
        $SourcePath,
        [array]
        $TargetArtifacts,
        [string]
        $DestinationPath
    )

    foreach($a in $TargetArtifacts){
        try{
            Write-Host "Fetching ${a} from ${SourcePath}}"
            Copy-Item -Path "${SourcePath}${a}" -Destination "${DestinationPath}${$a}"
            Write-Host "$a artifact successfully gathered." 
        }
        catch{
            Write-Error "Failed to grab $a from ${SourcePath}}"
        }
    }
}

$AppDataPath = "C:\Users\$TargetUser\AppData"

if (!(Get-Item $Outpath)){
    New-Item -Path $Outpath -ItemType Directory
}

switch ($Browser) {
        Chrome {
            Get-ChromeArtifacts 
        }
        Firefox {
            Get-FirefoxArtifacts 
        }
        Edge {
            Get-EdgeArtifacts 
        }
        Default {
            Get-FirefoxArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
            Get-EdgeArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
            Get-ChromeArtifacts -Outpath $Outpath -AppDataPath $AppDataPath
        }
}
Write-Host "Compressing browser artifacts for download"
Compress-Archive -Path $Outpath -DestinationPath "${ENV:Temp}\BrowserCollection.zip" -Force
Remove-Item -Path $Outpath -Recurse -Force
Write-Host "Archive available at ${Outpath}BrowserArtifacts.zip"
