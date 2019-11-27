<#
    set up various cluser storage settings
#>

Set-StrictMode -Version 'Latest'

Function
Set-clusterDiskEx
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({
            
                $psItem.GetType().FullName -in @(

                    'System.String'
                    'Microsoft.FailoverClusters.PowerShell.Cluster'
                    'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'
                    'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
                )
            
            })]
            $Cluster
        ,
         <# [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            $Node
        , #>
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Hashtable[]]
            $NodeSet
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateSet(
              # $Null,
                'SAN',
                'VHD',
                'S2D',
                'File Share'
            )]
            [System.String]
            $StorageType
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String[]]
            $FileShareName
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $FileShareWitness
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
            $vmmServer
    )

    Begin
    {
        $Message = "Entering Set-ClusterDiskEx for $Cluster"
        Write-Debug -Message $Message

        $Module = Import-ModuleEx -Name "FailoverClusters"

           #region Object Names

                Switch
                (
                    $Cluster.GetType().FullName
                )
                {
                    'System.String'
                    {
                        $ClusterName    = $Cluster.Split( '.' )[0]
                        $ClusterAddress = $Cluster
                        $Node           = [System.Collections.Generic.List[System.String]]::new()
                                                
                        $NodeSet.Node | ForEach-Object -Process {

                            $vmName = $psItem.Name + $ClusterAddress.Replace( $ClusterName, [System.String]::Empty )
                            
                            $Node.Add( $vmName )
                        }
                    }

                    'Microsoft.FailoverClusters.PowerShell.Cluster'
                    {
                        $ClusterName    = $Cluster.Name
                        $ClusterAddress = Resolve-DnsNameEx -Name $ClusterName                        
                        
                        $Node           = Get-ClusterNode -InputObject $Cluster
                     <# $NodeName    = $Node.Name
                        $NodeAddress = [System.String[]]@()

                        $NodeName | ForEach-Object -Process {
        
                            $NodeNameCurrent    = $psItem
                            $NodeAddressCurrent = Resolve-DnsNameEx -Name $NodeNameCurrent
                            $NodeAddress       += $NodeAddressCurrent
                        }  #>
                    }

                    'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'
                    {

                        $ClusterName    = $Cluster.Name
                        $ClusterAddress = Resolve-DnsNameEx -Name $ClusterName

                        $Node        = $Cluster.Nodes
                      # $NodeAddress = $Node.Name
                    }

                    'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
                    {
                        $ClusterName    = $Cluster.StorageProvider.Name
                        $ClusterAddress = Resolve-DnsNameEx -Name $ClusterName

                        $Node        = $Cluster.StorageNodes
                      # $NodeAddress = $Node.Name
                    }

                    Default
                    {
                        $Message = "Unexpected object type: `“$( $Cluster.GetType().FullName )`”"
                        Write-Warning -Message $Message
                    }
                }

           #endregion Object Name
    }

    Process
    {
          # The following section is obsolete since we now connect every Target
          # one by one when we provision individual Disks

          <#region Connect Targets

                $NodeSet | ForEach-Object -Process {

                    $NodeSetCurrent = $psItem

                    If
                    (
                        $NodeSetCurrent.iSCSITargetPortalAddress
                    )

                  # We're using iSCSI and need to connect it now.

                    {
                        Switch
                        (
                            $Cluster.GetType().FullName
                        )
                        {
                            'Microsoft.FailoverClusters.PowerShell.Cluster'

                            {
                                $ConnectIscsiTargetExParam = @{
            
                                    ComputerName        = $NodeSetCurrent.NodeName
                                    TargetPortalAddress = $NodeSetCurrent.iSCSITargetPortalAddress
                                }
                                $iSCSISession += Connect-IscsiTargetEx @ConnectIscsiTargetExParam
                            }

                            'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'

                            {

                              # Connect iSCSI storage with Vmm

                            }

                            'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'

                            {

                              # We cannot use Vmm to create initiator-side connections
                              # for File Server.

                                $ConnectIscsiTargetExParam = @{
            
                                    ComputerName        = $NodeSetCurrent.NodeName
                                    TargetPortalAddress = $NodeSetCurrent.iSCSITargetPortalAddress
                                }
                                $iSCSISession += Connect-IscsiTargetEx @ConnectIscsiTargetExParam
                            }
                        }
                    }
                }

           #endregion Connect #>

           #region Disk Witness

              # Check whether we need a Witness.
              # Note that we cannot rely on Vmm here, since it won't show
              # a File Share Witness. It only recognizes Disk Witness.

                Write-Verbose -Message "Evaluating Quorum configuration for $ClusterAddress"

                If
                (
                    $NodeSet.Count -eq 1                    
                )
                {
                    Switch
                    (
                        $StorageType
                    )
                    {
                        {
                            $psItem -in @( 'SAN', 'VHD' )
                        }
                        {
                            $Message = '  The cluster storage type is eligible for a Disk Witness'
                            Write-Verbose -Message $Message

                            $ClusterDiskParam = @{
                
                                Node           = $Node
                                SiteName       = $NodeSet[0].SiteName
                              # NodeSetName    = $NodeSet[0].Name
                              # Storagetype    = $StorageType
                                Size           = 1GB
                                ClusterAddress = $ClusterAddress
                            }

                            Switch
                            (
                                $StorageType
                            )
                            {
                                'VHD'
                                {
                                    If
                                    (
                                        $NodeSet[0][ 'HostName' ]
                                    )
                                    {
                                        $ClusterDiskParam.Add(
                                            'HostName',    $NodeSet[0].HostName
                                        )
                                    }

                                    If
                                    (
                                        $NodeSet[0][ 'HostVhdPath' ]
                                    )
                                    {
                                        $ClusterDiskParam.Add(
                                            'HostVhdPath', $NodeSet[0].HostVhdPath
                                        )
                                    }
                                }

                                'SAN'
                                {
                                    If
                                    (
                                        $NodeSet[0][ 'iSCSITargetPortalAddress' ]
                                    )
                                    {
                                        $ClusterDiskParam.Add(
                                            'iSCSITargetPortalAddress',
                                            $NodeSet[0].iSCSITargetPortalAddress
                                        )
                                    }

                                    If
                                    (
                                        $NodeSet[0][ 'StoragePoolName' ]
                                    )
                                    {
                                        $ClusterDiskParam.Add(
                                            'StoragePoolName',
                                            $NodeSet[0].StoragePoolName
                                        )
                                    }
                                }

                             <# 'S2D'
                                {
                                    $Message = "There are no shared disk resources in Storage Spaces Direct. Consider specifying a File Share witness."
                                    Write-Verbose -Message $Message
                                }  #>
                            }

                         <# $ClusterDiskParam.GetEnumerator() | ForEach-Object -Process {
                                Write-Verbose -Message ( "Name:  " + $psItem.Name  )
                                Write-Verbose -Message ( "Value: " + $psItem.Value )
                            }

                            Write-Verbose -Message "Get-ClusterDiskEx Params"

                            $ClusterDiskParam.GetEnumerator() | ForEach-Object -Process {
                                Write-Verbose -Message ( $psItem.Name + ": " + $psItem.Value )
                            }  #>

                            If
                            (
                                $NodeSet[0][ 'Name' ]
                            )
                            {
                                $ClusterDiskParam.Add( 'NodeSetName', $NodeSet[0].Name )
                            }

                            If
                            (
                                $vmmServer
                            )
                            {
                                $ClusterDiskParam.Add( 'vmmServer', $vmmServer )
                            }

                            $ClusterDisk = Get-ClusterDiskEx @ClusterDiskParam

                            $Message = '  Witness disk was created'
                        }

                        {
                            $psItem -in @( 'S2D', 'File Share' )
                        }
                        {
                            $Message = '  Specified design does not assume shared storage. Consider specifying a File Share witness'
                        }

                        Default
                        {
                            $Message = "  Unknown Storage type: `“$psItem`”"
                        }
                    }
                }
                Else
                {
                    $Message = '  A Disk Witness is not suitable for “Stretched” (multi-site) clusters'
                }

                Write-Verbose -Message $Message
                
             <# Legacy logic which was replaced by the above

                If
                (
                    ( $NodeSet.Count -eq 1 ) -and

                  # Normally we would use “-InputObject = $Cluster” here.
                  # However, here $Cluster may have different types of value,
                  # depending on the Node Type and thus script execution mode.

                    (
                        -Not (
                            Get-ClusterQuorum -Cluster $ClusterAddress
                        ).QuorumResource
                    )
                )

              # Our cluster fits entirely into one Node Set,
              # i.e. all storage is connected to all nodes.
              # And there's no Witness yet.
              # Thus, process to Disk Witness.

                {                    
                    $Message = "There's no Witness Configured. Creating Disk Witness"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    Write-Verbose -Message "Skipping Disk Witness"

                  # There are multiple Node Sets in cluster.
                  # This means different cluster nodes may have different
                  # storage attached. This is typical to multi-site clusters.
                  # Or the cluster already has a Witness defined.
                  # Thus, skip Disk Witness. We assume
                  # there will be File Share Witness selected later.

                }  #>

           #endregion Disk Witness

           #region File Share Witness

                Switch
                (
                    $Cluster.GetType().FullName
                )
                {
                    {
                        $psItem -eq 'Microsoft.FailoverClusters.PowerShell.Cluster'            -or
                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.HostCluster' -or
                        $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
                    }
                    {
                        If
                        (

                          # Normally we would use “-InputObject = $Cluster” here.
                          # However, here $Cluster may have different types of value,
                          # depending on the Node Type and thus script execution mode.

                            $FileShareWitness -And
                            ( -Not (
                                Get-ClusterQuorum -Cluster $ClusterAddress
                            ).QuorumResource )                            
                        )

                      # We still do not have a Witness resource. This is either because
                      # we're running a Multi-Site cluster, or there's no shared disks
                      # whatsoever. Thus, let's define a File Share Witness (FSW).

                        {
                            $SetClusterQuorumParam = @{

                                Cluster          = $ClusterAddress
                                FileShareWitness = $FileShareWitness
                            }
                            $ClusterQuorum = Set-ClusterQuorum @SetClusterQuorumParam
                        }
                    }

                    'System.String'
                    {
                        $Message = 'Not configuring a File Share Witness for a cluster in an untrusted domain'
                        Write-Verbose -Message $Message
                    }

                    Default
                    {
                        $Message = 'Unknown cluster type'
                        Write-Warning -Message $Message
                    }
                }

           #endregion File Share Witness

           #region Data Disks

              # Loop through the list of Node Sets, then their Roles.

                Write-Verbose -Message "Processing Data Disks"

                $NodeSet | ForEach-Object -Process {

                    $NodeSetCurrent = $psItem

                    If
                    (
                        $NodeSetCurrent.Contains( "Role" )
                    )
                    {
                        $NodeSetCurrentNodeName = $NodeSetCurrent.Node.Name

                        $NodeSetCurrentNodeAddress = @()
                        $NodeSetCurrentNodeName | Sort-Object | ForEach-Object -Process {

                            $NodeSetCurrentNodeCurrentName = $psItem

                            Switch
                            (
                                $Cluster.GetType().FullName
                            )
                            {
                                {
                                    $psItem -eq 'Microsoft.FailoverClusters.PowerShell.Cluster'            -or
                                    $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.HostCluster' -or
                                    $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
                                }
                                {
                                    $NodeSetCurrentNodeCurrentAddress = Resolve-DnsNameEx -Name $NodeSetCurrentNodeCurrentName
                                }

                                'System.String'
                                {
                                    $NodeSetCurrentNodeCurrentAddress = $NodeSetCurrentNodeCurrentName + $ClusterAddress.Replace( $ClusterName, [System.String]::Empty )
                                }

                                Default
                                {
                                    $Message = 'Unknown cluster type'
                                    Write-Warning -Message $Message
                                }
                            }
                            
                            $NodeSetCurrentNodeAddress += $NodeSetCurrentNodeCurrentAddress
                        }

                        Write-Debug -Message "All Nodes:"
                        $Node | Sort-Object | 
                            ForEach-Object -Process { Write-Debug -Message "  * $( $psItem )" }

                        Write-Debug -Message "Node Set Nodes:"
                        $NodeSetCurrentNodeAddress | Sort-Object |
                            ForEach-Object -Process { Write-Debug -Message "  * $psItem" }

                        $NodeSetCurrentNode = $Node | Sort-Object | Where-Object -FilterScript {
                 
                            $NodeCurrent     = $psItem                            

                            Switch
                            (
                                $Cluster.GetType().FullName
                            )
                            {
                                {
                                    $psItem -eq 'Microsoft.FailoverClusters.PowerShell.Cluster'            -or
                                    $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.HostCluster' -or
                                    $psItem -eq 'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
                                }
                                {
                                    $NodeCurrentName    = $NodeCurrent.Name
                                    $NodeCurrentAddress = Resolve-DnsNameEx -Name $NodeCurrentName
                                }

                                'System.String'
                                {
                                    $NodeCurrentName    = $NodeCurrent
                                    $NodeCurrentAddress = $NodeCurrent
                                }

                                Default
                                {
                                    $Message = 'Unknown cluster type'
                                    Write-Warning -Message $Message
                                }
                            }                            

                            $NodeCurrentAddress -in $NodeSetCurrentNodeAddress
                        }

                        Write-Debug -Message "Current Nodes:"
                        $NodeSetCurrentNode | Sort-Object |
                            ForEach-Object -Process { Write-Debug -Message "  * $( $psItem )" }

                        $NodeSetCurrent.Role | ForEach-Object -Process {

                            $RoleCurrent = $psItem

                            If
                            (
                                $RoleCurrent.Contains( 'Name' )
                            )
                            {
                                Write-Verbose -Message "Processing Disk(s) for role: `“$($RoleCurrent.Name)`”"
                            }
                            Else
                            {
                                $Message = "Processing Shared Storage for Cluster $ClusterAddress"
                                Write-Verbose -Message $Message
                            }

                            If
                            (
                                $RoleCurrent.Contains( "Disk" ) -and
                                $RoleCurrent.Disk
                            )
                            {
                                $RoleCurrent.Disk | ForEach-Object -Process {

                                    $DiskCurrent = $psItem

                                    Switch
                                    (
                                        $DiskCurrent.GetType().FullName
                                    )
                                    {
                                        "System.Collections.Hashtable"

                                      # We're looping by individual disk name,
                                      # using disk properties like Size and Shared Volume.

                                        {
                                            Write-Verbose -Message "Processing Disk by Name `“$($DiskCurrent.Name)`”"

                                            $ClusterDiskParam = @{
                
                                                Node           = $NodeSetCurrentNode
                                                SiteName       = $NodeSetCurrent.SiteName
                                              # NodeSetName    = $NodeSetCurrent.Name
                                                Name           = $DiskCurrent.Name
                                              # StorageType    = $StorageType
                                                ClusterAddress = $ClusterAddress
                                            }

                                            If
                                            (
                                                $RoleCurrent[ 'Name' ]
                                            )
                                            {
                                                $ClusterDiskParam.Add(
                                                    'RoleName', $RoleCurrent.Name
                                                )                            
                                            }                                            

                                            If
                                            (
                                                $NodeSetCurrent[ 'Name' ]
                                            )
                                            {
                                                $ClusterDiskParam.Add(

                                                    'NodeSetName', $NodeSetCurrent.Name
                                                )
                                            }

                                            If
                                            (
                                                $DiskCurrent[ "Size" ]
                                            )
                                            {
                                                $ClusterDiskParam.Add(
                                                    "Size", $DiskCurrent.Size
                                                )
                                            }

                                            Switch
                                            (
                                                $StorageType
                                            )
                                            {
                                                'VHD'
                                                {
                                                    If
                                                    (
                                                        $NodeSetCurrent[ 'HostName' ]
                                                    )
                                                    {
                                                        $ClusterDiskParam.Add(
                                                            'HostName',    $NodeSetCurrent.HostName
                                                        )
                                                    }

                                                    If
                                                    (
                                                        $NodeSetCurrent[ 'HostVhdPath' ]
                                                    )
                                                    {
                                                        $ClusterDiskParam.Add(
                                                            'HostVhdPath', $NodeSetCurrent.HostVhdPath
                                                        )
                                                    }
                                                }
                                                
                                                'SAN'
                                                {
                                                    If
                                                    (
                                                        $NodeSetCurrent[ 'iSCSITargetPortalAddress' ]
                                                    )
                                                    {
                                                        $ClusterDiskParam.Add(
                                                            'iSCSITargetPortalAddress',
                                                            $NodeSetCurrent.iSCSITargetPortalAddress
                                                        )
                                                    }

                                                    If
                                                    (
                                                        $NodeSetCurrent[ 'StoragePoolName' ]
                                                    )
                                                    {
                                                        $ClusterDiskParam.Add(
                                                            'StoragePoolName',
                                                            $NodeSetCurrent.StoragePoolName
                                                        )
                                                    }
                                                }
                                            }
        
                                            If
                                            (
                                                $vmmServer
                                            )
                                            {
                                                $ClusterDiskParam.Add( 'vmmServer', $vmmServer )
                                            }

                                            $ClusterDisk = Get-ClusterDiskEx @ClusterDiskParam
                                    
                                          # Provision Storage File Share(s)

                                            If
                                            (
                                                $DiskCurrent.Contains( "FileShare" )
                                            )
                                            {
                                                Write-Verbose -Message "There are Storage File Share(s) for Disk $($DiskCurrent.Name)"
                            
                                                $DiskCurrent.FileShare | ForEach-Object -Process {

                                                    $FileShareCurrentProperty = $psItem

                                                    Write-Verbose -Message "Processing Storage File Share $($FileShareCurrentProperty.Name)"

                                                    $GetScStorageFileShareParam = @{
                            
                                                        Name      = $FileShareCurrentProperty.Name
                                                        vmmServer = $vmmServer
                                                    }
                                                    $StorageFileShare = Get-scStorageFileShare @GetScStorageFileShareParam

                                                    If
                                                    (
                                                        $StorageFileShare
                                                    )
                                                    {
                                                        Write-Verbose -Message "Storage File Share already exists!"
                                                    }

                                                    Else

                                                    {
                                                        Write-Verbose "Creating Storage File Share"

                                                        Set-dcaaDescription -Define $FileShareCurrentProperty

                                                        Write-Verbose -Message "Looking for Storage Classificaion $($FileShareCurrentProperty.ClassificationName)"

                                                        $GetSCStorageClassificationParam = @{

                                                            Name      = $FileShareCurrentProperty.ClassificationName
                                                            vmmServer = $vmmServer
                                                        }
                                                        $StorageClassification =
                                                            Get-scStorageClassification @GetSCStorageClassificationParam

                                                        Write-Verbose -Message "Obtained Storage Classification $StorageClassification"

                                                        $DiskName = $ClusterDisk.Name

                                                        Write-Verbose -Message "Looking for Storage Volume $DiskName"

                                                        $StorageVolume = $Cluster.StorageVolumes |
                                                            Where-Object -FilterScript {
                                                                $psItem.Name -like "*$DiskName*"
                                                            }

                                                        Write-Verbose -Message "Obtained Storage Volume $StorageVolume"

                                                        $NewScStorageFileShareParam = @{

                                                             Name                  = $FileShareCurrentProperty.Name
                                                             Description           = $FileShareCurrentProperty.Description
                                                             StorageFileServer     = $Cluster
                                                             StorageVolume         = $StorageVolume
                                                             StorageClassification = $StorageClassification
                                                           # ContinuouslyAvailable = $True
                                                        }
                                                        $StorageFileShare = New-scStorageFileShare @NewScStorageFileShareParam

                                                        Write-Verbose -Message "Created Storage File Share $($FileShareCurrentProperty.Name)"
                                                    }
                                                }

                                                Write-Verbose -Message "Done processing Storage File Share(s) for Disk $($DiskCurrent.Name)"
                                            }
                                        }

                                        "System.Int32"                      

                                      # We do not have a disk name, just a count.
                                      # The count specifies the number of Shared Volumes to add.

                                        {
                                            Write-Verbose -Message "Processing total $DiskCurrent disk(s)"

                                            1..$($DiskCurrent) | ForEach-Object -Process {

                                                $SharedVolumeNumber = $psItem

                                                Write-Verbose -Message "Processing Disk by number $($SharedVolumeNumber)"

                                                If
                                                (
                                                    $SharedVolumeNumber -lt 10
                                                )
                                                {
                                                    $SharedVolumeName = 'CSV0' + $SharedVolumeNumber
                                                }
                                                Else
                                                {
                                                    $SharedVolumeName = 'CSV' + $SharedVolumeNumber
                                                }

                                                $ClusterDiskParam = @{
                
                                                    Node           = $NodeSetCurrentNode
                                                    SiteName       = $NodeSetCurrent.SiteName
                                                  # NodeSetName    = $NodeSetCurrent.Name
                                                    Name           = $SharedVolumeName
                                                  # StorageType    = $StorageType
                                                    ClusterAddress = $ClusterAddress
                                                }

                                                If
                                                (
                                                    $RoleCurrent[ 'Name' ]
                                                )
                                                {
                                                    $ClusterDiskParam.Add(
                                                        'RoleName', $RoleCurrent.Name
                                                    )                            
                                                }                                                

                                                If
                                                (
                                                    $NodeSetCurrent[ 'Name' ]
                                                )
                                                {
                                                    $ClusterDiskParam.Add(

                                                        'NodeSetName', $NodeSetCurrent.Name
                                                    )
                                                }

                                                Switch
                                                (
                                                    $StorageType
                                                )
                                                {
                                                    'VHD'
                                                    {
                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'HostName' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'HostName',    $NodeSetCurrent.HostName
                                                            )
                                                        }

                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'HostVhdPath' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'HostVhdPath', $NodeSetCurrent.HostVhdPath
                                                            )
                                                        }
                                                    }
                                                
                                                    'SAN'
                                                    {
                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'iSCSITargetPortalAddress' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'iSCSITargetPortalAddress',
                                                                $NodeSetCurrent.iSCSITargetPortalAddress
                                                            )
                                                        }

                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'StoragePoolName' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'StoragePoolName',
                                                                $NodeSetCurrent.StoragePoolName
                                                            )
                                                        }
                                                    }
                                                }
        
                                                If
                                                (
                                                    $vmmServer
                                                )
                                                {
                                                    $ClusterDiskParam.Add( 'vmmServer', $vmmServer )
                                                }

                                                $ClusterDisk = Get-ClusterDiskEx @ClusterDiskParam
                                            }
                                        }

                                        "System.Int64"

                                      # We have a list of Shared Volumes to provision
                                      # with Size specified for each

                                        {
                                            Write-Verbose -Message "Processing multiple Shared Volumes disk(s)"

                                            $SharedVolumeNumber = 1

                                            $DiskCurrent | ForEach-Object -Process {

                                                $SharedVolumeSize = $psItem

                                                Write-Verbose -Message "Processing Shared Volume number $($SharedVolumeNumber)"

                                                If
                                                (
                                                    $SharedVolumeNumber -lt 10
                                                )
                                                {
                                                    $SharedVolumeName = 'CSV0' + $SharedVolumeNumber
                                                }
                                                Else
                                                {
                                                    $SharedVolumeName = 'CSV' + $SharedVolumeNumber
                                                }

                                                $ClusterDiskParam = @{
                
                                                    Node           = $NodeSetCurrentNode
                                                    SiteName       = $NodeSetCurrent.SiteName
                                                  # NodeSetName    = $NodeSetCurrent.Name
                                                    Name           = $SharedVolumeName
                                                    Size           = $SharedVolumeSize
                                                  # StorageType    = $StorageType
                                                    ClusterAddress = $ClusterAddress
                                                }

                                                If
                                                (
                                                    $RoleCurrent[ 'Name' ]
                                                )
                                                {
                                                    $ClusterDiskParam.Add(
                                                        'RoleName', $RoleCurrent.Name
                                                    )                            
                                                }

                                                If
                                                (
                                                    $NodeSetCurrent[ 'Name' ]
                                                )
                                                {
                                                    $ClusterDiskParam.Add(

                                                        'NodeSetName', $NodeSetCurrent.Name
                                                    )
                                                }

                                                Switch
                                                (
                                                    $StorageType
                                                )
                                                {
                                                    'VHD'
                                                    {
                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'HostName' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'HostName',    $NodeSetCurrent.HostName
                                                            )
                                                        }

                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'HostVhdPath' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'HostVhdPath', $NodeSetCurrent.HostVhdPath
                                                            )
                                                        }
                                                    }
                                                
                                                    'SAN'
                                                    {
                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'iSCSITargetPortalAddress' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'iSCSITargetPortalAddress',
                                                                $NodeSetCurrent.iSCSITargetPortalAddress
                                                            )
                                                        }

                                                        If
                                                        (
                                                            $NodeSetCurrent[ 'StoragePoolName' ]
                                                        )
                                                        {
                                                            $ClusterDiskParam.Add(
                                                                'StoragePoolName',
                                                                $NodeSetCurrent.StoragePoolName
                                                            )
                                                        }
                                                    }
                                                }

                                                If
                                                (
                                                    $vmmServer
                                                )
                                                {
                                                    $ClusterDiskParam.Add( 'vmmServer', $vmmServer )
                                                }
        
                                                $ClusterDisk = Get-ClusterDiskEx @ClusterDiskParam

                                                $SharedVolumeNumber++
                                            }
                                        }

                                        Default 
                                        {
                                            Write-Verbose -Message "Unknown format of Disk enumeration!"
                                        }
                                    }
                                }
                            }
                            ElseIf
                            (
                                $StorageType -eq 'S2D'
                            )
                            {
                                $Message = 'Processing automatic storage configuration for Storage Spaces Direct (S2D)'
                                Write-Verbose -Message $Message

                                New-scStorageVolumeEx -vmHostCluster $Cluster
                            }
                            Else
                            {
                                $Message = "No disks were specified for the Role or Cluster"
                                Write-Verbose -Message $Message
                            }
                        }
                    }
                    Else
                    {
                        Write-Verbose -Message "No Roles defined for the current Node Set!"
                    }
                } 

           #endregion Data Disk

           #region Register File Shares

                Write-Verbose -Message "Registering Storage File Share(s)"

                $StorageFileShare = @()

                If
                (
                    $FileShareName
                )
                {
                    $FileShareName | ForEach-Object -Process {

                        $FileShareCurrentName = $psItem

                        Write-Verbose -Message "Processing Share: $FileShareCurrentName"

                        Switch
                        (
                            $Cluster.GetType().FullName
                        )
                        {
                            'Microsoft.FailoverClusters.PowerShell.Cluster'

                            {

                              # Register File Share using Native tools.
        
                            }

                            'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'

                            {
                                $GetSCStorageFileShareParam = @{

                                    Name      = $FileShareCurrentName
                                    vmmServer = $vmmServer
                                }
                                $StorageFileShare = Get-scStorageFileShare @GetSCStorageFileShareParam

                                If
                                (
                                    $StorageFileShare -in $Cluster.RegisteredStorageFileShares
                                )
                                {
                                    Write-Verbose -Message "Already Registered!"
                                }
                                Else
                                {
                                    $Cluster.Nodes | ForEach-Object -Process {

                                        $vmHostCurrent = $psItem

                                        $SetscvmHostParam = @{

                                            vmHost        = $vmHostCurrent
                                            BaseDiskPaths = $StorageFileShare
                                        }
                                        $vmHostCurrent = Set-scvmHost @SetscvmHostParam
                                    }

                                    $RegisterSCStorageFileShareParam = @{

                                        StorageFileShare = $StorageFileShare
                                        vmHostCluster    = $Cluster
                                    }
                                    $StorageFileShare =
                                        Register-scStorageFileShare @RegisterSCStorageFileShareParam
                                }
                            }

                            'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
                
                            {

                              # Nothing to do here.
                              # We're not going to register a File Share
                              # with a File Server cluster itself.
                
                            }
                        }
                    }
                }
                Else
                {
                    Write-Verbose -Message "There are no File Shares to register"
                }

           #endregion Register File Shares
    }

    End
    {
        $Message = "Exiting  Set-ClusterDiskEx for $Cluster"
        Write-Debug -Message $Message
    }
}