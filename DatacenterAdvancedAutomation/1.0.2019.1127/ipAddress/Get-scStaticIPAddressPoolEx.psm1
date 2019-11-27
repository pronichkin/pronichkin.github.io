<#
    get Vmm Static IPAddress Pool
    based on VM Network and Location
    (Location can be either Host Group object
    or an arbitrary string resolving to Site name)
#>

Set-StrictMode -Version 'Latest'

Function
Get-scStaticIPAddressPoolEx
{
    [cmdletBinding()]

    Param(
        $vmNetwork,
        $StaticIpAddressPoolName,
        $Location,
        $vmmServer
    )

    Process
    {
      # Get Logical Network

        $LogicalNetwork = $vmNetwork.LogicalNetwork
    
      # Get Logical Network Definition

        $GetSCLogicalNetworkDefinitionParam = @{

            LogicalNetwork = $LogicalNetwork
            vmmServer      = $vmmServer
        }

        If
        (
            $Location -is [Microsoft.SystemCenter.VirtualMachineManager.HostGroup]
        )
        {
            $GetSCLogicalNetworkDefinitionParam.Add(
                "vmHostGroup", $Location
            )
        }
        Else
        {
            $GetSCLogicalNetworkDefinitionParam.Add(
                'Name', $Location
            )
        }

        $LogicalNetworkDefinition = Get-scLogicalNetworkDefinition @GetSCLogicalNetworkDefinitionParam

      # Get IP Pool

        $GetSCStaticIPAddressPoolParam = @{

            Name                     = $StaticIpAddressPoolName
            LogicalNetworkDefinition = $LogicalNetworkDefinition
            vmmServer                = $vmmServer
        }
        $StaticIPAddressPool = Get-scStaticIPAddressPool @GetSCStaticIPAddressPoolParam

      # Return IP Pool

        Return $StaticIPAddressPool
    }
}