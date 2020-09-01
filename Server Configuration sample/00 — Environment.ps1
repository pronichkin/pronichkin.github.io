Import-Module -Verbose:$False -Name @(
    'NetTCPIP',
    'NetAdapter',
    'dnsClient',
    'FailoverClusters',
    'dism',
    'NetSecurity',
    'Storage',
    'Hyper-V'
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$VerbosePreference     = [System.Management.Automation.ActionPreference]::Continue
$DebugPreference       = [System.Management.Automation.ActionPreference]::Continue
Set-StrictMode -Version 'Latest'

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

Function
Write-Message
{
    [System.Management.Automation.CmdletBindingAttribute()]
    Param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateSetAttribute(
            'Error',
            'Information',
            'Verbose',
            'Debug',
            'Warning'
        )]
        [System.String]
        $Channel
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.String]
        $Message
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Int16]
        $Indent  = 0
    )

    Process
    {
      # Base offset to visually distinguish timestamp from the message
        $Indent++
        
        Switch
        (
            $Channel
        )
        {
           'Information'
            {
                $Length = 20
            }

           'Verbose'
            {
                $Length = 11
            }

           'Warning'
            {
                $Length = 11
            }

           'Debug'
            {
                $Length = 13
                $Indent++
            }

            'Error'
            {
                $Length = 13
            }
        }

        $DisplayHint = [Microsoft.PowerShell.Commands.DisplayHintType]::Time
        $TimeStamp   = ( Get-Date -DisplayHint $DisplayHint ).DateTime

        $MessageEx   = [System.String]::Empty
        $MessageEx  += $TimeStamp.PadLeft(  $Length )
        $MessageEx   = $MessageEx.PadRight( $Length + 2 * $Indent )
        $MessageEx  += $Message

        $Command     = "Write-$Channel"

      & $Command -Message $MessageEx
    }
}

Function
Test-Administrator
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param(
    
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    Process
    {
        $WindowsIdentity    = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $WindowsPrincipal   = [System.Security.Principal.WindowsPrincipal]::new( $WindowsIdentity )
        $WindowsBuiltInRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
        $IsInRole           = $WindowsPrincipal.IsInRole( $WindowsBuiltInRole )

        If
        (
            $Force
        )
        {
            If
            (
                $IsInRole
            )
            {        
              # We're good. Proceed to what we were going to do
            }
            Else
            {
                $Message = 'This script requires to be run Elevated (“as Administrator”)'

                Write-Message -Channel Error -Message $Message
            }
        }
        Else
        {
            Return $IsInRole
        }
    }
}

Function
Get-wsManTrustedHost
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param(
    
        [System.Management.Automation.ParameterAttribute()]
        [System.String]
        $ComputerName
    )

    Process
    {
        $InstanceParam = @{

            ResourceURI = 'WinRM/Config/Client'
        }

        If
        (
            $ComputerName
        )
        {
            $InstanceParam.Add( 'ComputerName', $ComputerName )
        }

        $Client = Get-wsManInstance @InstanceParam

        Return $Client.TrustedHosts -split ','
    }
}

Function
Test-wsManTrustedHost
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True    
        )]
        [System.Collections.Generic.List[System.String]]
        $HostName
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.String]
        $ComputerName
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.SwitchParameter]
        $noMatch
    )

    Process
    {
        $HostParam = @{}

        If
        (
            $ComputerName
        )
        {
            $HostParam.Add( 'ComputerName', $ComputerName )
        }

        $HostCurrent = Get-wsManTrustedHost @HostParam

        If
        (
            $noMatch
        )
        {
            $FilterScript = { $psItem -notIn $HostCurrent }
        }
        Else
        {
            $FilterScript = { $psItem    -In $HostCurrent }
        }

        Return $HostName | Where-Object -FilterScript $FilterScript
    }
}

