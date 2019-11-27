<#
    Grant Static IP Address from Static IP Address Poool in Vmm
    based on friendly concepts like Site Name and Network Name
#>

Set-StrictMode -Version 'Latest'

Function
Grant-scIpAddressEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Net.IPAddress]
        $IpAddress
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Description
    ,   
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NetworkName = "Management"
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
        $StaticIpAddressPoolName
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateSet(

            'VirtualNetworkAdapter',
            'VIP',
            'HostNetworkAdapter',
            'LoadBalancerConfiguration',
            'VirtualMachine',
            'HostCluster',
            'VMSubnet',
            'NetworkGateway',
            'StorageArray'
        )]
        [System.String]
        $GrantToObjectType = 'VirtualNetworkAdapter'
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        $vmmServer
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateSet(
        
            'Management',
            'Compute',
            'Network',
            'Storage'        
        )]
        [System.String]
        $ScaleUnitType
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
        $Message = "  Entering Grant-scIpAddressEx for $Description"
        Write-Debug -Message $Message

        $GetscvmHostGroupExParam = @{

            SiteName      = $SiteName
            vmmServer     = $vmmServer
            ScaleUnitType = $ScaleUnitType
        }

        If
        (
            $NodeSetName
        )
        {
            $GetscvmHostGroupExParam.Add(
                'NodeSetName', $NodeSetName
            )
        }

        $vmHostGroup = Get-scvmHostGroupEx @GetscvmHostGroupExParam

        $GetScvmNetworkParam = @{

            Name      = $NetworkName
            vmmServer = $vmmServer
        }
        $vmNetwork = Get-scvmNetwork @GetScvmNetworkParam

        If
        (
            -Not $StaticIpAddressPoolName
        )
        {
            $StaticIpAddressPoolName = $SiteName
        }

        $GetScStaticIpAddressPoolExParam = @{

            StaticIpAddressPoolName = $StaticIpAddressPoolName
            vmNetwork               = $vmNetwork
            Location                = $vmHostGroup
            vmmServer               = $vmmServer
        }        
        $StaticIpAddressPool = Get-scStaticIPAddressPoolEx @GetScStaticIpAddressPoolExParam

        $GrantScIpAddressParam = @{

            Description         = $Description
            GrantToObjectType   = $GrantToObjectType
            StaticIPAddressPool = $StaticIpAddressPool
        }

        If
        (
            $IpAddress
        )
        {
            $IpAddressString = $IpAddress.IpAddressToString
            
            $GrantScIpAddressParam.Add(
                "IpAddress", $IpAddressString
            )
        }

        $IpAddressGrant = Grant-scIPAddress @GrantScIpAddressParam

        $Message = "   Exiting Grant-scIpAddressEx for $Description"
        Write-Debug -Message $Message

        Return $IpAddressGrant
    }
}