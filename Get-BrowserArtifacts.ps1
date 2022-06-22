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
            [bool]
            $Quiet,
            [string]
            $Browser,
            [outpath]
            $Outpath = "C:\Temp\",
            [string]
            $TargetUser = "*"
        )

        switch ($browser) {
            condition { 
                Chrome {
                    Get-ChromeArtifacts -Outpath $Outpath
                }
                Firefox {
                    Get-FirefoxArtifacts -Outpath $Outpath
                }
                Edge {
                    Get-EdgeArtifacts -Outpath $Outpath
                }
                InternetExplorer {
                    Get-InternetExplorerArtifacts -Outpath $Outpath
                }
                Default {
                    Get-FirefoxArtifacts -Outpath $Outpath
                    Get-EdgeArtifacts -Outpath $Outpath
                    Get-ChromeArtifacts -Outpath $Outpath
                    Get-InternetExplorerArtifacts -Outpath $Outpath
                }
            }
        }

        function Get-UserSid{
        $SID = Get-LocalUser $TargetUser | Select-Object Sid
        }

        function Get-AppdataPath{
        [CmdletBinding()]
        param (
            [string(Mandatory=$true)]
            $SID
        )
        $AppdataKey = "HKEY_USERS\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"

        $AppDataPath = Get-ChildObject $AppDataKey
        }

        function Get-EdgeArtifacts{
        $folder = $Outpath + "/Edge"
        Get-ChromiumHistory -DestinationPath $folder

        }
        function Get-ChromeArtifacts{   
        $folder = $Outpath + "/Chrome"
        Get-ChromiumHistory -DestinationPath $folder
        }

        function Get-InternetExplorerArtifacts{
        $folder = $Outpath + "/InternetExplorer"
        }
        function Get-FirefoxArtifacts{
        $folder = $Outpath + "/Firefox"
        }

        function Get-ChromiumHistory{
        [cmdletbinding()]
        param (        
            [string]
            $DestinationPath= "C:\Temp\"
        )
        Get-ChildObject 
        }
}
