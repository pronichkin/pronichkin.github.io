Set-StrictMode -Version 'Latest'

Function
Find-scComputerEx
{
    [cmdletBinding()]

    Param(
    
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $bmcAddress
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
        $RunAsAccountBmc
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        $vmmServer =  $RunAsAccountBmc.ServerConnection
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.SwitchParameter]
        $DeepDiscovery
    )

    Process
    {
     <# Quick Discovery — “Discover baseboard management controler”
        to obtain Server's Manufacturer and Model  #>

        If
        (
            $DeepDiscovery
        )
        {
            $Message = 'Running Deep Discovery of server hardware. This should take a while'
            Write-Verbose -Message $Message
        }

     <# VMM cmdlets here won't allow to use FQDN here
        Need to obtain an IP address  #>

        $Message = '    Performing reverse DNS resolution for BMC address. This is required for VMM cmdlets'
        Write-Debug -Message $Message

        $bmcAddressIp       = Resolve-DnsNameEx -Name $bmcAddress -Reverse
        $bmcAddressIpString = $bmcAddressIp.IPAddressToString

        $Message = '  Physical Computer discovery is in progress'
        Write-Verbose -Message $Message

        $FindScComputerParam = @{

            bmcAddress      = $bmcAddressIpString
            BMCProtocol     = 'IPMI'
          # BMCPort         =  623
            BMCRunAsAccount = $RunAsAccountBmc
            DeepDiscovery   = $DeepDiscovery
            vmmServer       = $vmmServer
        }
        $Computer = Find-scComputer @FindScComputerParam

        $Message = '  Physical Computer discovery is done'
        Write-Verbose -Message $Message

        Return $Computer
    }
}