Function
Set-wsManTrustedHost
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True    
        )]
        [System.Collections.Generic.List[System.String]]
        $HostName
    ,    
        [System.Management.Automation.ParameterAttribute()]
        [System.String]
        $ComputerName
    )

    Process
    {
        $ValueSet = @{

            TrustedHosts = $HostName -join ','
        }

        $InstanceParam = @{

            ResourceURI = 'WinRM/Config/Client'
            ValueSet    = $ValueSet
        }

        If
        (
            $ComputerName
        )
        {
            $InstanceParam.Add( 'ComputerName', $ComputerName )
        }
        Else
        {
            Test-Administrator -Force
        }

        [System.Void]( Set-wsManInstance @InstanceParam )
    }
}

Function
Add-wsManTrustedHost
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True    
        )]
        [System.Collections.Generic.List[System.String]]
        $HostName
    ,    
        [System.Management.Automation.ParameterAttribute()]
        [System.String]
        $ComputerName
    )

    Process
    {
        $HostParam = @{

            'HostName' = $HostName
            'noMatch'  = $True
        }

        If
        (
            $ComputerName
        )
        {
            $HostParam.Add( 'ComputerName', $ComputerName )
        }
            
        $HostAdd = Test-wsManTrustedHost @HostParam

        If
        (
            $HostAdd
        )
        {
            $HostParam = @{}

            If
            (
                $ComputerName
            )
            {
                $HostParam.Add( 'ComputerName', $ComputerName )
            }

            $HostCurrent = Get-wsManTrustedHost @HostParam

            $HostSet = $HostCurrent + $HostAdd

            $HostParam.Add( 'HostName', $HostSet )

            Set-wsManTrustedHost @HostParam
        }
        Else
        {
            $Message = 'All specified values are already in Trusted Hosts'
            Write-Message -Channel Debug -Message $Message
        }
    }
}

Function
Remove-wsManTrustedHost
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True    
        )]
        [System.Collections.Generic.List[System.String]]
        $HostName
    ,    
        [System.Management.Automation.ParameterAttribute()]
        [System.String]
        $ComputerName
    )

    Process
    {
        $HostParam = @{

            'HostName' = $HostName
          # 'noMatch'  = $True
        }

        If
        (
            $ComputerName
        )
        {
            $HostParam.Add( 'ComputerName', $ComputerName )
        }
            
        $HostRemove = Test-wsManTrustedHost @HostParam

        If
        (
            $HostRemove
        )
        {
            $HostParam = @{}

            If
            (
                $ComputerName
            )
            {
                $HostParam.Add( 'ComputerName', $ComputerName )
            }

            $HostCurrent = Get-wsManTrustedHost @HostParam

            $HostSet = $HostCurrent | Where-Object -FilterScript {

                $psItem -notIn $HostRemove
            }

            $HostParam.Add( 'HostName', $HostSet )

            Set-wsManTrustedHost @HostParam
        }
        Else
        {
            $Message = 'None of the specified values are in Trusted Hosts'
            Write-Message -Channel Debug -Message $Message
        }
    }
}

Function
Get-ServiceEx
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True    
        )]
        [System.Collections.Generic.List[System.String]]
        $Name
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Collections.Generic.List[System.String]]
        $ComputerName
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.psCredential]
        $Credential
    )

    Process
    {
        If
        (
            $Credential
        )
        {
            $Mapping = [System.Collections.Generic.List[
                Microsoft.Management.Infrastructure.CimInstance
            ]]::new()

            $ComputerName | ForEach-Object -Process {

                $MappingParam = @{
                    
                    RemotePath = "\\$psItem\ipc$"
                    UserName   = $Credential.GetNetworkCredential().UserName
                    Password   = $Credential.GetNetworkCredential().Password
                }
                $Mapping.Add( ( New-SmbMapping @MappingParam ) )
            }
        }

        $ServiceParam = @{ 

            Name = $Name
        }

        If
        (
            $ComputerName
        )
        {
            $ServiceParam.Add(
                'ComputerName',
                $ComputerName
            )
        }

        [System.Collections.Generic.List[
            System.ServiceProcess.ServiceController
        ]]$Service = Get-Service @ServiceParam

        If
        (
            $Credential
        )
        {
          # This always returns “Invalid parameter” error
          # Remove-SmbMapping -InputObject $Mapping

            Remove-SmbMapping -RemotePath $Mapping.RemotePath -Confirm:$False
        }

        Return $Service
    }
}