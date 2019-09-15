Function
New-scConfigurationEx
{
   #region Data

        [cmdletBinding()]
        Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name
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
            [System.Net.IPAddress]
            $ipAddressManagement
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
            [Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerProfile]
            $Template
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
            [Microsoft.SystemCenter.VirtualMachineManager.HostGroup]
            $vmHostGroup
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Security.SecureString]
            $bmcPassword
        )

   #endregion Data

   #region Code

        Write-Verbose -Message "Entering New-scConfigurationEx for $Name"
      # Write-Verbose -Message "Physical Computer Template: $Template"

        If
        (
            [System.String]::IsNullOrWhiteSpace( $vmHostGroup )
        )
        {
            $GetscvmHostGroupExParam = @{

                SiteName  = $SiteName
                vmmServer = $vmmServer
            }
            $vmHostGroup = Get-scvmHostGroupEx @GetscvmHostGroupExParam

            Write-Verbose -Message "VM Host Group: $vmHostGroup"
        }       

      # We will need the MAC Address Pool for Physical Computer vNICs.

        $GetScmacAddressPoolParam = @{
        
            VirtualizationPlatform = "HyperV"
            vmmServer = $vmmServer
        }
        $macAddressPool = Get-scmacAddressPool @GetScmacAddressPoolParam |
            Sort-Object -Property 'Name' | Select-Object -First 1
                 
     <# Quick Discovery — “Discover baseboard management controler”
      # to obtain Server's SM BIOS GUID.

        $FindScComputerExParam = @{

            bmcAddress      = $bmcAddress
            RunAsAccountBmc = $RunAsAccountBmc
            vmmServer       = $vmmServer
        }
        $Computer = Find-scComputerEx @FindScComputerExParam  #>

      # Deep Discovery to obtain Physical NIC properties
      # (MAC Addresses or Consistent Device Names)

      # Note this is not necessary if we rely on CDN and it's available.
      # However this is required if there's no CDN, and we want to match
      # what we put in CDN previously with actual Location field.

        $FindScComputerExParam = @{

            bmcAddress      = $bmcAddress
            RunAsAccountBmc = $RunAsAccountBmc
            DeepDiscovery   = $True
            vmmServer       = $vmmServer
        }
        $Computer = Find-scComputerEx @FindScComputerExParam

       #region Build properties for Node Physical Computer Network Adapter Configuration

            $NetworkAdapterConfiguration = New-Object -TypeName "System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerNetworkAdapterConfig]"

            $NetworkAdapterProfile =
                $Template.PhysicalComputerNetworkAdapterProfiles
        
          # We need to process Physical NICs first because one of them
          # will be selected as Transient Management Network Adapter.

            $NetworkAdapterProfileSort = $NetworkAdapterProfile |
                Sort-Object -Property "IsVirtualNetworkAdapter" |
                    ForEach-Object -Process {

                $NetworkAdapterProfileCurrent = $psItem

                If
                (
                    $NetworkAdapterProfileCurrent.ConsistentDeviceName
                )
                {
                    $NetworkAdapterProfileCurrentName = $NetworkAdapterProfileCurrent.ConsistentDeviceName
                }
                Else
                {
                    $NetworkAdapterProfileCurrentName = $NetworkAdapterProfileCurrent.vmNetwork.Name
                }

                Write-Verbose -Message "Building Physical Computer Network Adapter Configuration for `“$NetworkAdapterProfileCurrentName`”"

                $NetworkAdapterParam = @{
            
                    vmmServer = $vmmServer
                }

                If
                (
                    $NetworkAdapterProfileCurrent.IsPhysicalNetworkAdapter
                )
                
              # Configuration specific to Physical NICs                              

                {
                    Write-Verbose -Message "  This is a Physical adapter"
                
                    $NetworkAdapterParam.Add(
                        "SetAsPhysicalNetworkAdapter", $True
                    )

                    If
                    (
                        $NetworkAdapterProfileCurrent.LogicalNetwork
                    )

                  # This pNIC connects directly to a Logical Network, which is
                  # typical for physical storage servers (as opposite to Hyper-V
                  # host servers.)

                    {
                        $LogicalNetwork = $NetworkAdapterProfileCurrent.LogicalNetwork
                
                        $GetScSubnetVlanExParam = @{
                
                            LogicalNetwork = $LogicalNetwork
                            vmHostGroup    = $vmHostGroup
                        }                
                        $SubnetVlan = Get-scSubnetVlanEx @GetScSubnetVlanExParam

                        $Subnet = $SubnetVlan[0].Subnet

                        $NetworkAdapterParam.Add(
                            "UseStaticIPForIPConfiguration", $True
                        )

                        $NetworkAdapterParam.Add(
                            "LogicalNetwork", $LogicalNetwork
                        )

                        $NetworkAdapterParam.Add(
                            "IPv4Subnet", $Subnet
                        )

                        $NetworkAdapterParam.Add(
                            "DisableAdapterDnsRegistration", $False
                        )
                    }

                    Else

                  # This is a pNIC connected to Logical Switch, which is typical
                  # for Hyper-V hosts

                    {
                        $Message = "  It will be used for a Logical Switch, but might temporarily get an IP address from DHCP. Hence we disable DNS registration."
                        Write-Verbose -Message $Message

                        $NetworkAdapterParam.Add(
                            "DisableAdapterDnsRegistration", $True
                        )
                    }

                    If
                    (
                        $NetworkAdapterProfileCurrent.ConsistentDeviceName
                    )

                  # We've populated Consistent Device Name (CDN) property in Physical
                  # Computer Network Adapter Profile. This means it's either an actual
                  # CDN, or we re-used this field as a temporary location to store
                  # device Location. (Because there's no separate field for that, and
                  # no "Description" property.)

                    {
                        
                      # If it was an actual Consistent Device Name (CDN)

                        $NetworkAdapterCDN =
                            $Computer.PhysicalMachine.NetworkAdapters | Where-Object -FilterScript {
                                $psItem.CommonDeviceName -eq $NetworkAdapterProfileCurrentName
                            }

                      # If it was device Location

                        $NetworkAdapterLocation =
                            $Computer.PhysicalMachine.NetworkAdapters | Where-Object -FilterScript {
                                $psItem.Location -eq $NetworkAdapterProfileCurrentName
                            }

                        If
                        (
                            $NetworkAdapterCDN
                        )
                        {
                            $NetworkAdapter = $NetworkAdapterCDN

                            $Message = "  Physical NIC was located by Consistent Device Name (CDN): `“$NetworkAdapterProfileCurrentName`”"
                            Write-Verbose -Message $Message

                            $NetworkAdapterParam.Add(            
                                "ConsistentDeviceName", $NetworkAdapter.CommonDeviceName
                            )                            
                        }
                        ElseIf
                        (
                            $NetworkAdapterLocation
                        )
                        {
                            $NetworkAdapter = $NetworkAdapterLocation

                            $Message = "  Physical NIC was located by Location: `“$NetworkAdapterProfileCurrentName`” — and will be fetched by MAC address"
                            Write-Verbose -Message $Message

                            $PhysicalAddressString = $NetworkAdapter.macAddress.ToUpper().Replace( ":", "-" )
                            $PhysicalAddress = [System.Net.NetworkInformation.PhysicalAddress]::Parse( $PhysicalAddressString )

                            $NetworkAdapterParam.Add(
                                "macAddress", $PhysicalAddress
                            )
                        }
                        ElseIf
                        (
                            $NetworkAdapterProfileCurrentName.Contains( ' — ')
                        )
                        {
                            $Message = "  Physical NIC identity was specified using Slot-Port notation. Will use BMC connection to obtain this information"
                            Write-Verbose -Message $Message

                            $Slot = ( $NetworkAdapterProfileCurrentName -split ' — ' )[0]
                            $Port = ( $NetworkAdapterProfileCurrentName -split ' — ' )[1]

                            $bmcUserName = $RunAsAccountBmc.UserName
                            $bmcPasswordBinary = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $bmcPassword )
                            $bmcPasswordPlain  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( $bmcPasswordBinary )

                            Switch
                            (
                                $Computer.Manufacturer
                            )
                            {
                                "HP"
                                {
                                    $HPEiLOparam = @{

                                        IP       = $bmcAddress
                                        Username = $bmcUserName
                                        Password = $bmcPasswordPlain
                                        Verbose  = $False
                                    }
                                    $BmcConnection = Connect-HPEiLO @HPEiLOparam
                        
                                    $HPEiLONICInfoParam = @{

                                        Connection = $BmcConnection
                                        Verbose    = $False
                                    }
                                    $BmcNicInfo = Get-HPEiLONICInfo @HPEiLONICInfoParam

                                    $BmcNicSlotPort = $BmcNicInfo.NetworkAdapter.Ports | Where-Object -FilterScript { 

                                        $psItem.Location -eq $Slot
                                    }

                                    $BmcNicPort = $BmcNicSlotPort | Where-Object -FilterScript {

                                        $psItem.NetworkPort -eq $Port
                                    }

                                    Switch
                                    (
                                        @( $BmcNicPort ).Count
                                    )
                                    {
                                    0
                                        {
                                            $Message = @(
                                                "  There was no direct match for Slot and Port combination, based on the information from the BMC."
                                                "  (This probably means that Port information is incomplete in the BMC, which might be the case.)"
                                                "  Will now match the requested *Port number* with actual *PCI function number* (from Deep Discovery)"
                                                "  among MACs found on the same Slot (from BMC)"
                                            )
                                            $Message | ForEach-Object -Process { Write-Verbose -Message $psItem }

                                            $BmcNicPortDeepDiscovery = $Computer.PhysicalMachine.NetworkAdapters | Where-Object -FilterScript {
                                            
                                                $psItem.macAddress -in $BmcNicSlotPort.macAddress.toUpper() -and

                                                ($psItem.Location -split ", function ")[1] -eq ($Port -split "Port ")[1]-1
                                            }

                                            $BmcNicPort = $BmcNicSlotPort | Where-Object -FilterScript {

                                                $psItem.macAddress.ToUpper() -eq $BmcNicPortDeepDiscovery.macAddress
                                            }
                                        }

                                    1
                                        {
                                            $Message = "  Physical NIC port was located successfully using Slot and Port information from the BMC."
                                            Write-Verbose -Message $Message
                                        }

                                    Default
                                        {
                                            $Message = @(
                                                "  More than one physical NIC ports were located by search criteria based on the port number"
                                                "  This probably means that the port number is specified ambiguously or incorrect in either BMC or in search criteria"
                                                "  e.g. `“Port 0`” does not typically represent a valid port. Instead it means that the actual port number could not be detected."
                                            )
                                            $Message | ForEach-Object -Process { Write-Verbose -Message $psItem }
                                        }
                                    }

                                    $BmcNic = $BmcNicInfo.NetworkAdapter | Where-Object -FilterScript {                            
                                        $psItem.Ports.macAddress -eq $BmcNicPort.macAddress
                                    }

                                    $BmcNicName = $BmcNic.Name

                                    $PhysicalAddressString = $BmcNicPort.macAddress.ToUpper().Replace( ":", "-" )
                                    $PhysicalAddress = [System.Net.NetworkInformation.PhysicalAddress]::Parse( $PhysicalAddressString )
                                }

                                Default
                                {
                                    $Message = "  Unknown server manufacturer, cannot work with BMC to obtain Physical NIC details"
                                    Write-Warning -Message $Message
                                }
                            }

                            If
                            (
                                $PhysicalAddress
                            )
                            {                            
                                $Message = "    `“$BmcNicName`”, $Slot, $Port will be fetched by MAC address `“$PhysicalAddress`”"
                                Write-Verbose -Message $Message

                                $NetworkAdapterParam.Add(            
                                    "macAddress", $PhysicalAddress
                                )

                             <# EXPERIMENT: set CND on a pNIC which does not support actual CDN
                              # if that works, and does not break the provisioning, we could use
                              # the PCP object later to obtain the pNIC name and rename the actual
                              # pNIC after the server is provisioned

                                Update: nope, it actually breaks provisioning 
                                because VMM tries to match the pNIC to CDN.

                              # Note that we cannot use the “AdatpterName” parameter for the same
                              # purpose because it's missing from the only parameter set which
                              # includes “UplinkPortProfileSet” parameter.

                                $NetworkAdapterParam.Add(
                                    "ConsistentDeviceName", $NetworkAdapterProfileCurrentName
                                )  #>

                              # This is only required to query for pNIC status and display it later

                                $NetworkAdapter = $Computer.PhysicalMachine.NetworkAdapters | Where-Object -FilterScript {

                                    $psItem.macAddress -eq $BmcNicPort.macAddress
                                }
                            }
                            Else
                            {
                                $Message = "  We connected to BMC, but could not locate the Physical NIC port"
                                Write-Warning -Message $Message
                            }
                        }
                        Else
                        {
                            $Message = "  No physical NIC could be located by CDN, device Location or BMC"
                            Write-Warning -Message $Message
                        }
                    }

                    Else

                  # This should be an edge case where no pNIC name is supplied.
                  # One potential option is to pre-fill the known MAC addreses
                  # in advance. The current script version does not handle that.

                    {
                        $Message = "  Adapter Name is empty. This is unexpected"
                        Write-Verbose -Message $Message
                    
                        $NetworkAdapterParam.Add(
                
                            "macAddress",
                            ""
                        )
                    }

                    If
                    (
                        $NetworkAdapter.State -eq "Connected"
                    )
                    {
                        $Message = "    `“$( $NetworkAdapter.ProductName )`” at `“$( $NetworkAdapter.Location )`” is connected at $( $NetworkAdapter.DataRate / 1000000000 ) Gbps"
                        Write-Verbose -Message $Message
                    }
                    Else
                    {
                        $Message = "    `“$( $NetworkAdapter.ProductName )`” at `“$( $NetworkAdapter.Location )`” is not connected!"
                        Write-Warning -Message $Message
                    }
                }
                
                Else

              # Configuration specific to Virtual NICs

                {
                    Write-Verbose -Message "  This is a Virtual adapter"

                    $PortClassification = $NetworkAdapterProfileCurrent.PortClassification
                    $vmNetwork          = $NetworkAdapterProfileCurrent.vmNetwork
                    $LogicalNetwork     = $vmNetwork.LogicalNetwork
                
                    $GetScSubnetVlanExParam = @{
                
                        LogicalNetwork = $LogicalNetwork
                        vmHostGroup    = $vmHostGroup
                    }                
                    $SubnetVlan = Get-scSubnetVlanEx @GetScSubnetVlanExParam

                    $Subnet = $SubnetVlan[0].Subnet

                  # Define common Virtual Network Adapter properties

                    $NetworkAdapterParam.Add(
                        "SetAsVirtualNetworkAdapter", $True
                    )

                    $NetworkAdapterParam.Add(
                        "UseStaticIPForIPConfiguration", $True
                    )

                    $NetworkAdapterParam.Add(
                        "vmNetwork", $vmNetwork
                    )

                    $NetworkAdapterParam.Add(
                        "AdapterName", $NetworkAdapterProfileCurrentName
                    )

                    $NetworkAdapterParam.Add(
                        "PortClassification", $PortClassification
                    )

                    $NetworkAdapterParam.Add(
                        "IpV4Subnet", $Subnet
                    )

                    If
                    (
                        $NetworkAdapterProfileCurrent.IsManagementNic
                    )
                    {
                        Write-Verbose -Message "  This is a Management adapter, it will inherit properties from the Physical NIC"

                        $NetworkAdapterParam.Add(
                            "SetAsManagementNIC", $True
                        )

                       #region Select Transient Management Network Adapter

                            $NetworkAdapterConfigurationSwitch = 
                                $NetworkAdapterConfiguration |
                                    Where-Object -FilterScript {

                                        (
                                            $psItem.LogicalSwitch -eq $NetworkAdapterProfileCurrent.LogicalSwitch
                                        ) -and
                                        (
                                            $psItem.IsPhysicalNetworkAdapter -eq $True
                                        )
                                    }

                            $NetworkAdapterConfigurationSort =
                                $NetworkAdapterConfigurationSwitch |
                                    Sort-Object -Property @( "ConsistentDeviceName", "macAddress" )

                            $NetworkAdapterConfigurationTransient =
                                $NetworkAdapterConfigurationSort |
                                    Select-Object -First 1

                            $Message = "  Transient network adapter found: `“"

                          # For this adapter, we need to enable DNS registration,
                          # and it was disabled by default. We cannot change it
                          # dynamically, because Physical computer network adapter
                          # object is read-only. So we need to remove this one
                          # from the collection, and then create a new one with
                          # all the same properties, except for DNS registration.

                            $NetworkAdapterParamTransient = @{

                                vmmServer                     = $vmmServer
                                SetAsPhysicalNetworkAdapter   = $NetworkAdapterConfigurationTransient.IsPhysicalNetworkAdapter
                                LogicalSwitch                 = $NetworkAdapterConfigurationTransient.LogicalSwitch
                                UplinkPortProfileSet          = $NetworkAdapterConfigurationTransient.UplinkPortProfileSet
                                DisableAdapterDNSRegistration = $False
                            }

                            If
                            (
                                $NetworkAdapterConfigurationTransient.macAddress
                            )
                            {
                                $Message += $NetworkAdapterConfigurationTransient.macAddress
                                
                                $NetworkAdapterParamTransient.Add(
                                    "macAddress",
                                    $NetworkAdapterConfigurationTransient.macAddress
                                )
                            }

                            If
                            (
                                $NetworkAdapterConfigurationTransient.ConsistentDeviceName
                            )
                            {
                                $Message += $NetworkAdapterConfigurationTransient.ConsistentDeviceName

                                $NetworkAdapterParamTransient.Add(
                                    "ConsistentDeviceName",
                                    $NetworkAdapterConfigurationTransient.ConsistentDeviceName
                                )
                            }

                            $Message += "`”. The adapter will be redefined with DNS registration enabled."
                            Write-Verbose -Message $Message

                            [void]$NetworkAdapterConfiguration.Remove(
                                $NetworkAdapterConfigurationTransient
                            )

                            $NetworkAdapterConfigurationTransient =
                                New-scPhysicalComputerNetworkAdapterConfig @NetworkAdapterParamTransient

                            $NetworkAdapterConfiguration.Add(
                                $NetworkAdapterConfigurationTransient
                            )

                       #endregion Select Transient Management Network Adapter

                        $NetworkAdapterParam.Add(
                            "TransientManagementNetworkAdapter",
                            $NetworkAdapterConfigurationTransient
                        )

                      # Allocate Static IP address to the host

                        If
                        (
                            $ipAddressManagement
                        )
                        {
                            $ipAddress = Get-scIPAddress -IPAddress $ipAddressManagement.IPAddressToString
                            
                            If
                            (
                                $ipAddress
                            )
                            {
                                $Message = "  The IP Address specified is already allocated in the pool!"
                                Write-Warning -Message $Message
                            }
                            Else
                            {                            
                                $Message = "  Assigning Static IP Address $ipAddressManagement"
                                Write-Verbose -Message $Message

                                $NetworkAdapterParam.Add(
                                    "IPv4Address",
                                    $ipAddressManagement.IPAddressToString
                                )
                            }
                        }
                        Else
                        {
                            $Message = "  Static IP address was not specified"
                            Write-Verbose -Message $Message
                        }
                    }
                    Else
                    {

                 <# The following is a workaround to obtain MAC Address from the Pool.
                  # It is not needed since VMM 2012 R2 Update Rollup 8
                  # (https://support.microsoft.com/help/3096389)

                    $GetScVirtualNetworkAdapterParam = @{

                        ParentTypeVMOrHost = $True
                        All                = $True
                        vmmServer          = $vmmServer
                    }                
                    $VirtualNetworkAdapterTemporary = Get-scVirtualNetworkAdapter @GetScVirtualNetworkAdapterParam |
                        Sort-Object -Property "macAddress" | Select-Object -Last 1

                    $macAddressDescription = "Temporary MAC Address for Physical Computer Network Adapter Configuration $Name"

                    $GrantScmacAddressParam = @{
                
                        macAddressPool        = $macAddressPool
                        Description           = $macAddressDescription
                        VirtualNetworkAdapter = $VirtualNetworkAdapterTemporary
                    }
                    $macAddress = Grant-scmacAddress @GrantScmacAddressParam
                    $macAddress = Revoke-scmacAddress -AllocatedmacAddress $macAddress
                    $macAddressString = $macAddress.Address

                    Write-Verbose -Message "Granted Staic MAC Address $macAddressString"

                    $NetworkAdapterParam.Add(
                        "macAddress", $macAddressString
                    )  #>

                      # To choose MAC from the default VMM MAC address pool, you can
                      # specify the MAC address as 00:00:00:00:00:00.

                        $NetworkAdapterParam.Add(
                            "macAddress", "00:00:00:00:00:00"
                        )
                    }
                }

              # Both Physical and Virtual NICs can be Generic

                If
                (
                    $NetworkAdapterProfileCurrent.IsGenericNic
                )
                {
                    $NetworkAdapterParam.Add(
                        "SetAsGenericNIC", $True
                    )
                }

              # Both Physical and Virtual NICs can have Logical Switch defined

                If
                (
                    $NetworkAdapterProfileCurrent.LogicalSwitch
                )
                {
                    $LogicalSwitch = $NetworkAdapterProfileCurrent.LogicalSwitch

                    $NetworkAdapterParam.Add(
                        "LogicalSwitch", $LogicalSwitch
                    )

                    If
                    (
                        $NetworkAdapterProfileCurrent.IsPhysicalNetworkAdapter
                    )
                    {
                        $UplinkPortProfileSet =
                            $NetworkAdapterProfileCurrent.UplinkPortProfileSet
                    
                        $NetworkAdapterParam.Add(
                            "UplinkPortProfileSet", $UplinkPortProfileSet
                        )
                    }
                }

                $NetworkAdapterConfiguration.Add(
                    ( New-scPhysicalComputerNetworkAdapterConfig @NetworkAdapterParam )
                )
            }

       #endregion Build properties for Node Physical Computer Network Adapter Configuration

      # Build Physical Computer Configuration

      # $NetworkAdapterConfiguration = $NetworkAdapterConfiguration.ToArray()

      # $Message = "  Total number of Physical Computer Network Adapter Configurations: $( $NetworkAdapterConfiguration.Count )"
      # Write-Verbose -Message $Message

        $ConfigurationParam = @{

            ComputerName                         = $Name
            Description                          = $Description
            PhysicalComputerProfile              = $Template
            PhysicalComputerNetworkAdapterConfig = $NetworkAdapterConfiguration
            bmcAddress                           = $bmcAddress
            BMCPort                              =  623
            BMCProtocol                          = "IPMI"
            BMCRunAsAccount                      = $RunAsAccountBmc
            smBiosGuid                           = $Computer.SMBiosGUID
            vmmServer                            = $vmmServer
            BypassADMachineAccountCheck          = $False
          # SkipBmcPowerControl                  = $False
        }
        
        If
        (
            $vmHostGroup
        )
        {
            $ConfigurationParam.Add(
                "vmHostGroup", $vmHostGroup
            )
        }
        
        $Configuration = New-scPhysicalComputerConfig @ConfigurationParam

      # $Message = "  Total number of Physical Computer Configurations: $( @( $Configuration ).Count )"
      # Write-Verbose -Message $Message

      # $Message = "  Object produced, name: `“Configuration`”, type: `”$( $Configuration.GetType().FullName )`”"
      # Write-Verbose -Message $Message

        Write-Verbose -Message "Exiting  New-scConfigurationEx for $Name"

        Return $Configuration

   #endregion Code
}