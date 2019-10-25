<#
    initialize disks on cluster
#>

Set-StrictMode -Version 'Latest'

Function
Get-clusterDiskEx
{
    [cmdletBinding(
        DefaultParameterSetName = "Witness"
    )]

    Param(

           #region Naming

                [Parameter(
                    Mandatory        = $True,
                    ParameterSetName = "Role Disk"
                )]
                [Parameter(
                    Mandatory        = $True,
                    ParameterSetName = "Shared Volume"
                )]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $Name
            ,
                [Parameter(
                    Mandatory        = $True,
                    ParameterSetName = "Role Disk"
                )]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $RoleName
            ,
                [Parameter(
                    Mandatory        = $False
                )]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $ClusterAddress
            ,
           #endregion Naming

           #region Placing

                [Parameter(
                    Mandatory = $True
                )]
                [ValidateNotNullOrEmpty()]
              # [Microsoft.FailoverClusters.PowerShell.ClusterNode[]]
                $Node
            ,
                [Parameter(
                    Mandatory = $False
                )]
                [System.String]
                $NodeSetName
            ,
                [Parameter(
                    Mandatory = $False
                )]
                [System.String]
                $SiteName
            ,
                [Parameter(
                    Mandatory        = $False
                )]
                [ValidateRange(512MB, 64TB)]
                [System.UInt64]
                $Size
            ,
           #endregion Placing

           #region VHD

             <# [Parameter(
                    Mandatory        = $False
                )]
                [System.String[]]
                $HostName
            ,  #>
                [Parameter(
                    Mandatory        = $False
                )]
                [ValidateNotNullOrEmpty()]
                [String]
                $HostVhdPath
            ,
                [Parameter(
                    Mandatory = $False
                )]
                [ValidateNotNullOrEmpty()]
                [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
                $vmmServer
            ,

           #endregion VHD
            
           #region SAN

                [Parameter(
                    Mandatory        = $False
                )]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $iSCSITargetPortalAddress
            ,
                [Parameter(
                    Mandatory        = $False
                )]            
                [System.String]
                $StoragePoolName

           #endregion SAN
    )

    Begin
    {
        $Message = '  Entering Get-ClusterDiskEx'
        Write-Debug -Message $Message

        [System.Void]( Import-ModuleEx -Name @( 'Storage', 'iSCSI' ) )
    }

    Process
    {
       #region Node Name

            Switch
            (
                $Node[0].GetType().FullName
            )
            {
                'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                {
                    Write-Verbose -Message "Running in ClusterNode mode"
                    
                    $DomainAddress  = $env:UserDnsDomain.ToLower()

                    $Cluster        = $Node[0].Cluster
                    $ClusterName    = $Cluster.Name
                    $ClusterAddress = Resolve-DnsNameEx -Name $ClusterName
                    $NodeName       = $Node.Name | Sort-Object

                    $NodeAddress    = [System.Collections.Generic.List[System.String]]::new()                    

                    $NodeName | ForEach-Object -Process {
        
                        $NodeNameCurrent = $psItem

                        $NodeAddressCurrent = Resolve-dnsNameEx -Name $NodeNameCurrent

                        $NodeAddress.Add( $NodeAddressCurrent )
                    }
                }

                'System.String'
                {
                    $Message = 'Running in Untrusted Virtual Cluster mode. Will only provision virtual disks without initializing them'
                    Write-Verbose -Message $Message

                  # $Message = "Number of Nodes: $( @( $Node ).Count )"
                  # Write-Verbose -Message $Message

                    $ClusterName    = $ClusterAddress.Split(".")[0]
                    $DomainAddress  = $ClusterAddress.Replace( "$ClusterName.", [System.String]::Empty )
                    $NodeName       = $Node
                    $NodeAddress    = $Node

                  # $NodeProvision.AddRange( [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]$Node )
                }

                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                {
                    Write-Verbose -Message "Running in VM Host mode"
                    
                    $DomainAddress  = $env:UserDnsDomain.ToLower()

                    $Cluster        = $Node[0].HostCluster
                    $ClusterAddress = $Cluster.Name
                    $ClusterName    = $ClusterAddress.Split(".")[0]
                    $NodeAddress    = $Node.Name | Sort-Object
                    $vmmServer      = $Node[0].ServerConnection
                }

                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                {
                    Write-Verbose -Message "Running in StorageFileServerNode mode"
                    
                    $DomainAddress  = $env:UserDnsDomain.ToLower()

                    $Cluster        = $Node[0].StorageArray
                    $ClusterAddress = $Cluster.Name
                    $ClusterName    = $ClusterAddress.Split(".")[0]
                    $NodeAddress    = $Node.Name | Sort-Object

                    $NodeInitiatorName = [System.String[]]@()
                    $NodeAddress | ForEach-Object -Process {

                        $NodeAddressCurrent = $psItem
                        $NodeInitiatorNameCurrent =
                            "iqn.1991-05.com.microsoft:" + $NodeAddressCurrent
                        $NodeInitiatorName += $NodeInitiatorNameCurrent
                    }

                    $vmmServer = $Node[0].ServerConnection
                }

                Default
                {
                    $Message = "Unexpected Node type: `“$( $psItem )`”"
                    Write-Warning -Message $Message
                }
            }

            If
            (
                $Node[0].GetType().FullName -in @(

                    'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                    'System.String'
                )
            )
            {
                $NodeProvision  = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

                $vmmServer = Get-scvmmServerEx -vmmServer $vmmServer

                $NodeAddress | ForEach-Object -Process {

                    $VirtualMachineParam = @{

                        Name      = $psItem
                        vmmServer = $vmmServer
                    }
                    $NodeProvisionCurrent = Get-scVirtualMachine @VirtualMachineParam

                    If
                    (
                        $NodeProvisionCurrent
                    )
                    {
                        $NodeProvision.Add( $NodeProvisionCurrent )
                    }
                }

             <# $Message = "Found @( $NodeProvision.Count ) virtual machine(s)"
                Write-Debug -Message $Message
                
                $NodeProvision | ForEach-Object -Process {

                    $Message = "  * $( $psItem.Name )"
                    Write-Debug -Message $Message

                    $Message = "    $( $psItem.vmHost.vmHostGroup.Name )"
                    Write-Debug -Message $Message
                }  #>

             <# If
                (
                    Test-Path -Path 'Variable:\HostGroup'
                )
                {
                    Remove-Variable -Name 'HostGroup'
                }  #>

                If
                (
                    $NodeProvision
                )
                {
                    If
                    (
                        $NodeSetName
                    )
                    {
                        $HostGroup = Get-scvmHostGroup -Name $NodeSetName

                        $Message = "Host Group was explicitly specified as `“Node Set`” name and resolved to `“$($HostGroup.Path)`”"
                    }
                    ElseIf
                    (
                        $NodeProvision | Where-Object -FilterScript { $psItem.HasSharedStorage }
                    )
                    {
                        $HostGroup = ( $NodeProvision | Where-Object -FilterScript { $psItem.HasSharedStorage } )[0].vmHost.vmHostGroup

                        $Message = "Existing VMs for the same `“cluster node set`” found with Shared Storage in Host Group `“$($HostGroup.Path)`”"
                    }
                    Else
                    {
                        $Message = 'Node Set Name not specified, skipping Host Group check'                    
                    }

                    Write-Debug -Message $Message

                    If
                    (
                        Test-Path -Path 'Variable:\HostGroup'
                    )
                    {
                      # $Message = "Checking Host Group $( $HostGroup.Name )"
                      # Write-Debug -Message $Message

                        If
                        (
                            $HostGroup -eq ( $NodeProvision.vmHost.vmHostGroup | Sort-Object -Unique )
                        )
                        {
                            $Message = 'All VMs are already on target Host Group (matching Node Set name)'
                            Write-Debug -Message $Message
                        }
                        Else
                        {
                            $NodeProvision | Where-Object -FilterScript {

                                $psItem.vmHost.vmHostGroup -ne $HostGroup

                            } | ForEach-Object -Process {

                                $Message = "Moving virtual machine `“$( $psItem.Name )`”"
                                Write-Verbose -Message $Message                            

                                $HostRatingParam = @{

                                    VM                      = $psItem
                                    HighlyAvailable         = $psItem.IsHighlyAvailable
                                    vmHostGroup             = $HostGroup
                                    PlacementGoal           = 'LoadBalance'
                                    ReturnFirstSuitableHost = $True
                                    UseDefaultPath          = $True
                                }
                                $HostRating = Get-scvmHostRating @HostRatingParam

                                $VirtualMachineParam = @{

                                    VM     = $psItem
                                    vmHost = $HostRating.vmHost
                                    Path   = $HostRating.PreferredStorage.MountPoints[0]
                                }
                                [System.Void]( Move-scVirtualMachine @VirtualMachineParam )
                            }
                        }
                    }
                
             <# If
                (
                    [System.String]::IsNullOrWhiteSpace( $HostName )
                )
                {
                    $HostName = $NodeProvision.HostName

                  # Write-Verbose -Message $HostName.GetType().FullName

                  # $HostName | ForEach-Object -Process { Write-Verbose -Message $psItem }
                }  #>

                    If
                    (
                        [System.String]::IsNullOrWhiteSpace( $HostVhdPath )
                    )
                    {
                        $HostVhdPath = $NodeProvision.vmHost.vmPaths | Sort-Object | Select-Object -First 1
                    }
                }
                Else
                {
                    $Message = '    There are no Virtual Machine(s) provisioned, skipping VM relocation'
                    Write-Debug -Message $Message
                }
            }

            Write-Verbose -Message "Disk Type: $($psCmdlet.ParameterSetName)"
            
            Write-Debug -Message '  Node Address:'
            
            $NodeAddress | ForEach-Object -Process {
                
                $Message = "    * $psItem"
                Write-Debug -Message $Message
            }

       #endregion Node Name

       #region Disk Name

            If
            (
                ( $psCmdlet.ParameterSetName -eq "Shared Volume" ) -or
                ( $psCmdlet.ParameterSetName -eq "Witness" )
            )
            {
                $RoleName = $ClusterName
            }

            $RoleAddress = $RoleName + "." + $DomainAddress

            If
            (
                $psCmdlet.ParameterSetName -eq "Witness"
            )
            {
                $Name = "Witness"
            }

            $DiskName    = [string]::Empty
            $VolumeLabel = [string]::Empty

            If
            (
                $SiteName
            )
            {
                $DiskName    += $SiteName + ' — '
                $VolumeLabel += $SiteName + ' — '
            }

            If
            (
                $NodeSetName
            )
            {
                $DiskName    += $NodeSetName + ' — '
              # $VolumeLabel += $NodeSetName + ' — '
            }

            $DiskName    += $RoleAddress + ' — ' + $Name
            $VolumeLabel += $RoleName    + ' — ' + $Name

            If
            (
                $VolumeLabel.Length -gt 32
            )
            {
                $VolumeLabel = $VolumeLabel.Substring( 0, 32 )
            }

            Write-Verbose -Message ( "Disk Name:    " + $DiskName )
            Write-Verbose -Message ( "Volume Label: " + $VolumeLabel )

       #endregion Object Names

       #region Check whether the disk already exists

            $ClusterDisk = @()
            $Disk        = $Null
            
            Switch
            (
                $Node[0].GetType().FullName
            )
            {
                {
                    $psItem -in @(

                      # These scenarios support automatic connection of disk
                      # when new nodes are added

                        'System.String'
                        'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                    )
                }
                {
                    $NodeProvision = $NodeProvision | Where-Object -FilterScript {

                        -Not ( Get-scVirtualHardDisk -VM $psItem | Where-Object -FilterScript {
                            $psItem.Name -eq $DiskName
                        } )
                    }
                }
                
             <# 'System.String'
                {
                    $ClusterDisk = Get-scVirtualHardDisk -VM $Node[0] | Where-Object -FilterScript { $psItem.Name -eq $DiskName }
                }  #>

                {
                 <# (
                        $psItem -eq 'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                    ) -or  #>

                    $psItem -in @(

                      # 'System.String'
                        'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                        'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                    )
                }
                {
                    $GetClusterDiskParam = @{

                        Cluster = $ClusterAddress
                    }

                    $ClusterDisk += Get-ClusterSharedVolume @GetClusterDiskParam
                    $ClusterDisk += Get-ClusterResource     @GetClusterDiskParam
                }

                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                {                
                    $StorageDisk        = Get-scStorageDisk -vmHost $Node[0]
                    
                    $StorageDiskCluster = $StorageDisk |
                        Where-Object -FilterScript {
                    
                            $psItem.IsClustered -eq $True
                        }
                    
                    If
                    (
                        $StorageDiskCluster
                    )
                    {
                        $ClusterDisk  = $StorageDiskCluster.ClusterDisk
                    }
                    Else
                    {

                      # There are no cluster disks on this cluster.
                    
                    }
                }

                Default
                {
                    $Message = "Unexpected Node type: `“$( $psItem )`”"
                    Write-Warning -Message $Message
                }
            }

            If
            (
                $ClusterDisk
            )
            {
                $Disk = $ClusterDisk | Where-Object -FilterScript {

                    $psItem.Name -eq $DiskName
                }
            }

            If
            (
                $Disk -and
                -not $NodeProvision
            )
            {
                $Message = 'Disk already exists. Skipping'
                Write-Verbose -Message $Message

                $Message = '  Exiting  Get-ClusterDiskEx'
                Write-Debug -Message $Message

                Return $Disk
            }
            Else
            {
                $Message = '  Disk does not exist yet, or might need reconnecting processing'
                Write-Debug -Message $Message
            }

       #endregion Check whether the disk already exists

       #region Select Cluster Node

            Switch
            (
                $Node[0].GetType().FullName
            )
            {
                {
                    (
                        $psItem -eq 'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                    ) -or
                    (
                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                    ) -or
                    (
                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.Host'
                    )
                }
                {
                  # Select the first node to participate in disks operations.
        
                    $NodeAddressCurrent = $NodeAddress |
                        Sort-Object | Select-Object -First 1

                    $cimSession = New-cimSessionEx -Name $NodeAddressCurrent

                  # Move Available Storage group to selected cluster node.

                    $GetClusterGroupParam = @{

                        Cluster     = $ClusterAddress
                        Name        = "Available Storage"
                    }        
                    $ClusterGroup = Get-ClusterGroup @GetClusterGroupParam

                    $MoveClusterGroupParam = @{

                        InputObject = $ClusterGroup
                        Node        = $NodeAddressCurrent
                    }
                    $ClusterGroup = Move-ClusterGroup @MoveClusterGroupParam
                }

                'System.String'
                {
                    $Message = 'No need to select the node because the disk won''t be initialized'
                    Write-Verbose -Message $Message
                }

                Default
                {
                    $Message = "Unexpected Node type: `“$( $psItem )`”"
                    Write-Warning -Message $Message
                }
            }

       #endregion Select Cluster Node

       #region Provision and/or Connect Disk
        
            If
            (
                $NodeProvision -and
                $HostVhdPath
            )
            {
                Write-Verbose -Message 'Storage Type is VHD(x/s)'

              # Write-Verbose -Message $HostName.GetType().FullName

              # $HostName | ForEach-Object -Process { Write-Verbose -Message $psItem }

                $vhdSetParam = @{

                    Name      = $DiskName
                    Path      = $HostVhdPath
                    Size      = $Size
                  # HostName  = $HostName
                    vm        = Get-vmFromVirtualMachine -VirtualMachine $NodeProvision
                }
                $vhd = New-vhdSet @vhdSetParam
                
                $NodeProvision | ForEach-Object -Process {
                    [System.Void]( Read-scVirtualMachine -VM $psItem )
                }
            }

            ElseIf
            (
                $iSCSITargetPortalAddress
            )

          # Try to obtain the relevant iSCSI Session by Disk Name.
          # This typically works when there's one iSCSI Target by Disk.
          # It is common with 3rd party hardware iSCSI Targets.

            {
                Write-Verbose -Message "Storage Type is SAN — iSCSI"

                $GetIscsiSessionParam = @{

                    cimSession        = $cimSession
                    SessionIdentifier = "*"
                }            
                $IscsiSession = Get-IscsiSession @GetIscsiSessionParam

                $IscsiSessionCurrent = $IscsiSession | Where-Object -FilterScript {
                    $psItem.TargetNodeAddress -like "*$Name*"
                }

                If
                (
                    $IscsiSessionCurrent
                )
                {

                  # There's an iSCSI Session already, nothing to do.

                }

                Else
                {

                  # There's no iSCSI Session yet, we need to establish one.

                    Switch
                    (
                        $Node[0].GetType().FullName
                    )
                    {
                        {
                            (
                                $psItem -eq 'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                            ) -or
                            (
                                $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                            ) -or
                            (
                                $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.Host'
                            )
                        }

                        {

                          # First, we need to present LUN to Initiator.
                          # This should be done on the Target side.

                            Switch
                            (
                                $Node[0].GetType().FullName
                            )
                            {

                                'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                                
                                {

                                  # We cannot manage iSCSI target without Vmm.
                                  # This should be done manually.

                                }

                                {
                                    (
                                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                    ) -or
                                    (
                                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                    )
                                }

                                {

                                  # The following currently assumes the LUN was created
                                  # already and exists in Vmm. To provision a new LUN
                                  # some additional work would be required.

                                    $RegisterScStorageLogicalUnitExParam = @{

                                        StorageLogicalUnitName = $DiskName
                                        StorageInitiatorName   = $NodeInitiatorName
                                        vmmServer              = $vmmServer
                                    }
                                    $StorageLogicalUnitEx =
                                        Register-scStorageLogicalUnitEx @RegisterScStorageLogicalUnitExParam
                                }
                            }

                          # Second, we need to connect the Initiator to the Target

                            $ConnectIscsiTargetExParam = @{

                                TargetPortalAddress = $iSCSITargetPortalAddress
                                ComputerName        = $NodeAddressCurrent
                            }                            
                            $IscsiSessionCurrent =
                                Connect-IscsiTargetEx @ConnectIscsiTargetExParam
                        }
                    }
                }
            }
            
            ElseIf
            (
                $StoragePoolName
            )
            {
                Write-Verbose -Message "Storage Type is SAN — FC"

                          # First, we need to present LUN to Initiator.
                          # This should be done on the Target side.

                            Switch
                            (
                                $Node[0].GetType().FullName
                            )
                            {

                                'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                                
                                {

                                  # We cannot manage SAN without Vmm.
                                  # This should be done manually.

                                }

                                {
                                    (
                                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                    ) -or
                                    (
                                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                    )
                                }

                                {

                                    $GetScStoragePoolParam = @{

                                        Name      = $StoragePoolName
                                        vmmServer = $vmmServer
                                    }
                                    $StoragePool = Get-scStoragePool @GetScStoragePoolParam
                                    
                                    $SizeMb = $Size / 1mb

                                    $StorageLogicalUnitName = $VolumeLabel.Replace( ' — ', "--" )

                                    $NewScStorageLogicalUnitParam = @{

                                         StoragePool      = $StoragePool
                                         DiskSizeMB       = $SizeMb
                                         Name             = $StorageLogicalUnitName
                                         Description      = $DiskName
                                         ProvisioningType = "Thin"
                                         vmmServer        = $vmmServer
                                    }

                                    Switch
                                    (
                                        $Node[0].GetType().FullName
                                    )
                                    {
                                        'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                        {

                                          # No additional parameters

                                        }

                                        'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                        {

                                            $HostGroup = $Node[0].vmHostGroup

                                            $NewScStorageLogicalUnitParam.Add(

                                                "vmHostGroup", $HostGroup
                                            )
                                        }
                                    }

                                    Write-Verbose -Message "Provisioning a new SAN LUN $StorageLogicalUnitName of size $SizeMb MB to $($HostGroup.Name)"

                                    $StorageLogicalUnit =
                                        New-scStorageLogicalUnit @NewScStorageLogicalUnitParam

                                    $RegisterScStorageLogicalUnitParam = @{

                                        StorageLogicalUnit = $StorageLogicalUnit
                                    }

                                    Switch
                                    (
                                        $Node[0].GetType().FullName
                                    )
                                    {
                                        'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                        {

                                          # No additional parameters

                                        }

                                        'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                        {
                                            $RegisterScStorageLogicalUnitParam.Add(

                                                "vmHostCluster", $Cluster
                                            )
                                        }
                                    }
                                    
                                    Write-Verbose -Message "Presenting the SAN LUN $StorageLogicalUnitName to $($Cluster.Name)"

                                    $StorageLogicalUnit =
                                        Register-scStorageLogicalUnit @RegisterScStorageLogicalUnitParam
                                }
                            }
            }

            Else
            {
                Write-Verbose -Message "Storage Type unknown or all disks are already connected. We're not provisioning any disk(s)"
            }

       #endregion Provision and/or Connect Disk

       #region Disk Selection options (obtain suitable disk(s))

            Switch
            (
                $Node[0].GetType().FullName
            )
            {
                {
                    (
                        $psItem -eq 'Microsoft.FailoverClusters.PowerShell.ClusterNode'
                    ) -or
                    (
                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                    ) -or
                    (
                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.Host'
                    )
                }
                {
                    Write-Verbose -Message "Looking for Disks"

                    $DiskAll      = [Microsoft.Management.Infrastructure.CimInstance[]]@()                    

                    If
                    (
                        Test-Path -Path "Variable:\IscsiSessionCurrent"
                    )

                  # We managed to fetch relevatn iSCSI Session,
                  # thus we can narrow the selection by this Session.

                    {
                        $IscsiSessionCurrent | ForEach-Object -Process {
                
                            $DiskAll += Get-Disk -iSCSISession $psItem
                        }
                        Write-Verbose -Message "Searching by Session"
                    }

                    Else

                  # Just get all disks from the node.

                    {
                        Update-HostStorageCache -cimSession $cimSession
                
                        $DiskAll = Get-Disk -cimSession $cimSession

                        $Message = '    Grabbing All Disk(s)'
                        Write-Debug -Message $Message
                    }

                    $Message = '    Disk Total Count: ' + @( $DiskAll ).Count
                    Write-Debug -Message $Message

                  # Filter only suitable disks. (Not initialized yet, offline, etc.).

                    $DiskSuitable = $DiskAll | Where-Object -FilterScript {

                        ( $psItem.PartitionStyle    -eq 'RAW'     ) -and
                        ( $psItem.OperationalStatus -eq 'Offline' ) -and
                        ( $psItem.HealthStatus      -eq 'Healthy' ) -and
                        ( $psItem.AllocatedSize     -eq  0        ) -and
                        ( $psItem.IsClustered       -eq $False    ) -and
                        (
                            (   $psItem.BusType -eq 'Fibre Channel' ) -or
                            (   $psItem.BusType -eq 'SAS'           ) -or
                            ( ( $psItem.BusType -eq 'iSCSI'  ) -and
                                (
                                    Get-IscsiSession -IscsiConnection (
                                        Get-IscsiConnection -Disk $psItem
                                    )[0]
                                ).TargetNodeAddress -notLike '*-vss-control'
                            )
                        )
                    }
                }

                'System.String'
                {
                    $Message = 'No need to select the disk because it won''t be initialized'
                    Write-Verbose -Message $Message

                    $DiskSuitable = [Microsoft.Management.Infrastructure.CimInstance[]]@()
                }

                Default
                {
                    $Message = "Unexpected Node type: `“$( $psItem )`”"
                    Write-Warning -Message $Message
                }
            }

       #endregionregion Disk Selection options (obtain suitable disk(s))

       #region Process Disk(s)

            If
            (
                $DiskSuitable
            )
            {
                $Message = '    Disk Suitable Count: ' + @( $DiskSuitable ).Count
                Write-Debug -Message $Message

               #region Select disk

                  # Sort disks

                    If
                    (
                        $psCmdlet.ParameterSetName -eq 'Witness'
                    )

                  # It was not VHD, and for Witness we need the smallest disk.

                    {
                        $DiskSorted = $DiskSuitable |
                            Sort-Object -Property 'Size'
                    }

                    ElseIf
                    (
                        $Size
                    )

                  # We created a VHD, so it is the latest added disk.
                  # (Disks are numbered in order of adding, and we just added the VHD).

                    {
                        $DiskSorted = $DiskSuitable |
                            Sort-Object -Property "Number" -Descending
                    }

                    ElseIf
                    (
                        $psCmdlet.ParameterSetName -eq "Shared Volume"
                    )

                  # It was not VHD, and for Shared Volume we need the largest disk.

                    {
                        $DiskSorted = $DiskSuitable |
                            Sort-Object -Property "Size" -Descending
                    }
                    ElseIf
                    (
                        $psCmdlet.ParameterSetName -eq "Role Disk"
                    )

                  # It was not VHD, and will be used as a regular Cluster disk
                  # scoped to one Cluster Role. The best option would be to select
                  # the earliest added disk.

                    {
                        $DiskSorted = $DiskSuitable |
                            Sort-Object -Property "Number"
                    }
            
                    Write-Verbose -Message ( "Disk Sorted: " + @( $DiskSorted ).Count )

                  # Select one disk from the sorted.

                    $Disk = $DiskSorted | Select-Object -First 1

                    Write-Verbose -Message ( "Disk: " + $Disk.FriendlyName )

                    $DiskInitialzied = $Null
                    $ClusterDisk     = $Null
            
               #endregion Select Disk

               #region Initialize disk (includes partitioning and formatting)

                  # Initialize disk with specified parameters

                    If
                    (
                        $Disk
                    )
                    {
                
                        Write-Verbose -Message ( "Disk Number: " + $Disk.Number )
                      # $Disk | ForEach-Object -Process { $psItem | Write-Verbose }

                      # Write-Verbose -Message ( ( $Disk | Get-Member ).TypeName | Sort-Object -Unique )
                      # Write-Verbose -Message ( "Count: " + @( $Disk ).Count )

                        $InitializeDiskExParam = @{
            
                            Disk              = $Disk
                            VolumeLabel       = $VolumeLabel
                            AssignDriveLetter = ( $psCmdlet.ParameterSetName -eq "Role Disk" )
                        }
                        $Volume = Initialize-DiskEx @InitializeDiskExParam

                        Write-Verbose -Message "Initialized!"
                    
                      # Obtain the Disk object again
                      # (because it was not updated automatically once initialized).

                        $GetDiskParam = @{
        
                            cimSession = $NodeAddressCurrent
                            Number     = $Disk.Number
                        }
                        $DiskInitialzied = Get-Disk @GetDiskParam

                    }

               #endregion Initialize disk
        
               #region Add Disk to Cluster

                    If
                    (
                        $DiskInitialzied
                    )
                    {

                        Write-Verbose -Message "Adding disk $($DiskInitialzied.FriendlyName) Number $($DiskInitialzied.Number) to cluster"

                        $AddClusterDiskParam = @{

                            InputObject = $DiskInitialzied
                            Cluster     = $ClusterAddress
                        }
                        $ClusterDisk = Add-ClusterDisk @AddClusterDiskParam

                        Write-Verbose -Message ( "Disk Added to Cluster Group: " + $ClusterDisk.OwnerGroup.Name )

                      # Rename the Cluster disk object

                        $ClusterDisk.Name = $DiskName

                        Write-Verbose -Message ( "Disk Renamed to " + $ClusterDisk.Name )

                      # Start-Sleep -Seconds 30

                    }
          
               #endregion Add Disk to Cluster

               #region Set as Witness

                    If
                    (
                        ( $psCmdlet.ParameterSetName -eq "Witness" ) -and
                        ( $ClusterDisk )
                    )
                    {

                      # Normally we would use “-InputObject = $Cluster” here.
                      # However, here $Cluster may have different types of value,
                      # depending on the Node Type and thus script execution mode.

                        $SetClusterQuorumParam = @{
                
                            Cluster     = $ClusterAddress
                            DiskWitness = $ClusterDisk.Name
                        }
                        $ClusterQuorum = Set-ClusterQuorum @SetClusterQuorumParam
                    }

               #endregion Set as Witness

               #region Add as Cluster Shared Volume

                    If
                    (
                        ( $psCmdlet.ParameterSetName -eq "Shared Volume" ) -and
                        ( $ClusterDisk )
                    )
                    {
                        Write-Verbose -Message ( "Disk Group: " + $ClusterDisk.OwnerGroup.Name )

                      # We should replace this with Vmm cmdlets in case we're dealing
                      # with VM Host Cluster. However, for Storage File Server cluster
                      # we have to keep using the native cmdlets.

                        $AddClusterSharedVolumeParam = @{
                
                            InputObject = $ClusterDisk
                            Cluster     = $ClusterAddress
                        }
                        $ClusterSharedVolume =
                            Add-ClusterSharedVolume @AddClusterSharedVolumeParam

                        $ClusterSharedVolumeNode     = $ClusterSharedVolume.OwnerNode
                        $ClusterSharedVolumeNodeName = $ClusterSharedVolumeNode.Name

                        $ClusterSharedVolumeNodeAddress = $NodeAddress |
                            Where-Object -FilterScript {
                                $psItem -like "$ClusterSharedVolumeNodeName*"
                            }

                        $ClusterSharedVolumePath = "\\" +
                            $ClusterSharedVolumeNodeAddress +
                            "\c$\ClusterStorage\Volume1"

                        $RenameItemParam = @{

                            Path     = $ClusterSharedVolumePath
                            NewName  = $DiskName
                            PassThru = $True
                        }
                        $ClusterSharedVolumeNodeName = Rename-Item @RenameItemParam
                    }

               #endregion Add to Cluster Shared Volume

                $Message = '  Exiting  Get-ClusterDiskEx'
                Write-Debug -Message $Message

                Return $ClusterDisk
            }

            Else
            {
                $Message = 'There are no suitable disk(s) to initialize. Skipping'
                Write-Verbose -Message $Message

                $Message = '  Exiting  Get-ClusterDiskEx'
                Write-Debug -Message $Message
            }        

       #endregion Process Disk(s)
    }

    End
    {
    
    }
}