<#
    Perform non-disruptive Cluster Node configuration.
    This includes settings defined with Vmm (Scale Unit-specific),
    as well as generic Windows Server settings (including NIC configuration)
#>

Set-StrictMode -Version 'Latest'

Function
Set-clusterNodeEx
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
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Description
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateSet(
            'Compute',
            'Management',
            'Storage',
            'Network',
            'Virtual'
        )]
        [System.String]
        $ScaleUnitType
    ,
     <# [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $SiteProperty
     ,  #>
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $bmcAddress
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
        $RunAsAccountBmc
    ,
     <# [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
        $RunAsAccount
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        $vmmServer  # = $RunAsAccount.ServerConnection
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $PhysicalComputerHardwareProfile
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $OperatingSystemProfile
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
        [System.Uri]
        $applianceAddress
    ,  #>
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $applianceCredential
    ,
     <# [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $applianceModuleName = 'HPOneView.420'
    , #>
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.SwitchParameter]
        $Guarded
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $HgsUriScheme
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $MemoryDumpEncryptionCertificateThumbPrint
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Byte[]]
        $MemoryDumpEncryptionCertificatePublicKey
 <# ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Security.SecureString]
        $bmcPassword  #>
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection]
        $OpsMgrConnection
    )

    Begin
    {
        $Message = '  Entering Set-ClusterNodeEx'
        Write-Debug -Message $Message

       #region Establish session

            Switch
            (
                $Node[0].GetType().FullName
            )
            {
                {
                    $psItem -in @(
                        'Microsoft.SystemCenter.VirtualMachineManager.Host'
                        'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                        'Microsoft.SystemCenter.VirtualMachineManager.VM'
                        'Microsoft.ActiveDirectory.Management.adComputer'
                    )
                }
                {
                    [System.Collections.Generic.List[System.String]]$NodeAddress = $Node.Name
                }

                'System.String'
                {
                    [System.Collections.Generic.List[System.String]]$NodeAddress = $Node
                }

                Default
                {
                    $Message = "Unexpected `“Node`” object type: `“$psItem`”"
                    Write-Warning -Message $Message
                }
            }

            $cimSession = New-cimSessionEx -Name $NodeAddress
            $psSession  = New-psSession    -ComputerName $NodeAddress

       #endregion Establish session

       #region Obtain service address from Host Group metadata

            Switch
            (
                $ScaleUnitType
            ) 
            { 
                {
                    $psItem -in @(
                        'Management'
                        'Compute'
                        'Network'
                    )
                }
                {
                    If
                    (
                        $Guarded
                    )
                    {
                     <# We no longer derive HGS URLs from VMM server
                            settings because they can be different per host
 
                        $HostParam.Add(
                                "AttestationServerUrl", $vmmServer.AttestationServerUrl
                        )

                        $HostParam.Add(
                                "KeyProtectionServerUrl", $vmmServer.KeyProtectionServerUrl
                        )

                        $HostParam.Add(
                                "FallbackAttestationServerUrl", $vmmServer.FallbackAttestationServerUrl
                        )

                        $HostParam.Add(
                                "FallbackKeyProtectionServerUrl", $vmmServer.FallbackKeyProtectionServerUrl
                        )  #>       

                        $PropertyParam = @{

                            Name      = 'HGS Primary'
                            vmmServer = $Node[0].ServerConnection
                        }
                        $Property = Get-scCustomProperty @PropertyParam

                        $PropertyValueParam = @{
    
                            CustomProperty = $Property
                            HostGroup      = $Node[0].vmHostGroup
                        }
                        $PropertyValue = Get-scCustomPropertyValueEx @PropertyValueParam

                        $HgsAddressPrimary  = Resolve-DnsNameEx -Name $PropertyValue.Value

                        $HgsUriPrimary  = [System.Uri]::new( "$($HgsUriScheme)://$HgsAddressPrimary"  )    

                        $PropertyParam = @{

                            Name      = 'HGS Fallback'
                            vmmServer = $Node[0].ServerConnection
                        }
                        $Property = Get-scCustomProperty @PropertyParam

                        $PropertyValueParam = @{
    
                            CustomProperty = $Property
                            HostGroup      = $Node[0].vmHostGroup
                        }
                        $PropertyValue = Get-scCustomPropertyValueEx @PropertyValueParam

                        $HgsAddressFallback  = Resolve-DnsNameEx -Name $PropertyValue.Value

                        $HgsUriFallback = [System.Uri]::new( "$($HgsUriScheme)://$HgsAddressFallback" )
                    }
            
                 <# $PropertyParam = @{

                        Name      = 'DPM Server'
                        vmmServer = $Node[0].ServerConnection
                    }
                    $Property = Get-scCustomProperty @PropertyParam

                    $PropertyValueParam = @{
    
                        CustomProperty = $Property
                        HostGroup      = $Node[0].vmHostGroup
                    }
                    $PropertyValue = Get-scCustomPropertyValueEx @PropertyValueParam

                    $DpmServerAddress  = Resolve-DnsNameEx -Name $PropertyValue.Value  #>
            
                    $PropertyParam = @{

                        Name      = 'Appliance'
                        vmmServer = $Node[0].ServerConnection
                    }
                    $Property = Get-scCustomProperty @PropertyParam

                    $PropertyValueParam = @{
    
                        CustomProperty = $Property
                        HostGroup      = $Node[0].vmHostGroup
                    }
                    $PropertyValue = Get-scCustomPropertyValueEx @PropertyValueParam

                    $ApplianceAddress  = Resolve-DnsNameEx -Name $PropertyValue.Value

                    $ApplianceUri       = [System.Uri]::new( 'https://' + $ApplianceAddress )
                }

                Default
                {
                    $Message = "Not Host Group metatdata is available for Scale Unit type `“$psItem`”"
                    Write-Verbose -Message $Message
                }
            }

       #endregion Obtain service address from Host Group metadata

       #region Obtain hardware information from appliance

            $System = Get-ComputerSystem -Session $cimSession[0]

            Switch
            (
                $System.Manufacturer
            )
            {
             <# {
                    $psItem -in @( 'HP' )
                }
                {
                    $Module = Get-Module -Name $applianceModuleName

                    If
                    (
                        -not $Module
                    )
                    {
                        $Message = 'Appliance management module is not loaded'
                        Write-Error -Message $Message
                    }
                }  #>

                'HP'
                {
                  # Connect to HP OneView

                  # $appliancePasswordBinary = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $applianceCredential.Password )
                  # $appliancePasswordPlain  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( $appliancePasswordBinary )

                    $Message = "  Obtaining physical server topology from appliance `“$($ApplianceUri.Host)`”"
                    Write-Verbose -Message $Message

                    $hpovMgmtParam = @{

                        Hostname        = $ApplianceUri.Host
                        Credential      = $applianceCredential
                      # UserName        = $applianceCredential.UserName
                      # Password        = $appliancePasswordPlain
                        AuthLoginDomain = 'Local'
                        Verbose         = $False
                    }
                    $applianceConnection = Connect-hpovMgmt @hpovMgmtParam

                  # Obtain all racks from HP OneView

                    $hpovParam = @{ ApplianceConnection = $applianceConnection; Verbose = $False }

                    $Rack = Get-hpovRack @hpovParam

                    $RackMember = $Rack | ForEach-Object -Process {

                        Get-hpovRackMember @hpovParam -InputObject $psItem
                    }
                }

                Default
                {
                    $Message = "There's no appliance for `“$( $System.Manufacturer )`”"
                    Write-Verbose -Message $Message
                }
            }

       #endregion Obtain hardware information from appliance
    }

    Process
    {
       #region  1/6  Multi-node generic configuration

            $Message = '  Step 1/6  Multi-node generic configuration'
            Write-Verbose -Message $Message

          # Windows Optional Features
          # This is now done in Physical Computer Template (Profile) created
          # by “New-scPhysicalComputerTemplateEx” as “BareMetalPostUnattend”

          # Set-WindowsOptionalFeature -Session $psSession -FeatureNameDisable $OperatingSystemProfileCurrent.FeatureNameDisable -FeatureNameEnable $OperatingSystemProfileCurrent.FeatureNameEnable

            $Message = '      Setting Windows Capabilities'
            Write-Debug -Message $Message

            Set-WindowsCapability -Session $psSession

          # Power Plan

            $Message = '      Setting Power plan'
            Write-Debug -Message $Message

            $PlanParam = @{

                cimSession = $cimSession
                psSession  = $psSession
            }
            [System.Void]( Set-PowerPlan @PlanParam )

          # Disable Windows RE

            $Message = '      Disabling Windows RE'
            Write-Debug -Message $Message

            $Command = '
            
                $ErrorActionPreference = ''silentlyContinue''
                ReAgentC.exe /Disable
            '

            $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( $Command )

            $InvokeCommandParam = @{

                ScriptBlock  = $ScriptBlock
                Session      = $psSession
            }
            $Command = Invoke-Command @InvokeCommandParam

       #endregion  1/5  Multi-node generic configuration

       #region  2/6  Multi-node virtualization host configuration

            $Message = '  Step 2/6  Multi-node virtualization host configuration'
            Write-Verbose -Message $Message

            Switch
            (
                $ScaleUnitType
            ) 
            { 
                {
                    $psItem -in @(
                        'Management'
                        'Compute'
                        'Network'
                    )
                }
                {
                   #region Memory Dump

                        $Message = '    Configuring memory dump settings'
                        Write-Debug -Message $Message

                        $DumpConfigurationParam = @{

                            Session    = $psSession
                            ThumbPrint = $MemoryDumpEncryptionCertificateThumbPrint
                            PublicKey  = $MemoryDumpEncryptionCertificatePublicKey
                        }
                        Set-MemoryDumpConfiguration @DumpConfigurationParam

                   #endregion Memory Dump

                   #region Hypervisor Scheduler Type
            
                        $ImageInfo = Get-WindowsImageInfo -ComputerName $NodeAddress[0]

                        If
                        (
                            $ImageInfo.GetValue( 'ReleaseId' ) -lt 1809
                        )
                        {
                            $Message = '    Changing Hypervisor Scheduler type'
                            Write-Debug -Message $Message

                            $HypervisorSchedulerTypeParam = @{

                                Session    = $psSession
                                ModulePath = "$SoftwareRootPath\Scripts\psbcd"
                            }
                            Set-HypervisorSchedulerType @HypervisorSchedulerTypeParam
                        }

                   #endregion Hypervisor Scheduler Type

                 <# reboot to finish removing features. This is required to enable BitLocker and DCB
                  # NOTE: this will reboot all nodes at once

                  # $Message = 'Restarting nodes'
                  # Write-Verbose -Message $Message

                  # Restart-Computer -ComputerName $NodeCluster.Name -Wait

                  # [void]( $NodeCluster | Restart-scvmHost -Confirm:$False )

                  # $cimSession = New-cimSession -ComputerName $NodeCluster.Name -Verbose:$False
                  # $psSession  = New-psSession  -ComputerName $NodeCluster.Name  #>

                   #region Enable BitLocker

                        $Message = '    Configuring BitLockr'
                        Write-Debug -Message $Message

                        Enable-BitLockerEx -vmHost $Node

                   #endregion Enable BitLocker

                   #region Export the Platform Identifier for TPM-based attestation

                        $Path = Join-Path -Path . -ChildPath 'Platform Identifier'

                        If
                        (
                            -Not ( Test-Path -Path $Path )
                        )
                        {
                            [System.Void]( New-Item -Path $path -ItemType 'Directory' )
                        }

                        $Command = '
            
                            Get-PlatformIdentifier -Name $env:ComputerName
                        '

                        $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( $Command )

                        $CommandParam = @{

                            ScriptBlock  = $ScriptBlock
                            Session      = $psSession
                        }
                        $Command = Invoke-Command @CommandParam

                        $Command | ForEach-Object -Process {

                            $PathParam = @{
                                
                                Path      = $Path
                                ChildPath = "$( $psItem.psComputerName ).xml"
                            }
                            $PathCurrent = Join-Path @PathParam

                            If
                            (
                                -Not ( Test-Path -Path $PathCurrent )
                            )
                            {
                                $FileParam = @{

                                    FilePath    = $PathCurrent
                                    InputObject = $psItem.InnerXml
                                    Encoding    = 'utf8'
                                }
                                Out-File @FileParam
                            }
                        }

                   #endregion Export the Platform Identifier for TPM-based attestation
                }

                {
                    $psItem -in @(
                        'Storage'
                        'Virtual'
                    )
                }
                {
                    $Message = '      This is not a virtualization host, so no configuration'
                    Write-Debug -Message $Message
                } 
            }

       #endregion  2/5  Multi-node virtualization host configuration

       #region  3/6  Configure Hyper-V host in VMM

            $Message = '  Step 3/6  Per-machine virtualization host configuration in VMM'
            Write-Verbose -Message $Message

            $Node | ForEach-Object -Process {

                $NodeCurrent = $psItem
        
                Switch
                (
                    $ScaleUnitType
                ) 
                { 
                    {
                        $psItem -in @(
                            'Management'
                            'Compute'
                            'Network'
                        )
                    }
                    {
                       #region Host properties

                            $HostParam = @{

                                vmHost              = $NodeCurrent
                                Description         = $Description
                                NumaSpanningEnabled = $False
                                EnhancedSession     = $True  # New in System Center 1711
                            }

                            If
                            (
                                $ScaleUnitType -eq "Network"
                            )
                            {
                                $HostParam.Add(
                                    "IsDedicatedToNetworkVirtualizationGateway", $True
                                )
                            }
                    
                            If
                            (
                                [string]::IsNullOrWhiteSpace(
                                    $bmcAddress
                                )
                            )
                            {
                              # No BMC Settings     
                            }
                            Else
                            {
                                $HostParam.Add(
                                   "BMCProtocol", "IPMI" 
                            )
                                $HostParam.Add(
                                    "bmcAddress", $bmcAddress
                                )
                                $HostParam.Add(
                                    "BMCPort", "623"
                                )                    
                                $HostParam.Add(
                                    "BMCRunAsAccount", $RunAsAccountBmc
                                )                    
                            }

                            If
                            (
                                $Guarded
                            )
                            {
                             <# Legacy way to explicitly specify Code Integrity
                                Policy in Physical Computer Profile
                         
                                $CodeIntegrityPolicyName =
                                    $PhysicalComputerHardwareProfile.Manufacturer + " " +
                                    $PhysicalComputerHardwareProfile.Model

                                $CodeIntegrityPolicyParam = @{

                                    vmmServer = $vmmServer
                                    Name      = $CodeIntegrityPolicyName
                                }
                                $CodeIntegrityPolicy = Get-scCodeIntegrityPolicy @CodeIntegrityPolicyParam  #>
                    
                                $CodeIntegrityPolicy = Get-scCodeIntegrityPolicyEx -vmHost $NodeCurrent

                                If
                                (
                                    $CodeIntegrityPolicy -and
                                    $NodeCurrent.CodeIntegrityPolicy -ne $CodeIntegrityPolicy
                                )
                                {
                                    $Message = "Code Integrity Policy ""$( $CodeIntegrityPolicy.Name )"" found, applying."
                                    Write-Verbose -Message $Message
                        
                                    $scvmHostParam = @{
        
                                        vmHost  = $NodeCurrent
                                      # Confirm = $False
                                      # Force   = $True
                                    }
                                    $NodeCurrent = Disable-scvmHost @scvmHostParam

                                    $HostParam.Add(
                                        "ApplyLatestCodeIntegrityPolicy", $True
                                    )

                                    $HostParam.Add(
                                        "CodeIntegrityPolicy", $CodeIntegrityPolicy
                                    )
                                }

                                $HostParam.Add(

                                    'AttestationServerUrl',
                                    [System.Uri]::new( $HgsUriPrimary.ToString()  + 'Attestation'   )
                                )

                                $HostParam.Add(

                                    'KeyProtectionServerUrl',
                                    [System.Uri]::new( $HgsUriPrimary.ToString()  + 'KeyProtection' )
                                )

                                $HostParam.Add(

                                    'FallbackAttestationServerUrl',
                                    [System.Uri]::new( $HgsUriFallback.ToString() + 'Attestation'   )
                                )

                                $HostParam.Add(

                                    'FallbackKeyProtectionServerUrl',
                                    [System.Uri]::new( $HgsUriFallback.ToString() + 'KeyProtection' )
                                )
                            }

                            $NodeCurrent = Set-scvmHost @HostParam

                            If
                            (
                                $NodeCurrent.MaintenanceHost
                            )
                            {
                                $NodeCurrent = Enable-scvmHost @scvmHostParam
                            }

                       #endregion Host properties

                       #region Refresher Mode

                            If
                            (
                                $NodeCurrent.GetRefresherMode() -eq "Legacy"
                            )
                            {
                                $NodeCurrent.ResetRefresherMode()
                            }

                       #endregion Refresher Mode

                       #region Virtual SAN

                            $vmHostFibreChannelHba = Get-scvmHostFibreChannelHba -All |
                                Where-Object -FilterScript {
                                    $psItem.vmHost                     -eq $NodeCurrent -and
                                    $psItem.FabricClassification       -eq $null        -and
                                    $psItem.HostFibreChannelVirtualSAN -eq $null
                                }

                            If
                            (
                                $vmHostFibreChannelHba
                            )
                            {
                                $vmHostFibreChannelVirtualSanParam = @{

                                    Name                = "Fabric"
                                  # Description         = "Default Virtual SAN"
                                    HostFibreChannelHba = $vmHostFibreChannelHba
                                }

                                Set-DCAADescription -Define $vmHostFibreChannelVirtualSanParam

                                $vmHostFibreChannelVirtualSAN =
                                    New-scvmHostFibreChannelVirtualSAN @vmHostFibreChannelVirtualSanParam
                            }

                       #endregion Virtual SAN

                       #region Mark local volumes unavailable for Placement

                            $StorageVolume = [Microsoft.SystemCenter.VirtualMachineManager.StorageVolume[]]@()
                            $StorageVolume = Get-scStorageVolume -vmHost $NodeCurrent

                            $StorageVolumeNonCsv = $StorageVolume |
                                Where-Object -FilterScript {
                                    $psItem.IsClusterSharedVolume -eq $False
                                }

                            $StorageVolumeNonCsv | ForEach-Object -Process {

                                $StorageVolumeCurrent = $psItem

                                $SetSCStorageVolumeParam = @{

                                    StorageVolume         = $StorageVolumeCurrent
                                    AvailableForPlacement = $False

                                }
                                $StorageVolume = Set-scStorageVolume @SetSCStorageVolumeParam
                            }

                       #endregion Mark local volumes unavailable for Placement
                    }

                    {
                        $psItem -in @(
                            'Storage'
                            'Virtual'
                        )
                    }
                    {
                        $Message = '      This is not a virtualization host, so no configuration with VMM'
                        Write-Debug -Message $Message
                    } 
                }
            }

       #endregion 3/5  Configure Hyper-V host in VMM

       #region  4/6  Configure Hyper-V host using Hyper-V native tools

            $Message = '  Step 4/6  Per-machine virtualization host configuration using native Hyper-V'
            Write-Verbose -Message $Message

            $Node | ForEach-Object -Process {

                $NodeCurrent = $psItem
        
                Switch
                (
                    $ScaleUnitType
                ) 
                { 
                    {
                        $psItem -in @(
                            'Management'
                            'Compute'
                            'Network'
                        )
                    }
                    {
                       #region Host configuration

                            $cimSessionCurrent = $cimSession | Where-Object -FilterScript {
                                $psItem.ComputerName -eq $NodeCurrent.Name
                            }

                            $SetvmHostParam = @{

                                CimSession                = $cimSessionCurrent
                              # EnableEnhancedSessionMode = $True
                                Passthru                  = $True
                            }

                          # Calculate the default VM Placement path. This will only 
                          # apply to Native Hyper-V settings and not when deploying
                          # with VMM.

                            $vmPath = $NodeCurrent.vmPaths | Where-Object -FilterScript {
                                $psItem -notlike "\\?\Volume{*"
                            } | Sort-Object | Select-Object -First 1

                            If
                            (
                                $vmPath
                            )
                            {

                             <# Unlike previous versions, Windows Server 2019 
                                won't allow setting the default virtual hard
                                disk path to the root of the drive (cluster
                                shared volume.) So we have to create a child
                                folder for that. Under normal circumstances, 
                                this folder won't ever be used. However it's
                                there to accomondate for unexpected VM creation
                                which uses the default path  #>

                                $psSessionCurrent  = $psSession | Where-Object -FilterScript {
                                    $psItem.ComputerName -eq $NodeCurrent.Name
                                }

                                $Command = '

                                    @(
                                        "Default"
                                        "Config Store Root"
                                        "Replica"

                                    ) | Foreach-Object -Process {            

                                        $Path = Join-Path -Path $using:vmPath -ChildPath $psItem

                                        If
                                        (
                                            Test-Path -Path $Path
                                        )
                                        {
                                            $Message = "Path already exists, skipping"
                                            Write-Debug -Message $Message
                                        }
                                        Else
                                        {
                                            $ItemParam = @{
                                    
                                                Path     = $Path
                                                ItemType = "Directory"
                                            }
                                            [System.Void]( New-Item @ItemParam )
                                        }
                                    }
                                '

                                $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( $Command )

                                $InvokeCommandParam = @{

                                    ScriptBlock  = $ScriptBlock
                                    Session      = $psSessionCurrent
                                }
                                $Command = Invoke-Command @InvokeCommandParam

                                $vmPath = Join-Path -Path $vmPath -ChildPath 'Default'

                                $SetvmHostParam.Add( 'VirtualHardDiskPath', $vmPath )
                                $SetvmHostParam.Add( 'VirtualMachinePath',  $vmPath )
                            }

                       #endregion Host configuration

                       #region MAC address pool

                          # Reset Hyper-V Local MAC Address Pool to defaults.
                          # This is helpful in case host got some temporary IP address 
                          # from DHCP during OSD, and multiple hosts got the same IP
                          # over time, so they have overlapping MAC address pools now. 

                            $GetscvmHostNetworkAdapterParam = @{

                                vmHost = $NodeCurrent
                            }
                            $vmHostNetworkAdapterAll =
                                Get-scvmHostNetworkAdapter @GetscvmHostNetworkAdapterParam
                
                            $vmHostNetworkAdapterManagement = $vmHostNetworkAdapterAll |
                                Where-Object -FilterScript {
                                    $psItem.UsedForManagement -eq $True -and
                                    $psItem.IPAddresses       -ne $null
                                }

                            If
                            (
                                $vmHostNetworkAdapterManagement
                            )
                            {
                                $vmHostIpAddress = $vmHostNetworkAdapterManagement.IPAddresses |
                                    Where-Object -FilterScript { $psItem.AddressFamily -eq "InterNetwork" }

                                $3rdOctetDec = $vmHostIpAddress.IPAddressToString.Split( "." )[2]
                                $4thOctetDec = $vmHostIpAddress.IPAddressToString.Split( "." )[3]
                                $3rdOctetHex = [Convert]::ToString( $3rdOctetDec, 16 )
                                $4thOctetHex = [Convert]::ToString( $4thOctetDec, 16 )

                                If ( $3rdOctetHex.Length -eq 1 ) { $3rdOctetHex = "0" + $3rdOctetHex }
                                If ( $4thOctetHex.Length -eq 1 ) { $4thOctetHex = "0" + $4thOctetHex }

                                $macAddressMinimum = "00155D" + $3rdOctetHex + $4thOctetHex + "00"
                                $macAddressMaximum = "00155D" + $3rdOctetHex + $4thOctetHex + "FF"

                                $SetvmHostParam.Add( "macAddressMinimum",  $macAddressMinimum )
                                $SetvmHostParam.Add( "macAddressMaximum",  $macAddressMaximum )
                            }

                       #endregion MAC address pool

                       #region Apply configuration

                            If
                            (
                                $SetvmHostParam.Count -gt 2
                            )
                            {
                                $vmHost = Hyper-V\Set-vmHost @SetvmHostParam
                            }

                       #endregion Apply configuration
                    }

                    {
                        $psItem -in @(
                            'Storage'
                            'Virtual'
                        )
                    }
                    {
                        $Message = '      This is not a virtualization host, so no configuration with Hyper-V'
                        Write-Debug -Message $Message
                    }
                }
            }

       #endregion  4/5  Configure Hyper-V host using Hyper-V native tools

       #region  5/6  Configure physical server in VMM

            $Message = '  Step 5/6  Per-machine virtualization host physical server metadata in VMM'
            Write-Verbose -Message $Message

            $Node | ForEach-Object -Process {

                $NodeCurrent = $psItem
        
                Switch
                (
                    $ScaleUnitType
                ) 
                { 
                    {
                        $psItem -in @(
                            'Management'
                            'Compute'
                            'Network'
                        )
                    }
                    {
                       #region Initialize

                            $Message = "  Setting metadata on VM Host `“$( $NodeCurrent.Name )`”"
                            Write-Debug -Message $Message

                            $cimSessionCurrent = $cimSession | Where-Object -FilterScript {
                                $psItem.ComputerName -eq $NodeCurrent.Name
                            }

                            $psSessionCurrent  = $psSession  | Where-Object -FilterScript {
                                $psItem.ComputerName -eq $NodeCurrent.Name
                            }

                            $Property = @{}

                       #endregion Initialize

                       #region Physical server property

                            $HostGroupRoom       = $NodeCurrent.vmHostGroup
                            $HostGroupDatacenter = $HostGroupRoom.ParentHostGroup

                          # Obtain “Serial Number” from WMI

                            $CimInstanceParam = @{

                                ClassName    = 'win32_Bios'
                                cimSession   = $cimSessionCurrent
                                Verbose      = $False
                            }
                            $Bios = Get-CimInstance @CimInstanceParam

                            $Property.Add( 'Serial Number', $Bios.SerialNumber )

                          # Obtain “Manufacturer” from WMI

                            $CimInstanceParam.ClassName = 'win32_ComputerSystem'

                            $ComputerSystem = Get-CimInstance @CimInstanceParam

                            $Property.Add( 'Manufacturer', $ComputerSystem.Manufacturer )
    
                          # Different manufactureres leverage different naming schemas to store
                          # “Model” and “Product” codes in WMI

                            Switch
                            (
                                $ComputerSystem.Manufacturer
                            )
                            {
                                'HP'
                                {
                                    $Property.Add( 'Model',   $ComputerSystem.Model )
                                    $Property.Add( 'Product', $ComputerSystem.SystemSKUNumber )

                                  # We can obtain some additional properties from HP OneView

                                    $Server = Get-hpovServer @hpovParam | Where-Object -FilterScript {
                                        $psItem.serialNumber -eq $Bios.SerialNumber
                                    }

                                    $Location = $RackMember | Where-Object -FilterScript {
                                        $psItem.Uri -eq $Server.uri
                                    }

                                    $Property.Add( 'Rack',      $Location.RackName )
                                    $Property.Add( 'Rack Slot', $Location.ULocation )
                                }

                                'Lenovo'
                                {
                                    $Property.Add( 'Model',   $ComputerSystem.Model.Split( ':' )[0] )
                                    $Property.Add( 'Product', $ComputerSystem.Model.Split( ':' )[1].TrimStart( ' -[' ).TrimEnd( ']-' ) )
                                }
                            }

                       #endregion Physical server property

                       #region BitLocker recovery password

                            $Command = '
            
                                ( Get-BitLockerVolume -MountPoint "c:" ).KeyProtector | Where-Object -FilterScript {
                                    $psItem.KeyProtectorType -eq "RecoveryPassword"
                                }
                            '

                            $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( $Command )

                            $InvokeCommandParam = @{

                                ScriptBlock  = $ScriptBlock
                                Session      = $psSessionCurrent
                            }
                            $Command = Invoke-Command @InvokeCommandParam

                            $Property.Add( 'Recovery Password', $Command.RecoveryPassword )

                       #endregion BitLocker recovery password

                       #region Store the properties in the server object

                            $Property.GetEnumerator() | ForEach-Object -Process {

                                $CustomPropertyParam = @{
        
                                    Name      = $psItem.Key
                                    vmmServer = $NodeCurrent.ServerConnection
                                }
                                $CustomProperty = Get-scCustomProperty @CustomPropertyParam

                                $CustomPropertyValueParam = @{
            
                                    CustomProperty = $CustomProperty
                                    Value          = $psItem.Value
                                    InputObject    = $NodeCurrent
                                }
                                [System.Void]( Set-scCustomPropertyValue @CustomPropertyValueParam )
                            }

                       #endregion Store the properties in the server object

                       #region Configure DPM Agent
                           
                         <# $Command = '
            
                                $FilePath = Join-Path -Path $env:ProgramFiles -ChildPath ''Microsoft Data Protection Manager\DPM\bin\SetDpmServer.exe''

                                $Argument = ''-dpmServerName $Using:DpmServerAddress''

                                Start-Process -Wait -FilePath $FilePath -ArgumentList $Argument
                            '

                            $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( $Command )

                            $InvokeCommandParam = @{

                                ScriptBlock  = $ScriptBlock
                                Session      = $psSessionCurrent
                            }
                          # $Command = Invoke-Command @InvokeCommandParam  #>

                       #endregion Configure DPM Agent
                    }

                    {
                        $psItem -in @(
                            'Storage'
                            'Virtual'
                        )
                    }
                    {
                        $Message = '      This is not a virtualization host, so no physical server configuration'
                        Write-Debug -Message $Message
                    }
                }
            }

       #endregion  5/6  Configure physical server in VMM

       #region  6/6  Configure Agent in OpsMgr

            $Message = '  Step 6/6  Configure Agent in OpsMgr'
            Write-Verbose -Message $Message

            If
            (
                $OpsMgrConnection
            )
            {
                $AgentParam = @{

                    dnsHostName = $NodeAddress
                    scSession   = $OpsMgrConnection
                }        
                $Agent = Get-scomAgent @AgentParam

             <# While
                (
                    @( $Agent ).Count -lt @( $AddressProxy ).Count
                )
                {
                    $Message = 'Some agents did not register yet, waiting'
                    Write-Verbose -Message $Message
                    Start-Sleep -Seconds 10
                    $Agent = Get-scomAgent @AgentParam
                }  #>
        
                Enable-scomAgentProxy -Agent $Agent
            }
            Else
            {
                $Message = '    No OpsMgr management group connection was specified, skipping configuration'
                Write-Debug -Message $Message
            }

       #endregion  6/6  Configure Agent in OpsMgr
    }

    End
    {
            Switch
            (
                $System.Manufacturer
            )
            {
                'HP'
                {
                     [System.Void]( Disconnect-hpovMgmt @hpovParam )
                }
            }

      # Remove-cimSession -cimSession $cimSession
        Remove-psSession  -Session    $psSession

        $Message = '  Exiting  Set-ClusterNodeEx'
        Write-Verbose -Message $Message
    }
}