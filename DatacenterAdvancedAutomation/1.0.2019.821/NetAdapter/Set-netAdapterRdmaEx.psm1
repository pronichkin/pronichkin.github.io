Function
Set-netAdapterRdmaEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.cimSession[]]
        $Session
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]
        $Policy
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SwitchName = 'Storage'
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $FrameSize = 9014
    )

    $ModuleName = @(

      # 'Hyper-V'
        'NetQos'
        'DcbQos'
        'SmbShare'
    )
    [void]( Import-ModuleEx -Name $ModuleName )

    $Session | Sort-Object -Property 'ComputerName' | ForEach-Object -Process {

        $SessionCurrent = $psItem

        $Message = "Setting Network adapter properties, QoS and DCB on `“$( $SessionCurrent.ComputerName )`”"
        Write-Verbose -Message $Message

        $Switch           = Get-vmSwitch         -cimSession $SessionCurrent -Name $SwitchName
        $SwitchTeam       = Get-vmSwitchTeam     -cimSession $SessionCurrent -vmSwitch $Switch

      # For vNICs, we cannot sort by MAC Address — because even though they are
      # created artificially in consistent order, the MAC address order appears
      # to be non-deterministic. Sometimes the “A” vNIC gets lower MAC address,
      # and sometimes it's the “B” vNIC. However, as the vNICs are created
      # with predictable names, we can sort by them.

        $vmNetworkAdapter = Get-vmNetworkAdapter -cimSession $SessionCurrent -SwitchName $SwitchName -ManagementOS | Sort-Object -Property 'Name'
        $vNetAdapter      = Get-netAdapterEx     -cimSession $SessionCurrent -vmNetworkAdapter $vmNetworkAdapter   | Sort-Object -Property 'Name'

        $Message = "  Found $( @( $vNetAdapter ).Count ) virtual network adapter(s):"
        Write-Verbose -Message $Message

        0..( $vNetAdapter.Count -1 ) | ForEach-Object -Process {

            $Message = "    $( $vNetAdapter[ $psItem ].Name )    $( $vmNetworkAdapter[ $psItem ].Name )"
            Write-Verbose -Message $Message
        }

      # For pNICs, we cannot rely on MAC Addresses, because cards in different
      # slots are not expected to have consistent MACs. Hence we need to query
      # for physical PCI location

        $pNetAdapterHardwareInfo = Get-netAdapterHardwareInfo -cimSession $SessionCurrent | Where-Object -FilterScript {
            [System.Guid]$psItem.InstanceID -in $SwitchTeam.NetAdapterInterfaceGuid
        } | Sort-Object -Property @( 'Bus', 'Device', 'Function' )
    
        $pNetAdapter = $pNetAdapterHardwareInfo | ForEach-Object -Process {
            Get-netAdapterEx -cimSession $SessionCurrent -DeviceID $psItem.InstanceID
        }

        $Message = "  Found $( @( $pNetAdapter ).Count ) physical network adapter(s):"
        Write-Verbose -Message $Message

        0..( $pNetAdapter.Count -1 ) | ForEach-Object -Process {

            $Message = "    $( $pNetAdapter[ $psItem ].Name )"
            Write-Verbose -Message $Message
        }

        $Message = "  Defining affinity (mapping) between physical and virtual network adapters"
        Write-Verbose -Message $Message

        If
        (
            $pNetAdapter.Count -eq $vNetAdapter.Count
        )
        {
            0..( $pNetAdapter.Count -1 ) | ForEach-Object -Process {

                $Message = "    $( $vmNetworkAdapter[ $psItem ].Name )  →  $( $pNetAdapter[ $psItem ].Name )"
                Write-Verbose -Message $Message

                $NetworkAdapterTeamMappingParam = @{

                  # ManagementOS           = $True
                    PhysicalNetAdapterName = $pNetAdapter[ $psItem ].Name
                    vmNetworkAdapter       = $vmNetworkAdapter[ $psItem ]
                  # cimSession             = $SessionCurrent 
                  # Passthru               = $True
                }    
                Set-vmNetworkAdapterTeamMapping @NetworkAdapterTeamMappingParam
            }
        }
        Else
        {
            Write-Warning -Message "  Number of pNic and vNic mismatch!"
        }

        $Message = "  Switching SMB Signing and Encrypting to non-mandatory"
        Write-Verbose -Message $Message

      # These parameters apply both to SMB Client and SMB Server

        $SmbConfigurationParam = @{

             EnableSecuritySignature  = $True
             RequireSecuritySignature = $False
             cimSession               = $SessionCurrent
             Confirm                  = $False
        }
        Set-smbClientConfiguration @SmbConfigurationParam

      # These parameters only apply to SMB Server but not SMB Client

        $SmbConfigurationParam.Add( 'EncryptData',             $False )
        $SmbConfigurationParam.Add( 'RejectUnencryptedAccess', $False )
    
        Set-smbServerConfiguration @SmbConfigurationParam

        $Message = "  Defining Network QoS"
        Write-Verbose -Message $Message

        $DcbxSetting = @{

            Willing    = $False
            cimSession = $SessionCurrent
            Confirm    = $False
        }
        Set-netQosDcbxSetting @DcbxSetting

        $Policy | ForEach-Object -Process {

            $Name = $psItem.Name

            $PolicyCurrent = Get-netQosPolicy -cimSession $SessionCurrent | Where-Object -FilterScript { $psItem.Name -eq $Name }

            If
            (
                $PolicyCurrent
            )
            {
                $Message = "    Qos Policy for $( $psItem.Name ) already exists with priority $( $PolicyCurrent.PriorityValue8021Action )"
                Write-Verbose -Message $Message
            }
            Else
            {
                $PolicyParam = @{

                    Name                        = $psItem.Name
                  # $psItem.Name                = $True        
                    PriorityValue8021Action     = $psItem.Priority
                    cimSession                  = $SessionCurrent
                }

                If
                (
                    $psItem[ "PortNd" ]
                )
                {
                    $PolicyParam.Add( "NetDirectPortMatchCondition", $psItem.PortNd )
                }

                If
                (
                    $psItem[ "Port" ]
                )
                {
                    $PolicyParam.Add( "IPDstPortMatchCondition", $psItem.Port )
                }

                $Message = "    Qos Policy for $( $psItem.Name ), priority $( $psItem.Priority )"
                Write-Verbose -Message $Message        

                [void]( New-netQosPolicy @PolicyParam )
            }

            $ClassCurrent = Get-netQosTrafficClass -cimSession $SessionCurrent | Where-Object -FilterScript { $psItem.Name -eq $Name }

            If
            (
                $ClassCurrent
            )
            {
                $Message = "    Qos Traffic Class for $( $psItem.Name ) already exists with priority $( $ClassCurrent.Priority ) and Bandwidth Percentage $( $ClassCurrent.BandwidthPercentage )"
                Write-Verbose -Message $Message
            }
            Else
            {
                $ClassParam = @{

                    Name                = $psItem.Name
                    Priority            = $psItem.Priority
                    BandwidthPercentage = $psItem.Bandwidth
                    Algorithm           = 'ETS'
                    cimSession          = $SessionCurrent
                }

                $Message = "    Qos Traffic Class for $( $psItem.Name ), priority $( $psItem.Priority ), Bandwidth Percentage $( $psItem.Bandwidth )"
                Write-Verbose -Message $Message

                [void]( New-netQosTrafficClass @ClassParam  )
            }
        }
        
        $Message = "  Enabling Priority Flow Control (PFC) for Priorities $( $Policy.Priority )"
        Write-Verbose -Message $Message

        $FlowControlParam = @{

            Priority   = $Policy.Priority
            cimSession = $SessionCurrent
        }
        Enable-netQosFlowControl @FlowControlParam

        $Message = "  Setting Network Adapter Advanced Properties"
        Write-Verbose -Message $Message

        $Message = "    Disabling regular Flow Control (`“Global Pause`”) since it's incompatible with PFC"
        Write-Verbose -Message $Message

        $AdvancedPropertyParam = @{

            DisplayName          = 'Flow Control'
            DisplayValue         = 'Disabled'
            InterfaceDescription = $pNetAdapter.InterfaceDescription
            cimSession           = $SessionCurrent
          # PassThru             = $True
        }
        Set-netAdapterAdvancedProperty @AdvancedPropertyParam

        $Message = "    Setting Frame size to $FrameSize on physical network adapters (`“Jumbo Frames`”)"
        Write-Verbose -Message $Message

        $AdvancedPropertyParam.DisplayName  = 'Jumbo Packet'
        $AdvancedPropertyParam.DisplayValue = $FrameSize
    
        Set-netAdapterAdvancedProperty @AdvancedPropertyParam

        $Message = "    Setting Frame size to $FrameSize on virtual network adapters (`“Jumbo Frames`”)"
        Write-Verbose -Message $Message

      # “Display Value” uses a slightly different notation here.

        $AdvancedPropertyParam.InterfaceDescription = $vNetAdapter.InterfaceDescription
        $AdvancedPropertyParam.DisplayValue         = "$FrameSize Bytes"

        Set-netAdapterAdvancedProperty @AdvancedPropertyParam

        $Message = "  Enabling network adapter features"
        Write-Verbose -Message $Message

        $AdapterParam = @{
    
            InterfaceDescription = $pNetAdapter.InterfaceDescription
            cimSession           = $SessionCurrent
          # PassThru             = $True
        }

        $Message = "    QoS on physical network adapter(s)"
        Write-Verbose -Message $Message

        Enable-netAdapterQos  @AdapterParam

        $Message = "    RDMA on physical network adapter(s)"
        Write-Verbose -Message $Message

        Enable-netAdapterRdma @AdapterParam

        $Message = "    RDMA on virtual network adapter(s)"
        Write-Verbose -Message $Message

        $AdapterParam.InterfaceDescription = $vNetAdapter.InterfaceDescription

        Enable-netAdapterRdma @AdapterParam
    }
}