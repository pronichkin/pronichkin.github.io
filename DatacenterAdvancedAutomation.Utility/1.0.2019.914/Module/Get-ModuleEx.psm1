<#
    check whether a particular PowerShell Module can be loaded
#>

Set-StrictMode -Version 'Latest'

Function
Get-ModuleEx
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [String]
            $Name
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [String]
            $FeatureName
    )

    Process
    {
        Write-Debug -Message "    Entering Get-ModuleEx for $Name"

        If
        (
            -Not
            (
                Get-Module -ListAvailable -Verbose:$False | Where-Object {
                    $psItem.name -eq $Name
                }
            )
        )
        {
            $InstallWindowsFeatureExParam = @{
        
                FeatureName = $FeatureName
            }
            $WindowsFeature = Install-WindowsFeatureEx @InstallWindowsFeatureExParam
        }

        $Module = Get-Module -Verbose:$False -Name $Name -ListAvailable

        Write-Debug -Message "    Exiting  Get-ModuleEx for $Name"

        Return $Module
    }
}