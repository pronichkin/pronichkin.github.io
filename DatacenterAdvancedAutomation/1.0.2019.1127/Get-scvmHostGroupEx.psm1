<#
    Retreive an existing VM Host Group
#>

Set-StrictMode -Version 'Latest'

Function
Get-scvmHostGroupEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        $vmmServer
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateSet(
            'Compute',
            'Management',
            'Storage',
            'Network'
        )]
        [System.String]
        $ScaleUnitType
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SiteName
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NodeSetName
    )

    Process
    {
        $Message = '  Entering Get-scvmHostGroupEx'
        Write-Debug -Message $Message

      # Get top-level VM Host Group for the Site

        $GetscvmHostGroupParam = @{

            Name      = $SiteName
            vmmServer = $vmmServer
        }
        $vmHostGroupSite = Get-scvmHostGroup @GetscvmHostGroupParam

        If
        (
            $ScaleUnitType
        )

      # Get second-level VM Host Group for the Scale Unit

        {

            If
            (
                $NodeSetName
            )
            {
                $vmHostGroupName = $NodeSetName + ' — ' + $ScaleUnitType
            }
            Else
            {
                $vmHostGroupName = $ScaleUnitType
            }

            $GetscvmHostGroupParam = @{

                Name            = $vmHostGroupName
                ParentHostGroup = $vmHostGroupSite
            }
            $vmHostGroupUnit = Get-scvmHostGroup @GetscvmHostGroupParam

            $Message = '  Exiting   Get-scvmHostGroupEx'
            Write-Debug -Message $Message

            Return $vmHostGroupUnit
        }

        Else
        
        {
            $Message = '  Exiting   Get-scvmHostGroupEx'
            Write-Debug -Message $Message
            
            Return $vmHostGroupSite
        }        
    }
}