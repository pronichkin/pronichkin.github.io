Import-Module -Name @( 'NetTCPIP', 'NetAdapter', 'dnsClient', 'FailoverClusters' ) -Verbose:$False

$VerbosePreference     = 'Continue'
$DebugPreference       = 'Continue'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 'latest'

Function
ConvertFrom-netIpAddressPrefixLength
{

 <#
   .Description
    Convert from Routing Prefix Length (CIDR notation) to subnet mask
    (Dot-decimal notation)

   .Notes
    Only tested on IPv4 addresses so far
  #>

    [cmdLetBinding()]

    [OutputType( [System.Net.ipAddress] )]

    Param(
        [Parameter()]
        [System.Byte]
        $PrefixLength
    )

    Process
    {
        $Bin  = ( '1' * $PrefixLength ).PadRight( 32, '0' )
        $Int  = [System.Convert]::ToUInt32( $Bin, 2 )
        Return [System.Net.ipAddress]::Parse( $Int )
    }
}

Function
ConvertFrom-netIpAddress
{

 <#
   .Description
    Convert IP address to integer, which might be helpful for calculations

   .Notes
    Only tested on IPv4 addresses so far

    You do not need a separate function for a reverse operation because built-in
    [System.Net.ipAddress]::Parse() will do
  #>

    [cmdLetBinding()]

    [OutputType( [System.uInt32] )]

    Param(
        [Parameter()]
        [System.Net.ipAddress]
        $ipAddress
    )

    Process
    {
        Switch
        (
            $ipAddress.AddressFamily
        )
        {
            (
                [System.Net.Sockets.AddressFamily]::InterNetwork
            )
            {
                $Byte = $ipAddress.GetAddressBytes()

                If
                (
                    [System.BitConverter]::IsLittleEndian
                )
                {
                    [System.Array]::Reverse( $Byte )
                }

                Return [System.BitConverter]::ToUInt32( $Byte, 0 )
            }

            (
                [System.Net.Sockets.AddressFamily]::InterNetworkV6
            )
            {
                Throw 'IPv6 is not yet supported by this function'
            }

            Default
            {
                Throw 'Future address types are not yet supported by this function'
            }
        }
    }
}

Function
Get-netIpSubnet
{

 <#
   .Description
    Find subnet address for a given IP address and Routing Prefix Length
    (subnet mask)

   .Notes
    Only tested on IPv4 addresses so far
  #>

    [cmdLetBinding()]

    [OutputType( [System.Net.ipAddress] )]

    Param(
        [Parameter()]
        [System.Net.ipAddress]
        $ipAddress
    ,
        [Parameter()]
        [System.Byte]
        $PrefixLength
    )

    Process
    {
        Switch
        (
            $ipAddress.AddressFamily
        )
        {
            (
                [System.Net.Sockets.AddressFamily]::InterNetwork
            )
            {
                $ipAddressInt  = ConvertFrom-netIpAddress -ipAddress $ipAddress
                $SubnetMask    = ConvertFrom-netIpAddressPrefixLength -PrefixLength $PrefixLength
                $SubnetMaskInt = ConvertFrom-netIpAddress -ipAddress $SubnetMask
                $SubnetInt     = $SubnetMaskInt -bAnd $ipAddressInt
                Return [System.Net.ipAddress]::Parse( $SubnetInt )
            }

            (
                [System.Net.Sockets.AddressFamily]::InterNetworkV6
            )
            {
                Throw 'IPv6 is not yet supported by this function'
            }

            Default
            {
                Throw 'Future address types are not yet supported by this function'
            }
        }
    }
}

Function
Get-netIpSubnetBroadcastAddress
{

 <#
   .Description
    Find broadcast address for a given IP Address and Routing Prefix Length
    (subnet mask)

   .Notes
    Only tested on IPv4 addresses so far
  #>

    [cmdLetBinding()]

    [OutputType( [System.Net.ipAddress] )]

    Param(
        [Parameter()]
        [System.Net.ipAddress]
        $ipAddress
    ,
        [Parameter()]
        [System.Byte]
        $PrefixLength
    )

    Process
    {
        Switch
        (
            $ipAddress.AddressFamily
        )
        {
            (
                [System.Net.Sockets.AddressFamily]::InterNetwork
            )
            {
                $SuffixLength = 32 - $PrefixLength
                $SubnetSize   = [System.Math]::Pow( 2, $SuffixLength ) 
                $Subnet       = Get-netIpSubnet -ipAddress $ipAddress -PrefixLength $PrefixLength
                $SubnetInt    = ConvertFrom-netIpAddress -ipAddress $Subnet
                $BroadcastInt = $SubnetInt + $SubnetSize - 1

                Return [System.Net.IPAddress]::Parse( $BroadcastInt )
            }

            (
                [System.Net.Sockets.AddressFamily]::InterNetworkV6
            )
            {
                Throw 'IPv6 is not yet supported by this function'
            }

            Default
            {
                Throw 'Future address types are not yet supported by this function'
            }
        }
    }
}

Function
Test-netIpAddress
{

 <#
   .Description
    Find whether given IP address falls into specified subnet, given Routing
    Prefix Length (subnet mask)

   .Notes
    Only tested on IPv4 addresses so far
  #>

    [cmdLetBinding()]

    [OutputType( [System.Boolean] )]

    Param(
        [Parameter()]
        [System.Net.ipAddress]
        $ipAddress
    ,
        [Parameter()]
        [System.Net.ipAddress]
        $Subnet
    ,
        [Parameter()]
        [System.Byte]
        $PrefixLength
    )

    Process
    {
        Switch
        (
            $ipAddress.AddressFamily
        )
        {
            (
                [System.Net.Sockets.AddressFamily]::InterNetwork
            )
            {
                $ipAddressSubnet    = Get-netIpSubnet -ipAddress $ipAddress -PrefixLength $PrefixLength
                $ipAddressSubnetInt = ConvertFrom-netIpAddress -ipAddress $ipAddressSubnet
                $SubnetInt          = ConvertFrom-netIpAddress -ipAddress $Subnet
                Return $ipAddressSubnetInt -eq $SubnetInt
            }

            (
                [System.Net.Sockets.AddressFamily]::InterNetworkV6
            )
            {
                Throw 'IPv6 is not yet supported by this function'
            }

            Default
            {
                Throw 'Future address types are not yet supported by this function'
            }
        }
    }
}