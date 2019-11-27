Set-StrictMode -Version 'Latest'

Function
Get-netAdapterEx
{
    [cmdletBinding()]

    Param(

            [parameter(
                Mandatory = $False
            )]
            [System.String]
            $Name = "*"
        ,
            [parameter(
                Mandatory = $False
            )]
            [Microsoft.Management.Infrastructure.cimSession]
            $cimSession = "."
        ,
            [parameter(
                Mandatory = $False
            )]
            [Switch]
            $Physical
        ,
            [parameter(
                Mandatory = $False
            )]
            [System.Net.NetworkInformation.PhysicalAddress[]]
            $PhysicalAddress
        ,
            [parameter(
                Mandatory = $False
            )]
            [Microsoft.HyperV.PowerShell.VMInternalNetworkAdapter[]]
            $vmNetworkAdapter
        ,
            [parameter(
                Mandatory = $False
            )]
            [System.Guid[]]
            $DeviceID
    )

    Begin
    {

      # When we have $VerbosePreference defined as “Continue”, each time
      # we run “Get-netAdapter”, there's a lot of Verbose output listing
      # imported Functions from “NetAdapter.Format.Helper” module. This output
      # provides no value, thus we need to suppress it. Unfortunately, even
      # if we pass “-Verobse:$False” to “Get-netAdapter”, it does not help
      # at all. (This is probably a bug). Thus, we need to temporary change
      # $VerbosePreference.

        $VerbosePreferenceCurrent = $VerbosePreference
        $Global:VerbosePreference = "SilentlyContinue"
    }

    Process
    {        
        $NetAdapterParam = @{

            Name       = $Name
            Physical   = $Physical
            cimSession = $cimSession 
        }
        $NetAdapter = Get-netAdapter @NetAdapterParam

        If
        (
            $PhysicalAddress
        )
        {
            $NetAdapter = $NetAdapter | Where-Object -FilterScript {

                $psItem.NetworkAddresses[0] -in (
                    $PhysicalAddress | ForEach-Object -Process { $psItem.ToString() }
                )
            }
        }
        ElseIf
        (
            $vmNetworkAdapter
        )
        {
            $NetAdapter = $NetAdapter | Where-Object -FilterScript {

                [System.Guid]$psItem.DeviceID -in [System.Guid[]]$vmNetworkAdapter.DeviceId
            }
        }
        ElseIf
        (
            $DeviceID
        )
        {
            $NetAdapter = $NetAdapter | Where-Object -FilterScript {

                [System.Guid]$psItem.DeviceID -in $DeviceID
            }
        }
        Else
        {
            $SortObjectParam = @{

                Property = "LinkSpeed", "macAddress"
            }
            $NetAdapter = $NetAdapter | Sort-Object @SortObjectParam
        }
    }

    End
    { 
        $Global:VerbosePreference = $VerbosePreferenceCurrent

        Return $NetAdapter
    }
}