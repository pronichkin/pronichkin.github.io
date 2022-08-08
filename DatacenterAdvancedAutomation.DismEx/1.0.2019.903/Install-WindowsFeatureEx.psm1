<#
    install specified Windows features on the number of computers
#>

Set-StrictMode -Version 'Latest'

Function
Install-WindowsFeatureEx
{
    [cmdletBinding()]

    Param(
        [parameter(
            Mandatory = $False
        )]
        [System.Collections.Generic.List[System.String]]
        $ServerAddress
    ,
        [parameter(
            Mandatory = $True
        )]
        [System.Collections.Generic.List[System.String]]
        $FeatureName
    ,
        [parameter(
            Mandatory = $False
        )]
        [System.String]
        $SourcePath
    )

    Process
    {
        [System.Void]( Import-ModuleEx -Name 'ServerManager' )
 
      # In case no Server was specified, will install Features locally

        If
        (
            -Not $ServerAddress
        )
        {
            $ServerAddress = "LocalHost"
        }
 
        $ServerAddress = Resolve-dnsNameEx -Name $ServerAddress

        $ServerAddress | ForEach-Object -Process {

            $ServerAddressCurrent = $psItem
 
            $WindowsFeatureParam = @{

                ComputerName           = $ServerAddressCurrent
                Name                   = $FeatureName
                IncludeManagementTools = $True
                Restart                = $False
            }
 
            If
            (
                $SourcePath
            )
            {
                $WindowsFeatureParam.Add(
                    'Source', $SourcePath
                )
            }
 
            $WindowsFeature = Install-WindowsFeature @WindowsFeatureParam

            If
            (
                $WindowsFeature.ExitCode -eq 'SuccessRestartRequired'
            )
            {
                $ComputerParam = @{

                    ComputerName = $ServerAddressCurrent
                    Protocol     = 'wsMan'
                    Wait         = $True
                }
                Restart-Computer @ComputerParam
            }
        }
    }
}