<#
    define network settings on a given node

    Input options inlcude:

  * Create Logical Switch instance using VMM.
  * Create NIC Team and a tNIC.
  * Assign IP Address to NIC directroy.
  * Disble NIC.

#>

Set-StrictMode -Version 'Latest'

Function
Set-netAdapterEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            @( $psItem )[0].GetType().FullName -in @(

                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                'Microsoft.SystemCenter.VirtualMachineManager.VM'
                'Microsoft.ActiveDirectory.Management.adComputer'
                'System.String'
            )
        })]
        [System.Collections.ArrayList]
        $Node
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        $NetworkAdapterGroupProperty
    ,
        [Parameter(
            Mandatory = $False
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
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString]
        $bmcPassword
    )

    Begin
    {
        $Message = 'Entering Set-netAdapterEx'
        Write-Debug -Message $Message

        $ModuleName = @(

            'NetAdapter'
            'NetTcpIp'
            'NetLbfo'
        )

        [System.Void]( Import-ModuleEx -Name $ModuleName )
    }

    Process
    {
        $Node | Sort-Object -Property 'Name' | ForEach-Object -Process {

            $NodeCurrent = $psItem

           #region 0/5  Obtain all physical network adapters of the server

                Switch
                (
                    $NodeCurrent.GetType().FullName
                )
                {
                    {
                        $psItem -in @(
                            'Microsoft.SystemCenter.VirtualMachineManager.Host'
                            'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                        )
                    }
                    {
                      # Vmm Management Server is used to obtain further objects

                        $vmmServer   = $NodeCurrent.ServerConnection
                        $NodeAddress = $NodeCurrent.Name
                    }

                    'Microsoft.SystemCenter.VirtualMachineManager.Host'
                    {
                        $GetscvmHostNetworkAdapterParam = @{
                            vmHost = $NodeCurrent
                        }
                        $NetworkAdapterAll = Get-scvmHostNetworkAdapter @GetscvmHostNetworkAdapterParam

                        $NetworkAdapterPhysical = $NetworkAdapterAll | Where-Object -FilterScript {
        
                            $psItem.Name -NotLike "Microsoft Network Adapter Multiplexor Driver*"
                        }

                        $NetworkAdapterPhysical = $NetworkAdapterPhysical | Sort-Object -Property "MaxBandwidth", "macAddress"

                      # This value will be used to fetch relevant Static IP Address Pool

                        $Location = $NodeCurrent.vmHostGroup

                        $SiteName = $Location.ParentHostGroup.Name

                        $PropertyName = 'ConnectionName'                        
                    }

                    'System.String'
                    {
                        $NodeAddress = $NodeCurrent
                    }

                    {
                        $psItem -in @(

                            'Microsoft.ActiveDirectory.Management.adComputer'
                            'Microsoft.SystemCenter.VirtualMachineManager.VM'
                        )
                    }
                    {
                        $NodeAddress = Resolve-dnsNameEx -Name $NodeCurrent.Name
                    }

                    {
                        $psItem -in @(
                            'Microsoft.SystemCenter.VirtualMachineManager.Host'
                            'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                            'Microsoft.SystemCenter.VirtualMachineManager.VM'
                            'Microsoft.ActiveDirectory.Management.adComputer'
                            'System.String'
                        )
                    }
                    {
                        $Session = New-cimSessionEx -Name $NodeAddress
                    }

                    {
                        $psItem -in @(
                            'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                            'Microsoft.SystemCenter.VirtualMachineManager.VM'
                            'Microsoft.ActiveDirectory.Management.adComputer'
                            'System.String'
                        )
                    }
                    {
                        $NetAdapterParam = @{

                            cimSession = $Session
                            Physical   = $True
                        }
                        $NetworkAdapterPhysical = Get-netAdapterEx @NetAdapterParam

                        $Location = $SiteName

                        $PropertyName = 'Name'
                    }

                    Default
                    {
                        $Message = "Unexpected `“Node`” object type: `“$psItem`”"
                        Write-Warning -Message $Message
                    }
                }

                Write-Verbose -Message "  All Physical NICs (including disabled) on $($NodeAddress):"

                $NetworkAdapterPhysical | Sort-Object -Property $PropertyName | ForEach-Object -Process {
                        
                    $Message = "  * $( $psItem.$PropertyName )"
                    Write-Verbose -Message $Message
                }

                $NetworkAdapter = [System.Collections.Generic.List[Microsoft.Management.Infrastructure.CimInstance]]::new()

           #endregion Obtain all physical network adapters of the server

           #region 1/5  Adapter metadata (Name & Description)

                $Message = '  Step 1/5.  Setting network adapter metadata (name and description)'
                Write-Verbose -Message $Message

               #region Build

                    Switch
                    (
                        $NodeCurrent.GetType().FullName
                    )
                    {
                        'Microsoft.SystemCenter.VirtualMachineManager.Host'
                        {
                            $CustomPropertyParam = @{

                                Name           = 'Manufacturer'
                                vmmServer      = $NodeCurrent.ServerConnection
                            }
                            $CustomProperty = Get-scCustomProperty @CustomPropertyParam

                            $CustomPropertyValueParam = @{

                                InputObject    = $NodeCurrent
                                CustomProperty = $CustomProperty
                                vmmServer      = $NodeCurrent.ServerConnection
                            }
                            $CustomPropertyValue = Get-scCustomPropertyValue @CustomPropertyValueParam

                            $Manufacturer = $CustomPropertyValue.Value
                        }

                        {
                            $psItem -in @(                            
                                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                'Microsoft.SystemCenter.VirtualMachineManager.VM'
                                'Microsoft.ActiveDirectory.Management.adComputer'
                                'System.String'
                            )
                        }
                        {
                            $System       = Get-ComputerSystem -Session $Session
                            $Manufacturer = $System.Manufacturer
                        }
                    }

                    $bmcData = @()

                    $Message = '    Obtaining information from BMC'
                    Write-Debug -Message $Message

                    Switch
                    (
                        $Manufacturer
                    )
                    {
                        {
                            $psItem -ne 'Microsoft Corporation'
                        }
                        {    
                            $bmcAddress  = $NodeCurrent.PhysicalMachine.bmcAddress
                            $bmcUserName = $NodeCurrent.PhysicalMachine.RunAsAccount.UserName
                            $bmcPasswordBinary = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $bmcPassword )
                            $bmcPasswordPlain  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( $bmcPasswordBinary )
                        }

                        'HP'
                        {
                            If
                            (
                                -not ( Get-Module -Name 'HPEiLOCmdlets' )
                            )
                            {
                                $Message = "    HP iLO Module was not found"
                                Write-Error -Message $Message
                            }

                            $HPEiLOparam = @{

                                IP       = $bmcAddress
                                Username = $bmcUserName
                                Password = $bmcPasswordPlain
                                Verbose  = $False
                            }
                            $BmcConnection = Connect-HPEiLO @HPEiLOparam
                        
                            $BmcParam = @{

                                Connection = $BmcConnection
                                Verbose    = $False
                            }
                            $BmcNicInfo = Get-HPEiLONICInfo @BmcParam
                            $BmcFirmwareInventory = Get-HPEiLOFirmwareInventory @BmcParam

                            $Count = 1

                            $BmcNicInfo.NetworkAdapter | ForEach-Object -Process {

                                $NetworkAdapterCurrent = $psItem

                                $Message = "    pNIC $Count of $( $BmcNicInfo.NetworkAdapter.Count )  `“$( $NetworkAdapterCurrent.Name )`”"
                                Write-Verbose -Message $Message

                                If
                                (
                                    $NetworkAdapterCurrent.Ports.Count -ge 2
                                )
                                {                    
                                    $PortStatus = $NetworkAdapterCurrent.Ports.Status | Sort-Object -Unique

                                    If
                                    (
                                        @( $PortStatus ).Count -eq 1 -and
                                        $PortStatus -eq 'Unknown'
                                    )
                                    {
                                        $Message = "      Both ports have `“Unknown`” status. Please investigate iLO for potential inconsistencies"
                                        Write-Warning -Message $Message
                                    }                                       

                                    $NetworkAdapterBaseName = $NetworkAdapterCurrent.Name.Split( '#' )[0] + '*'

                                    While
                                    (
                                        -not (
                                           $BmcFirmwareInventory.FirmwareInformation | Where-Object -FilterScript { $psItem.FirmwareName -like $NetworkAdapterBaseName }
                                        )
                                    )
                                    {                        
                                        $Message = "      Incomplete Firmware Information. Number of entries retrieved: $( $BmcFirmwareInventory.FirmwareInformation.Count ). Could not locate pNIC in Firmware data returned by iLO. Reconnecting and retrying..."
                                        Write-Warning -Message $Message

                                        Start-Sleep -Seconds 10

                                        $BmcConnection = Connect-HPEiLO @HPEiLOparam
                                        $BmcParam.Connection = $BmcConnection

                                        $BmcNicInfo           = Get-HPEiLONICInfo @BmcParam
                                        $BmcFirmwareInventory = Get-HPEiLOFirmwareInventory @BmcParam
                                    }

                                    $Firmware = $BmcFirmwareInventory.FirmwareInformation | Where-Object -FilterScript { $psItem.FirmwareName -eq $NetworkAdapterCurrent.Name }

                                    If
                                    (
                                        $Firmware
                                    )
                                    {
                                        $Message = "      Firmware information was successfully obtained from BMC using direct name match"
                                        Write-Verbose -Message $Message
                                    }
                                    Else
                                    {
                                        $Firmware = $BmcFirmwareInventory.FirmwareInformation | Where-Object -FilterScript { $psItem.FirmwareName -like $NetworkAdapterBaseName } | Sort-Object | Select-Object -First 1

                                        If
                                        (
                                            $Firmware
                                        )
                                        {
                                            $Message = "      Firmware information was obtained from BMC using wildcard match. This possibly indicates inconsistencies in BMC information"
                                            Write-Warning -Message $Message
                                        }
                                        Else
                                        {
                                            $Message = "      Could not locate Firmware information in BMC"
                                            Write-Error -Message $Message
                                        }
                                    }

                                    $NetworkAdapterCurrent.Ports | ForEach-Object -Process {

                                        $PhysicalAddressString = $psItem.macAddress.ToUpper().Replace( ":", "-" )
                                        $PhysicalAddress = [System.Net.NetworkInformation.PhysicalAddress]::Parse( $PhysicalAddressString )

                                        If
                                        (
                                            @( $NetworkAdapterCurrent.Ports.NetworkPort | Sort-Object -Unique ).Count -eq 1
                                        )
                                        {
                                            $Message = '      All ports indicate as “Port 0”. Will try to guess based on MAC addresses'
                                            Write-Warning -Message $Message

                                            $PortNumber = ( $NetworkAdapterCurrent.Ports | Sort-Object -Property 'MacAddress' ).IndexOf( $psItem ) + 1

                                          # This is to accomodate for edge case where iLO 
                                          # returns 2 dual-port NICs as single quad-port.
                                          # (Slot information for each port is still correct
                                          # in this case.)

                                            If
                                            (
                                                $PortNumber -gt 2
                                            )
                                            {
                                                $PortNumber = $PortNumber - 2
                                            }

                                            $PortName = "Port $PortNumber"
                                        }
                                        Else
                                        {
                                            If
                                            (
                                                $psItem.NetworkPort -eq 'Port 0' -and
                                                $psItem.Status      -eq 'Unknown'                    
                                            )
                                            {
                                              # we're dealing with a bogus port
                    
                                                $PortTotal = $NetworkAdapterCurrent.Ports.Count

                                                $PortKnown = $NetworkAdapterCurrent.Ports | Where-Object -FilterScript {
                            
                                                  # ( $psItem | Get-Member -Name 'NetworkPort' ) -and
                                                    $psItem.NetworkPort -ne 'Port 0' # -and
                                                  # $psItem.Status      -ne 'Unknown'
                                                }

                                                $PortKnownNumber = $PortKnown.NetworkPort.Replace( 'Port ', '' )

                                                $PortNumber = 1..$PortTotal | Where-Object -FilterScript { $psItem -notin $PortKnownNumber }

                                                $PortName = "Port $PortNumber"
                                            }
                                            Else
                                            {
                                                $PortName = $psItem.NetworkPort
                                            }
                                        }

                                        $bmcData += @{

                                          # Port            = $PortName
                                          # Slot            = $psItem.Location
                                            Name            = $psItem.Location + ' — ' + $PortName
                                            PhysicalAddress = $PhysicalAddress
                                            Firmware        = $Firmware.FirmwareVersion
                                        }
                                    }
                                }
                                Else
                                {
                                    $Message = "      pNIC has unexpected number of ports: $( $NetworkAdapterCurrent.Ports.Count ). It probably indicates iLO inconsistency. This pNIC will be skipped"
                                    Write-Warning -Message $Message
                                }

                                $Count++
                            }
                        }

                        'Microsoft Corporation'
                        {
                            $NetworkAdapterPhysical | ForEach-Object -Process {

                                $PhysicalAddress = [System.Net.NetworkInformation.PhysicalAddress]::Parse( $psItem.LinkLayerAddress )

                                $PropertyParam = @{
                                
                                    Name        = $psItem.Name
                                  # Name        = 'Ethernet'
                                    DisplayName = 'Hyper-V Network Adapter Name'
                                    CimSession  = $Session
                                }
                                $Property = Get-NetAdapterAdvancedProperty @PropertyParam

                                $bmcData += @{

                                    Name            = $Property.ValueData[0]
                                    PhysicalAddress = $PhysicalAddress
                                }
                            }
                        }

                        Default
                        {
                            $Message = "Unknown Server manufacturer `“$Manufacturer`”"
                            Write-Warning -Message $Message
                        }
                    }

               #endregion Build

               #region Set

                    $NetworkAdapterPhysical | Sort-Object -Property 'PhysicalAddress' | ForEach-Object -Process {

                        $NetworkAdapterCurrent = $psItem

                        $Message = "  Processing physical network adapter `“$($NetworkAdapterCurrent.Name)`”"
                        Write-Verbose -Message $Message                        

                        Switch
                        (
                            $psItem.GetType().FullName
                        )
                        {
                            'Microsoft.SystemCenter.VirtualMachineManager.HostNetworkAdapter'
                            {
                                $PhysicalAddressString = $NetworkAdapterCurrent.PhysicalAddress.ToUpper().Replace( ":", "-" ).TrimEnd()
                                $NetworkAdapterVmm     = $NetworkAdapterCurrent
                                $NetworkAdapterNative  = Get-netAdapterEx -cimSession $Session -PhysicalAddress $PhysicalAddress |
                                    Where-Object -FilterScript { $NetworkAdapterCurrent.HardwareInterface }
                            }
                        
                            'Microsoft.Management.Infrastructure.CimInstance'
                            {
                                $PhysicalAddressString = $NetworkAdapterCurrent.LinkLayerAddress
                                $NetworkAdapterNative  = $NetworkAdapterCurrent
                            }

                            {
                                $True
                            }
                            {
                                $PhysicalAddress = [System.Net.NetworkInformation.PhysicalAddress]::Parse( $PhysicalAddressString )
                                $NetworkAdapter.Add( $NetworkAdapterNative )
                            }

                            'Microsoft.SystemCenter.VirtualMachineManager.HostNetworkAdapter'
                            {
                                $NetworkAdapterNative  = Get-netAdapterEx -cimSession $Session -PhysicalAddress $PhysicalAddress |
                                    Where-Object -FilterScript { $psItem.HardwareInterface }
                            }

                            {
                                $True
                            }
                            {                    
                                $NetworkAdapterBmc = $bmcData | Where-Object -FilterScript { $psItem.PhysicalAddress -eq $PhysicalAddress }

                              # $Name = $NetworkAdapterBmc.Slot + ' — ' + $NetworkAdapterBmc.Port
                                $Name = $NetworkAdapterBmc.Name

                                $Message = "    Renaming to `“$Name`”"
                                Write-Debug -Message $Message

                                Rename-netAdapter -InputObject $NetworkAdapterNative -NewName $Name

                              # Set-TcpIpNetBios -netAdapter $NetworkAdapterNative -TcpIpNetBiosOption DisableNetBios

                                Switch
                                (
                                    $NetworkAdapterNative.Status
                                )
                                {
                                    'Disconnected'
                                    {
                                        $Message = "    Disabling the adapter because it's currently disconnected"
                                        Write-Debug -Message $Message

                                        Disable-netAdapter -InputObject $NetworkAdapterNative -Confirm:$False
                                        $Status = 'Disabled'
                                    }

                                    'Not Present'
                                    {
                                        $Status = 'Disabled'
                                    }

                                    Default
                                    {
                                        $Status = $NetworkAdapterNative.Status
                                    }
                                }
                            }

                            'Microsoft.SystemCenter.VirtualMachineManager.HostNetworkAdapter'
                            {                        
                                $Description = "$Name
Location: $($NetworkAdapterVmm.BDFLocationInformation)
Status: $Status
Manufacturer: $($NetworkAdapterNative.DriverProvider)
Model: $($NetworkAdapterNative.DriverDescription)
$($NetworkAdapterNative.DriverInformation)
Firmware: $($NetworkAdapterBmc.Firmware)

Information updated $( ( Get-Date -DisplayHint DateTime ).DateTime )"

                                $Message = "    Setting metadata in VMM"
                                Write-Debug -Message $Message

                                $HostNetworkAdapterParam = @{

                                    vmHostNetworkAdapter = $NetworkAdapterVmm
                                    Description          = $Description
                                }

                                [void]( Set-scvmHostNetworkAdapter @HostNetworkAdapterParam )
                            }
                        }
                    }

               #endregion Set

           #endregion Rename adapter

           #region 2/5  Global server-wide configuration

                $Message = '  Step 2/5.  Server-wide networking setting'
                Write-Verbose -Message $Message

                $ImageInfo = Get-WindowsImageInfo -ComputerName $NodeAddress

                If
                (
                    $ImageInfo.GetValue( 'ReleaseId' ) -lt 1809
                )
                {
                    $Message = '    Setting congestion algorythm to CUBIC'
                    Write-Debug -Message $Message
                    
                    $Setting = Get-netTcpSetting -cimSession $Session |
                        Where-Object -FilterScript { $psItem.SettingName -notin @( 'Automatic', 'Compat' ) }
    
                    $SettingParam = @{

                        InputObject        = $Setting
                        CongestionProvider = 'CUBIC'
                    }
                    Set-netTcpSetting @SettingParam
                }

                $Message = '    Disabling TCP/IP NetBIOS'
                Write-Debug -Message $Message

                $NetBiosParam = @{

                    NetAdapter         = $NetworkAdapter
                    TcpIpNetBiosOption = 'DisableNetBios'
                }
                Set-TcpIpNetBios @NetBiosParam

              # Remove-cimSession -cimSession $Session

                Switch
                (
                    $NodeCurrent.GetType().FullName
                )
                {
                    'Microsoft.SystemCenter.VirtualMachineManager.Host'
                    {
                        If
                        (
                            $NodeCurrent.HostCluster
                        )
                        {
                            $Message = "  The node is already clustered, skipping refresh"
                            Write-Debug -Message $Message
                        }
                        Else
                        {
                            $Message = "  Refreshing host to pick new adapter names and state"
                            Write-Debug -Message $Message

                            [System.Void]( Read-scvmHost -vmHost $NodeCurrent )
                        }
                    }
                }

           #endregion Global server-wide configuration

           #region 3/5  Template-based adapter configuration

                $Message = '  Step 3/5.  Template-based configuration'
                Write-Verbose -Message $Message

                If
                (
                    $NetworkAdapterGroupProperty
                )
                {
                  # Now we're going to loop through all network types defined 
                  # in Physical Computer Template (as “Physical Computer 
                  # Network Adapter Group Property”) and configure physical 
                  # adapters as specified

                  # Note: this assumes that adapters are already renamed
                  # to their “final” permanent names (done by Step 1 above)

                    $Skip = 0
    
                $NetworkAdapterGroupProperty | ForEach-Object -Process {

                    $NetworkAdapterGroupCurrentProperty = $psItem

                   #region Get Physical Adapters

                        Write-Verbose -Message "  ***"
                        Write-Verbose -Message "  Starting New pass"
                        Write-Verbose -Message "    Host Name: $NodeAddress"
                      # Write-Verbose -Message ( "Pass Name: " + $NetworkAdapterGroupCurrentProperty.Type )

                      # Get Adapters by Name
            
                        If
                        (
                            $NetworkAdapterGroupCurrentProperty.Name
                        )
                        {

                            Write-Verbose -Message "    Fetching by Name"

                            If
                            (
                                $NetworkAdapterGroupCurrentProperty.Name -is "System.String"
                            )
                            {
                                $SearchMask = $NetworkAdapterGroupCurrentProperty.Name + "*"

                                Write-Verbose -Message "    Wildcard mode. Searching for: $SearchMask"
                
                                $NetworkAdapterCurrentType = @(
                
                                    $NetworkAdapterPhysical |
                                    Where-Object -FilterScript {
                                        $psItem.Name -match $SearchMask
                                    }
                                )
                            }

                            ElseIf
                            (
                                $NetworkAdapterGroupCurrentProperty.Name -is "System.Array"
                            )
                            {
                                Write-Verbose -Message "    Exact match mode. Searching for:"

                                $NetworkAdapterGroupCurrentProperty.Name | Sort-Object | ForEach-Object -Process {

                                    $Message = "      $psItem"
                                    Write-Verbose -Message $Message
                                }
                
                                $NetworkAdapterCurrentType = @(

                                    $NetworkAdapterPhysical |
                                        Where-Object -FilterScript {
                                    
                                            $NetworkAdapterPhysicalCurrent = $psItem

                                            Switch
                                            (
                                                $Node.GetType().FullName
                                            )
                                            {
                                                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                                {
                                                    $NetworkAdapterPhysicalCurrentName =
                                                        $NetworkAdapterPhysicalCurrent.ConnectionName
                                                }

                                                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                                {
                                                    $NetworkAdapterPhysicalCurrentName =
                                                        $NetworkAdapterPhysicalCurrent.Name
                                                }
                                            }

                                            $NetworkAdapterPhysicalCurrentName -in
                                                $NetworkAdapterGroupCurrentProperty.Name
                                       }
                                )
                            }
                        }

                        Else

                      # Get Adapters by Count

                        {
                            Write-Verbose -Message "    Fetching by Count"
                            Write-Verbose -Message ( "Skipping " + $Skip )

                            $NetworkAdapterCurrentType = @(

                                $NetworkAdapterPhysical |
                                Select-Object -First $NetworkAdapterGroupCurrentProperty.Count -Skip $Skip
                            )

                            Write-Verbose -Message ( "Fetched " + $NetworkAdapterCurrentType.Count + " NIC(s)" )
        
                            $Skip += $NetworkAdapterCurrentType.Count
                        }

                   #endregion Get Physical Adapters

                   #region Configure Physical Adapters

                        If
                        (
                            $NetworkAdapterCurrentType
                        )
                        {
                            Write-Verbose -Message "    Adapters for this pass:"

                            $NetworkAdapterCurrentType | Sort-Object -Property 'Name' | ForEach-Object -Process {
                    
                                $Message = "      $( $psItem.Name )"
                                Write-Verbose -Message $Message                    
                            } 

                           #region Get Adapter Names

                                Switch
                                (
                                    $Node.GetType().FullName
                                )
                                {
                                    'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                    {
                                        $NetworkAdapterCurrentTypeName = $NetworkAdapterCurrentType.ConnectionName
                                    }

                                    'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                    {
                                        $NetworkAdapterCurrentTypeName = $NetworkAdapterCurrentType.Name
                                    }
                                }

                           #endregion Get Adapter Names

                           #region Check for IP Address on these Adapters

                                $NetworkAdapterWithIPAddress = @()
                                $NetworkAdapterIPAddress     = @()

                                $NetworkAdapterCurrentType | ForEach-Object -Process {
                
                                    $NetworkAdapterCurrent = $psItem

                                    Switch
                                    (
                                        $Node.GetType().FullName
                                    )
                                    {
                                        'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                        {
                                            $IPAddresses = $NetworkAdapterCurrent.IPAddresses
                                        }

                                        'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                        {
                                            $NetIPAddressAll = Get-netIPAddress -cimSession $NodeAddress
                                            $NetIPAddress = $NetIPAddressAll | Where-Object -FilterScript {
                                                $psItem.InterfaceAlias -eq $NetworkAdapterCurrent.Name
                                            }
                                            $IPAddressesString = $NetIPAddress.IPAddress
                                            $IPAddresses = [System.Net.IPAddress[]]$IPAddressesString
                                        }
                                    }

                                    $IPAddresses | ForEach-Object -Process {
            
                                        $IPAddressesCurrent = $psItem

                                        If (
                                            ( $IPAddressesCurrent.AddressFamily -eq "InterNetwork" ) -and 
                                            ( $IPAddressesCurrent.IPAddressToString -notmatch "169.254*" ) -and
                                            ( $IPAddressesCurrent.IPAddressToString -notmatch "127.0.0*" ) 
                                        )
                                        {               
                                           $NetworkAdapterWithIPAddress += $NetworkAdapterCurrent
                                           $NetworkAdapterIPAddress     += $IPAddressesCurrent
                                        }
                                    }               
                                }

                                If
                                (
                                    $NetworkAdapterWithIPAddress
                                )
                                {
                                    $Message = "    VM Host Network Adapter with IP Address:"
                                    Write-Verbose -Message $Message

                                    $Message = "      $NetworkAdapterWithIPAddress"
                                    Write-Verbose -Message $Message
                                }

                                If
                                (
                                    $NetworkAdapterIPAddress
                                )
                                {
                                    $Message = "    VM Host Network Adapter IP Address:"
                                    Write-Verbose -Message $Message

                                    $Message = "      $NetworkAdapterIPAddress"
                                    Write-Verbose -Message $Message
                                }

                           #endregion Check for IP Address on these Adapters

                           #region Create an instance of Logical Switch if needed

                                If
                                (
                                    $NetworkAdapterGroupCurrentProperty.Contains( "LogicalSwitchName" )
                                )
                                {
                                    Write-Verbose -Message "  Start pass: Switch"

                                    $NetworkAdapterCurrentTypeNoSwitch =
                                        $NetworkAdapterCurrentType | Where-Object -FilterScript {

                                            $psItem.VirtualNetwork -eq $Null
                                        }

                                    If
                                    (
                                        $NetworkAdapterCurrentTypeNoSwitch
                                    )
                                    {
                                        Write-Verbose -Message "Selected Adapter(s): $NetworkAdapterCurrentTypeNoSwitch"

                                      # Get Logical Switch

                                        $GetSCLogicalSwitchParam = @{

                                            Name      = $NetworkAdapterGroupCurrentProperty.LogicalSwitchName 
                                            vmmServer = $vmmServer
                                        }
                                        $LogicalSwitch = Get-scLogicalSwitch @GetSCLogicalSwitchParam

                                        If
                                        (
                                            $NodeSetName
                                        )
                                        {
                                            $Location = $NodeSetName
                                        }
                                        Else
                                        {
                                            $Location = $SiteName
                                        }

                                        $UplinkPortProfileSet = Get-scUplinkPortProfileSetEx -LogicalSwitch $LogicalSwitch -Location $Location -Role $ScaleUnitType

                                      #region Calculate Virtual Network Adapters Params

                                            $ManagementAdapterParam           = $Null
                                            $NewScVirtualNetworkAdapterParams = @()

                                            If
                                            (
                                                $NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty
                                            )
                                            {

                                                $NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty | ForEach-Object -Process {

                                                    $NetworkAdapterGroupCurrentStaticIpAddressProperty = $psItem

                                                  # Get vmNetwork

                                                    $GetSCvmNetworkParam = @{

                                                        Name      = $NetworkAdapterGroupCurrentStaticIpAddressProperty.NetworkName
                                                        vmmServer = $vmmServer
                                                    }
                                                    $vmNetwork = Get-scvmNetwork @GetSCvmNetworkParam

                                                  # Get Port Classification
        
                                                    $GetSCPortClassificationParam = @{

                                                        Name      = $NetworkAdapterGroupCurrentStaticIpAddressProperty.PortClassificationName
                                                        vmmServer = $vmmServer
                                                    }
                                                    $PortClassification = Get-scPortClassification @GetSCPortClassificationParam

                                                  # Get IP Pool. Current convention is that
                                                  # there's only one Static IP Address Pool per
                                                  # Logical Network per Site, and the
                                                  # Pool name is the same ase Site Name.
                                 
                                                    $StaticIpAddressPoolName = $SiteName

                                                    $GetScStaticIPAddressPoolExParam = @{

                                                        vmNetwork               = $vmNetwork
                                                        StaticIpAddressPoolName = $StaticIpAddressPoolName
                                                        Location                = $Location
                                                        vmmServer               = $vmmServer
                                                    }

                                                 <# Write-Verbose -Message "Fetching Static IP Address Pool with the following paramters:"
                            
                                                    $GetSCStaticIPAddressPoolExParam.GetEnumerator() | ForEach-Object -Process {

                                                        Write-Verbose -Message ( "  Name:  " + $psItem.Name )
                                                        Write-Verbose -Message ( "  Value: " + $psItem.Value )
                                                    } #>

                                                    $StaticIPAddressPool = Get-scStaticIPAddressPoolEx @GetSCStaticIPAddressPoolExParam

                                                  # Check $NetworkAdapterIPAddres for IP Address by Virtual Adapter Name (= Physical Adapter Type)

                                                    If
                                                    (
                                                        (
                                                            $NetworkAdapterIPAddress
                                                        ) -and
                                                        (
                                                            $NetworkAdapterGroupCurrentStaticIpAddressProperty.Contains( "TransferIpAddress" )
                                                        )
                                                    )
                                                    {
                                                        $ManagementAdapterParam = @{

                                                            CreateManagementAdapter             = $true
                                                            ManagementAdapterName               = $NetworkAdapterGroupCurrentStaticIpAddressProperty.NetworkName
                                                            ManagementAdapterPortClassification = $PortClassification
                                                            ManagementAdaptervmNetwork          = $vmNetwork
                                                        } 
                                                    }
                                                    Else
                                                    {
                                                        $NewScVirtualNetworkAdapterParam = @{

                                                            Name               = $NetworkAdapterGroupCurrentStaticIpAddressProperty.NetworkName
                                                            vmHost             = $Node
                                                            vmNetwork          = $vmNetwork
                                                            LogicalSwitch      = $LogicalSwitch
                                                            PortClassification = $PortClassification
                                                            IPv4AddressType    = "Static"
                                                            IPv4AddressPool    = $StaticIPAddressPool
                                                        }                       
                                                        $NewScVirtualNetworkAdapterParams += $NewScVirtualNetworkAdapterParam 
                                                    }                        
                                                }
                                            }

                                       #endregion Calculate Virtual Network Adapters Params

                                       #Revoke IP Assigned Address, if it was used

                                        If
                                        (
                                            $NetworkAdapterIPAddress
                                        )
                                        {
                                            $NetworkAdapterIPAddress | ForEach-Object -Process {

                                                $NetworkAdapterIPAddressCurrent = $psItem

                                              # Get IP Address

                                                $GetSCIPAddressParam = @{
                                                    IPAddress = $NetworkAdapterIPAddressCurrent.IPAddressToString
                                                    vmmServer = $vmmServer
                                                }
                                                $AllocatedIPAddress = Get-scIPAddress @GetSCIPAddressParam

                                                If
                                                (
                                                    $AllocatedIPAddress
                                                )
                                                {
                                                    $RevokeSCIPAddressParam = @{
                                                        AllocatedIPAddress = $AllocatedIPAddress
                                                        vmmServer          = $vmmServer
                                                    }
                                                    $RevokeIPAddress = Revoke-scIPAddress @RevokeSCIPAddressParam
                                                }
                                            }
                                        }

                                      # Assign Hyper-V Port Profile Set for Uplink to Adapters

                                        $vmHostNetworkAdapters = @()

                                        $NetworkAdapterCurrentTypeNoSwitch | ForEach-Object -Process {

                                            $NetworkAdapterCurrentTypeCurrent = $psItem

                                            $SetscvmHostNetworkAdapterParam = @{

                                                vmHostNetworkAdapter  = $NetworkAdapterCurrentTypeCurrent
                                                UplinkPortProfileSet  = $UplinkPortProfileSet
                                                AvailableForPlacement = $true
                                            }

                                            If
                                            (
                                                $NewScVirtualNetworkAdapterParams
                                            )
                                            {
                                                $SetscvmHostNetworkAdapterParam.Add(
                                                    "UsedForManagement",
                                                    $true
                                                )
                                            }

                                            $vmHostNetworkAdapters += Set-scvmHostNetworkAdapter @SetscvmHostNetworkAdapterParam
                                        }

                                      # Try to obtain Virtual Switch

                                        $VirtualNetworkParam = @{
                                    
                                            LogicalSwitch         = $LogicalSwitch
                                        }

                                        $VirtualNetwork = Get-scVirtualNetwork -vmHost $Node |
                                            Where-Object -FilterScript { $psItem.Name -eq $LogicalSwitch.Name }

                                        If
                                        (
                                            $VirtualNetwork
                                        )
                                        {
                                            Write-Verbose -Message "Logical Switch Instance already exists. Addining pNIC to existing vSwitch."

                                            $vmHostNetworkAdaptersAll = $vmHostNetworkAdapters += $VirtualNetwork.vmHostNetworkAdapters

                                            $VirtualNetworkParam.Add(
                                                "vmHostNetworkAdapters", $vmHostNetworkAdaptersAll
                                            )
                                            $VirtualNetworkParam.Add(
                                                "VirtualNetwork", $VirtualNetwork
                                            )

                                            $VirtualNetwork = Set-scVirtualNetwork @VirtualNetworkParam
                                        }
                                        Else
                                        {

                                          # Create an Instance of Logical Switch

                                            $VirtualNetworkParam.Add(
                                                "Description", "Created by " + $env:USERNAME + " with " + $MyInvocation.MyCommand.Name
                                            )
                                            $VirtualNetworkParam.Add(
                                                "vmHost", $Node
                                            )
                                            $VirtualNetworkParam.Add(
                                                "vmHostNetworkAdapters", $vmHostNetworkAdapters
                                            )

                                            If
                                            (
                                                $ManagementAdapterParam
                                            )
                                            {
                                                $VirtualNetworkParam +=
                                                $ManagementAdapterParam 
                                            }
                
                                            $VirtualNetwork = New-scVirtualNetwork @VirtualNetworkParam
                                        }

                                      # Create Virtual Network Adapters

                                        $NewScVirtualNetworkAdapterParams | ForEach-Object -Process {
                    
                                            $NewScVirtualNetworkAdapterParamsCurrent = $psItem

                                            $VirtualNetworkAdapter = New-scVirtualNetworkAdapter @NewScVirtualNetworkAdapterParamsCurrent
                                        }
                                     <#
                                        $SetscvmHostParam = @{
                                            vmHost = $Node
                                        }
                                        $SetvmHost = Set-scvmHost @SetscvmHostParam
                                     #>
                                    }
                                    Else
                                    {

                                      # Some Virtual Switch (either Standard or an instance of Logical)
                                      # is already present on these NICs. Skpping.

                                        Write-Verbose -Message "    NICs are already busy by the following Switch(es):"

                                      # $NetworkAdapterCurrentType | Select-Object -Property "ConnectionName","VirtualNetwork" | Write-Verbose

                                        $NetworkAdapterCurrentType | ForEach-Object -Process {

                                            $Message = "      NIC name: `“$( $psItem.ConnectionName )`”, Switch name: `“$( $psItem.VirtualNetwork )`”"
                                            Write-Verbose -Message $Message
                                        }

                                        Write-Verbose -Message "    Skipping Switch creation."
                                    }
                                }

                           #endregion Create an instance of Logical Switch if needed

                           #region Create Nic Teaming if needed

                                ElseIf
                                (
                                    $NetworkAdapterGroupCurrentProperty.Contains( "NicTeamProperty" )
                                )
                                {                
                                    Write-Verbose -Message "Start pass: Teaming"

                                    $NetLbfoTeam = $null

                                    Try
                                    {
                                        $GetNetLbfoTeamParam = @{
                
                                            Name        = $NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty.NetworkName
                                            cimSession  = $NodeAddress
                                            ErrorAction = "Ignore"
                                        }
                                        $NetLbfoTeam = Get-netLbfoTeam @GetNetLbfoTeamParam
                                    }
                                    Catch
                                    {

                                      # There's no team yet.
                                      # We will create one.
                
                                    }

                                    If
                                    (
                                        $NetLbfoTeam
                                    )
                                    {
                                        $Message = "The NIC Team $($NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty.NetworkName) already exists."
                                        Write-Verbose -Message $Message
                                    }
                                    Else
                                    {
                                        $Message = "Creating NIC Team $($NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty.NetworkName)"
                                        Write-Verbose -Message $Message

                                      # Get vmNetwork

                                        $GetSCvmNetworkParam = @{

                                            Name      = $NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty.NetworkName
                                            vmmServer = $vmmServer
                                        }
                                        $vmNetwork = Get-scvmNetwork @GetSCvmNetworkParam

                                      # Get IP Pool

                                        $StaticIpAddressPoolName = $SiteName

                                        $GetSCStaticIPAddressPoolExParam = @{

                                            vmNetwork               = $vmNetwork
                                            StaticIpAddressPoolName = $StaticIpAddressPoolName
                                            Location                = $Location
                                            vmmServer               = $vmmServer
                                        }
                                        $StaticIPAddressPool = Get-scStaticIPAddressPoolEx @GetSCStaticIPAddressPoolExParam

                                      # Get Prefix Length

                                        $PrefixLength = $StaticIPAddressPool.Subnet.Split("/")[1]

                                      # Create NIC Team
               
                                        $NewNetLbfoTeamParam = @{

                                            Name                   = $NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty.NetworkName
                                            TeamMembers            = $NetworkAdapterCurrentTypeName
                                            TeamingMode            = $NetworkAdapterGroupCurrentProperty.NicTeamProperty.TeamingMode
                                            LoadBalancingAlgorithm = $NetworkAdapterGroupCurrentProperty.NicTeamProperty.LoadBalancingAlgorithm
                                            cimSession             = $NodeAddress
                                            Confirm                = $False
                                        }
                                        $NetLbfoTeam = New-netLbfoTeam @NewNetLbfoTeamParam

                                      # Assign VLanID to the tNIC

                                        If (
                                            $StaticIPAddressPool.VLanID -ne 0
                                        )
                                        {
                                            $SetNetLbfoTeamNicParam = @{
                        
                                                Name       = $NetLbfoTeam.TeamNics
                                                Team       = $NetLbfoTeam.Name
                                                VlanID     = $StaticIPAddressPool.VLanID
                                                cimSession = $NodeAddress
                                                Confirm    = $false
                                            }
                                            Set-netLbfoTeamNic @SetNetLbfoTeamNicParam
                                        }

                                      # Grant IP Address to the Adapter

                                        $GrantSCIPAddressParam = @{

                                            GrantToObjectType   = "HostNetworkAdapter"
                                            StaticIPAddressPool = $StaticIPAddressPool
                                          # GrantToObjectID     = $NetworkAdapterCurrentTypeCurrent.ID
                                            vmmServer           = $vmmServer
                                            Description         = $NodeAddress
                                        }
                                        $GrantIPAddress = Grant-scIPAddress @GrantSCIPAddressParam

                                        Write-Verbose -Message "Granted:"
                                        Write-Verbose -Message $GrantIPAddress

                                      # Obtain tNIC as NetAdapter

                                        $NetAdapterParam = @{

                                            Name       = $NetLbfoTeam.TeamNics
                                            cimSession = $NodeAddress
                                        }
                                        $NetAdapter = Get-netAdapterEx @NetAdapterParam

                                        Write-Verbose -Message "Fetched tNIC"

                                      # Need to wait to work around a bug

                                        Start-Sleep -Seconds 5

                                      # Assign DNS Server Addresses

                                        If (
                                            $StaticIPAddressPool.DNSServers
                                        )
                                        {
                                            $SetDnsClientServerAddressParam = @{

                                                InterfaceIndex  = $NetAdapter.ifIndex
                                                ServerAddresses = $StaticIPAddressPool.DNSServers
                                                cimSession      = $NodeAddress
                                            }
                                            Set-DnsClientServerAddress @SetDnsClientServerAddressParam
                                        }

                                        Write-Verbose -Message "DNS Servers assigned to the tNIC"

                                      # Assign IP Address

                                      # In current implementation this might result
                                      # in network connection loss to the server. This is probably
                                      # because there were multiple IP Addresses on the pNICs
                                      # (e.g. assigned with DHCP). We were using one of them, and
                                      # another one was selected for the team. Now we no longer can
                                      # reconnect because the new IP address will never get to DNS
                                      # since the DNS servers were not yet assigned to the NIC. The
                                      # solution for this issue is TBD. Maybe it would be enough
                                      # to just set DNS servers on adapter before changing
                                      # IP Address. We're trying to implement this now, but it still
                                      # might be insufficient.

                                        $NewNetIPAddressParam = @{

                                            InterfaceIndex = $NetAdapter.ifIndex
                                            IPAddress      = $GrantIPAddress.Address
                                            PrefixLength   = $PrefixLength
                                            cimSession     = $NodeAddress
                                        }
                                        $NetIPAddress = New-netIPAddress @NewNetIPAddressParam 

                                        Write-Verbose -Message "IP Address assigned to the NIC"

                                      # Additional saftety measures in case we're dealing with a VM Host.

                                        Switch
                                        (
                                            $Node.GetType().FullName
                                        )
                                        {
                                            'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                            {

                                          # Since the pNICs are used exclusively for the Team
                                          # we need to disable them for placement
                                          # from Vmm standpoint.

                                            $vmHostNetworkAdapters = @()

                                            $NetworkAdapterCurrentType | ForEach-Object -Process {

                                                $NetworkAdapterCurrentTypeCurrent = $psItem

                                                $SetscvmHostNetworkAdapterParam = @{

                                                    vmHostNetworkAdapter  = $NetworkAdapterCurrentTypeCurrent
                                                    AvailableForPlacement = $False
                                                    UsedForManagement     = $False
                                                }
                                                $vmHostNetworkAdapters +=
                                                    Set-scvmHostNetworkAdapter @SetscvmHostNetworkAdapterParam
                                            }

                                          # We also need to disable for placement the new tNIC.
                                          # But first we need to recognize it in Vmm, thus refresh.

                                            $vmHostCurrent = Read-scvmHost -vmHost $Node

                                            $NetworkAdapterTeam = Get-scvmHostNetworkAdapter -vmHost $Node |
                                                Where-Object -FilterScript {
                                                    $psItem.ConnectionName -eq $NetLbfoTeam.Name
                                                }

                                            $SetscvmHostNetworkAdapterParam = @{

                                                vmHostNetworkAdapter  = $NetworkAdapterTeam
                                                AvailableForPlacement = $False
                                                UsedForManagement     = $False
                                            }
                                            $vmHostNetworkAdapters +=
                                                Set-scvmHostNetworkAdapter @SetscvmHostNetworkAdapterParam
                                            }

                                            'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                            {

                                              # We're good

                                            }
                                        }
                                    }
                                }

                           #endregion Create Nic Teaming if needed

                           #region Assign IP Addresses to the Physical Adapters

                                ElseIf
                                (
                                    $NetworkAdapterGroupCurrentProperty.Contains( "StaticIpAddressProperty" )
                                )
                                {

                                    Write-Verbose -Message "Start pass: Stand-alone"
                    
                                  # If there was Adapter with IP address already, then exclude
                                  # it from $NetworkAdapterCurrentType List

                                    If
                                    (
                                        $NetworkAdapterWithIpAddress
                                    )
                                    {
                                        $NetworkAdapterNoIpAddress = $NetworkAdapterCurrentType |
                                            Where-Object -FilterScript {
                                                $psItem.Name -notin $NetworkAdapterWithIPAddress.Name
                                            }
                                    }
                                    Else
                                    {
                                        $NetworkAdapterNoIpAddress = $NetworkAdapterCurrentType
                                    }

                                    If
                                    (
                                        $NetworkAdapterNoIpAddress
                                    )
                                    {

                                      # Calculate IP Address Parameters for Physical Adapters and Grant IP Addresses

                                        $vmHostNetworkAdapters = @()

                                        $NetworkAdapterNoIpAddress | ForEach-Object -Process {
                    
                                            $NetworkAdapterCurrentTypeCurrent = $psItem

                                            $Message = "Processing Adapter: $NetworkAdapterCurrentTypeCurrent"
                                            Write-Verbose -Message $Message

                                          # If dealing with VM Host, we need to translate
                                          # the Vmm Host Network Adapter object to Network Adapter.

                                            Switch
                                            (
                                                $Node.GetType().FullName
                                            )
                                            {
                                                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                                {
                                                    $NetAdapterParam = @{

                                                        Name       = $NetworkAdapterCurrentTypeCurrent.ConnectionName
                                                        cimSession = $NodeAddress
                                                    }
                                                    $NetAdapter = Get-netAdapterEx @NetAdapterParam
                                                }
                    
                                                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                                {
                                                    $NetAdapter = $NetworkAdapterCurrentTypeCurrent
                                                }
                                            }

                                          # Get vmNetwork

                                            $GetSCvmNetworkParam = @{

                                                Name      = $NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty.NetworkName
                                                vmmServer = $vmmServer
                                            }
                                            $vmNetwork = Get-scvmNetwork @GetSCvmNetworkParam

                                          # Get IP Pool

                                            $StaticIpAddressPoolName = $SiteName

                                            $GetSCStaticIPAddressPoolExParam = @{

                                                vmNetwork               = $vmNetwork
                                                StaticIpAddressPoolName = $StaticIpAddressPoolName
                                                Location                = $Location
                                                vmmServer               = $vmmServer
                                            }
                                            $StaticIPAddressPool = Get-scStaticIPAddressPoolEx @GetSCStaticIPAddressPoolExParam

                                          # Get Prefix Length

                                            $PrefixLength = $StaticIPAddressPool.Subnet.Split("/")[1]

                                          # Grant IP Address to the Adapter

                                            $GrantSCIPAddressParam = @{

                                                GrantToObjectType   = "HostNetworkAdapter"
                                                StaticIPAddressPool = $StaticIPAddressPool
                                              # GrantToObjectID     = $NetworkAdapterCurrentTypeCurrent.ID
                                                vmmServer           = $vmmServer
                                                Description         = $NodeAddress
                                            }
                                            $GrantIPAddress = Grant-scIPAddress @GrantSCIPAddressParam

                                            Write-Verbose -Message "Granted:"
                                            Write-Verbose -Message $GrantIPAddress
                                            Write-Verbose -Message "Processing"

                                          # Assign VLanID to the Physical Adapter

                                            If
                                            (
                                                $StaticIPAddressPool.VLanID -ne 0
                                            )
                                            {

                                                $SetNetAdapterParam = @{

                                                    Name       = $NetAdapter.Name
                                                    VLanID     = $StaticIPAddressPool.VLanID
                                                    cimSession = $NodeAddress
                                                    Confirm    = $false
                                                }
                                                Set-netAdapter @SetNetAdapterParam
                                            }

                                          # Assign IP Address

                                            Write-Verbose -Message "Preparing to assign IP Address."

                                            $NewNetIPAddressParam = @{

                                                InterfaceIndex = $NetAdapter.ifIndex
                                                IPAddress      = $GrantIPAddress.Address
                                                PrefixLength   = $PrefixLength 
                                                cimSession     = $NodeAddress
                                            }

                                            $NewNetIPAddressParam.GetEnumerator() | ForEach-Object -Process {
                                                Write-Verbose -Message $psItem.Key
                                                Write-Verbose -Message $psItem.Value                        
                                            }

                                            $NetIPAddress = New-netIPAddress @NewNetIPAddressParam

                                            Write-Verbose -Message "Assigned IP Address:"
                                            Write-Verbose -Message $GrantIPAddress.Address

                                          # Assign DNS Server Addresses

                                            If (
                                                $StaticIPAddressPool.DNSServers
                                            )
                                            {
                                                $SetDnsClientServerAddressParam = @{

                                                    InterfaceIndex  = $NetAdapter.ifIndex
                                                    ServerAddresses = $StaticIPAddressPool.DNSServers
                                                    cimSession      = $NodeAddress
                                                }
                                                Set-DnsClientServerAddress @SetDnsClientServerAddressParam
                                            }

                                          # Safety measures in case we're working with Vmm

                                            Switch
                                            (
                                                $Node.GetType().FullName
                                            )
                                            {
                                                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                                {

                                                    $SetscvmHostNetworkAdapterParam = @{

                                                        vmHostNetworkAdapter  = $NetworkAdapterCurrentTypeCurrent
                                                        AvailableForPlacement = $False
                                                        UsedForManagement     = $False
                                                    }
                    
                                                    $vmHostNetworkAdapters +=
                                                        Set-scvmHostNetworkAdapter @SetscvmHostNetworkAdapterParam
                                                }

                                                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                                {

                                                  # We're good

                                                }
                                            }
                                        }
                                    }
                                    Else
                                    {
                                        $Message = "All adapters already have IP Address. Skipping."
                                        Write-Verbose -Message $Message
                                    }
                                }

                           #endregion Assign IP Addresses to the Physical Adapters

                           #region Disable Adapters

                                ElseIf
                                (
                                    $NetworkAdapterGroupCurrentProperty.Contains( "Disable" )
                                )
                                {
                                    Write-Verbose -Message "Start pass: Disable"

                                    $NetworkAdapterCurrentType | ForEach-Object -Process {
                    
                                        $NetworkAdapterCurrentTypeCurrent = $psItem

                                      # If dealing with VM Host, we need to translate
                                      # the Vmm Host Network Adapter object to Network Adapter.

                                        Switch
                                        (
                                            $Node.GetType().FullName
                                        )
                                        {
                                            'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                            {
                                                $NetAdapterParam = @{
                                                    Name = $NetworkAdapterCurrentTypeCurrent.ConnectionName
                                                    cimSession = $NodeAddress
                                                }
                                                $NetAdapter = Get-netAdapterEx @NetAdapterParam
                                            }
                    
                                            'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                            {
                                                $NetAdapter = $NetworkAdapterCurrentTypeCurrent
                                            }
                                        }

                                        $DisableNetAdapterParam = @{

                                            Name       = $NetAdapter.Name
                                            Confirm    = $False
                                            cimSession = $NodeAddress
                                        }
                                        Disable-netAdapter @DisableNetAdapterParam
                                    }
                                }

                           #endregion  Disable Adapters

                        }
                        Else
                        {
                            $Message = "There were no adapters found for this pass! Skipping."
                            Write-Verbose -Message $Message
                        }

                   #endregion Configure Physical Adapters

                }
                }
                Else
                {
                    $Message = '      There was no “Network Adapter Group” defined in the template. Skipping'
                    Write-Debug -Message $Message
                }

           #endregion Template-based adapter configuration

           #region 4/5  Network QoS configuration for RDMA

                $Message = '  Step 4/5.  Network QoS configuration for RDMA'
                Write-Verbose -Message $Message

                If
                (
                    $NetworkAdapterGroupProperty
                )
                {
                    $NetworkAdapterGroupProperty |
                        Where-Object -FilterScript { $psItem[ 'Policy' ] } | 
                            ForEach-Object -Process {

                        $RdmaParam = @{
                        
                            Session    = $Session
                            Policy     = $psItem.Policy
                            SwitchName = $psItem.LogicalSwitchName
                        }
                        Set-netAdapterRdmaEx @RdmaParam
                    }
                }
                Else
                {
                    $Message = '      There was no “Network Adapter Group” defined in the template. Skipping'
                    Write-Debug -Message $Message
                }

           #endregion 4/5  Network QoS configuration for RDMA

           #region 5/5  Network adapter affinity for VMQ/RSS

                $Message = '  Step 5/5.  Network adapter affinity for VMQ/RSS'
                Write-Verbose -Message $Message

                If
                (
                    $NetworkAdapterGroupProperty
                )
                {
                    Set-netAdapterAffinity -ComputerName $NodeAddress
                }
                Else
                {
                    $Message = '      This is not a physical server. Skipping'
                    Write-Debug -Message $Message
                }

           #endregion 5/5  Network adapter affinity for VMQ/RSS
        }
    }

    End
    {
        $Message = 'Exiting  Set-netAdapterEx'
        Write-Verbose -Message $Message
    }
}

# Set-Alias -Name "Set-DCAANodeNetwork" -Value "Set-netAdapterEx"