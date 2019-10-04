Set-StrictMode -Version 'Latest'

Function
Set-TcpIpNetBios
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $NetAdapter
        ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateSet(
            "EnableNetBiosViaDhcp",
            "EnableNetBios",
            "DisableNetBios"        
        )]
        [System.String]
        $TcpIpNetBiosOption
    )

    $Choice = @{

        EnableNetBiosViaDhcp = 0
        EnableNetBios        = 1
        DisableNetBios       = 2
    }

    $Action = @{

        TcpIpNetBiosOptions = $Choice[ "$TcpIpNetBiosOption" ]
    }

    $NetAdapter | ForEach-Object -Process {
    
        $Filter = "InterfaceIndex like '$($psItem.InterfaceIndex)'"

        $ConfigurationParam = @{

            ClassName  = "win32_NetworkAdapterConfiguration"
            Filter     = $Filter
            Verbose    = $False
            cimSession = $psItem.CimSystemProperties.ServerName
        }
        $Configuration = Get-CimInstance @ConfigurationParam

        Write-Verbose -Message "    Setting TCP/IP NetBios on `“$( $Configuration.Caption )`”"

        $TcpIpNetBiosParam = @{

            CimInstance = $Configuration
            MethodName  = "SetTcpIpNetBios"
            Arguments   = $Action
            Verbose     = $False
        }
        $TcpIpNetBios = Invoke-CimMethod @TcpIpNetBiosParam

      # Write-Verbose -Message $TcpIpNetBios.ReturnValue
    }
}