Function
Set-clusterEx
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({

            $psItem.GetType().FullName -in @(

                'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'
                'Microsoft.FailoverClusters.PowerShell.Cluster'
            )
        })]
        $Cluster
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Description
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int64]
        $Reserve = 2
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int64]
        $csvCacheSize = 1gb
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
        $RunAsAccount
    )

    [System.Void]( Import-ModuleEx -Name @( 'FailoverClusters', 'Storage' ) )

    Switch
    (
        $Cluster.GetType().FullName
    )
    {
        'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'
        {
            $ClusterParam = @{               
                
                vmHostCluster              = $Cluster
                Description                = $Description
                ClusterReserve             = $Reserve
                vmHostManagementCredential = $RunAsAccount
            }
            $Cluster = Set-scvmHostCluster @ClusterParam

            $Message = "Defining topology (fault domains) on the cluster `“$( $Cluster.Name )`”"
            Write-Verbose -Message $Message

            [Microsoft.Management.Infrastructure.CimInstance[]]$FaultDomainRack = @()

            $Cluster.Nodes | ForEach-Object -Process {

                $vmHost = $psItem

                $Message = "  Processing cluster node `“$( $vmHost.Name )`”"
                Write-Verbose -Message $Message

                $HostGroupRoom       = $vmHost.vmHostGroup
                $HostGroupDatacenter = $HostGroupRoom.ParentHostGroup

                $CustomPropertyParam = @{
        
                    Name      = 'Rack'
                    vmmServer = $vmHost.ServerConnection
                }
                $CustomProperty = Get-scCustomProperty @CustomPropertyParam

                $CustomPropertyValueParam = @{
            
                    CustomProperty = $CustomProperty
                    InputObject    = $vmHost
                }
                $CustomPropertyRack = Get-scCustomPropertyValue @CustomPropertyValueParam

                $CustomPropertyParam = @{
        
                    Name      = 'Rack Slot'
                    vmmServer = $vmHost.ServerConnection
                }
                $CustomProperty = Get-scCustomProperty @CustomPropertyParam

                $CustomPropertyValueParam = @{
            
                    CustomProperty = $CustomProperty
                    InputObject    = $vmHost
                }
                $CustomPropertyRackSlot = Get-scCustomPropertyValue @CustomPropertyValueParam

                $SessionParam = @{
        
                    ComputerName = $vmHost.Name
                    Verbose      = $False
                }
                $cimSession = New-cimSession @SessionParam

              # Define the Fault domains for “Site” and “Chassis” (room)

                $FaultDomainParam = @{

                    cimSession = $cimSession
                    Verbose    = $False
                }
                $FaultDomain = Get-ClusterFaultDomain @FaultDomainParam

                $FaultDomainDatacenter  = $FaultDomain | Where-Object -FilterScript { $psItem.Name -eq $HostGroupDatacenter.Name }
              # $FaultDomainRoom        = $FaultDomain | Where-Object -FilterScript { $psItem.Name -eq $HostGroupRoom.Name }         # Not used
                $FaultDomainRackCurrent = $FaultDomain | Where-Object -FilterScript { $psItem.Name -eq $CustomPropertyRack.Value }
                $FaultDomainNode        = $FaultDomain | Where-Object -FilterScript { $psItem.Name -eq $vmHost.ComputerName }

              # “Site” fault domain is set after the “Datacenter” in VMM (top-level host group)

             <# If
                (
                    $FaultDomainDatacenter
                )
                {
                    $Message = "    Site (Datacenter) is already set to `“$( $FaultDomainDatacenter.Name )`”"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $Message = "    Setting Site (Datacenter) to `“$( $HostGroupDatacenter.Name )`” with Location `“$( $HostGroupDatacenter.Description )`”"
                    Write-Verbose -Message $Message

                    $FaultDomainParam = @{
    
                        Name            = $HostGroupDatacenter.Name
                        Location        = $HostGroupDatacenter.Description
                        Description     = [System.String]::Empty
                        FaultDomainType = 'Site'
                        cimSession      = $cimSession
                        Verbose         = $False
                    }
                    Set-dcaaDescription -Define $FaultDomainParam -Verbose:$False
                    $FaultDomainDatacenter = New-ClusterFaultDomain @FaultDomainParam
                }  #>

              # There isn't a native Fault Domain type for “Room” (child host group)
              # in Failover Cluster object model. We cannot use the “Unknown” type for
              # the “Room” because it cannot be a child of “Site.” We also cannot use 
              # the “Chassis” type because it cannot contain “Racks.” Finally, we cannot
              # nest multiple “Sites” into each other. Hence we're going to skip this level
              # of hierarchy, and nest “Racks” directly into “Sites.”

              # “Rack” fault domain does not have a native representation in our VMM Host
              # Group hierarchy because we anticipate clusters spanning multiple racks, and
              # in VMM each cluster should fit entirely into the same Host group. Hence,
              # the “Rack” is not a Host Group, but rather a Custom property on the VM Host
              # object.

                If
                (
                    $FaultDomainRackCurrent
                )
                {
                    $Message = "    Rack is already set to `“$( $FaultDomainRackCurrent.Name )`”"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $Message = "    Setting Rack to `“$( $CustomPropertyRack.Value )`” with Location `“$( $HostGroupRoom.Name )`”"
                    Write-Verbose -Message $Message

                    $FaultDomainParam = @{
    
                        Name            = $CustomPropertyRack.Value
                        Location        = $HostGroupRoom.Name
                        Description     = [System.String]::Empty
                        FaultDomainType = 'Rack'
                      # FaultDomain     = $FaultDomainDatacenter.Name
                        cimSession      = $cimSession
                        Verbose         = $False
                    }
                    Set-dcaaDescription -Define $FaultDomainParam -Verbose:$False
                    $FaultDomainRackCurrent = New-ClusterFaultDomain @FaultDomainParam
                }

                $FaultDomainRack += $FaultDomainRackCurrent

              # “Node” fault domain exists by default, so instead of creating it, we define
              # properties.

                $Location = "Slot $( $CustomPropertyRackSlot.Value )"

                $Message = "    Setting Node `“$( $FaultDomainNode.Name )`” with Location `“$Location`”"
                Write-Verbose -Message $Message

                $FaultDomainParam = @{
   
                    InputObject     = $FaultDomainNode 
                    Location        = $Location
                    Description     = [System.String]::Empty
                    FaultDomain     = $FaultDomainRackCurrent.Name
                    cimSession      = $cimSession
                    Verbose         = $False
                }
                Set-dcaaDescription -Define $FaultDomainParam -Verbose:$False
                $FaultDomainNode = Set-ClusterFaultDomain @FaultDomainParam

              # Remove-cimSession -cimSession $cimSession
            }

          # Workaround for an issue with S2D enablement. We need to create the Site
          # Fault domain to be the last one.
  
            If
            (
                $FaultDomainDatacenter
            )
            {
                $Message = "  Site (Datacenter) is already set to `“$( $FaultDomainDatacenter.Name )`”"
                Write-Verbose -Message $Message
            }
            Else
            {
                $Message = "  Setting Site (Datacenter) to `“$( $HostGroupDatacenter.Name )`” with Location `“$( $HostGroupDatacenter.Description )`”"
                Write-Verbose -Message $Message

                $FaultDomainParam = @{
    
                    Name            = $HostGroupDatacenter.Name
                    Location        = $HostGroupDatacenter.Description
                    Description     = [System.String]::Empty
                    FaultDomainType = 'Site'
                    cimSession      = $cimSession
                    Verbose         = $False
                }
                Set-dcaaDescription -Define $FaultDomainParam -Verbose:$False
                $FaultDomainDatacenter = New-ClusterFaultDomain @FaultDomainParam
            }

            $Message = "  Setting Racks to `“$($FaultDomainDatacenter.Name)`”"
            Write-Verbose -Message $Message

            $FaultDomainParam = @{
   
                InputObject     = $FaultDomainRack
              # Location        = $Location
              # Description     = [System.String]::Empty
                FaultDomain     = $FaultDomainDatacenter.Name
                cimSession      = $cimSession
                Verbose         = $False
            }
          # Set-dcaaDescription -Define $FaultDomainParam -Verbose:$False
            $FaultDomainRack = Set-ClusterFaultDomain @FaultDomainParam

          # We cannot do that before S2D is enabled

            If
            (
                ( Get-ClusterFaultDomain -CimSession $cimSession -Type 'Rack' ).Count -gt 1 -and
                ( Get-Cluster -Name $cimSession.ComputerName ).S2DEnabled
            )
            {
                $Message = "  The cluster is enabled for S2D and has multiple racks. Setting Default Fault Domain type to Rack"
                Write-Verbose -Message $Message

                $FaultDomainAwareness = 'StorageRack'

                $Message = "    Processing the Storage Pool"
                Write-Verbose -Message $Message

                $Pool = Get-StoragePool -CimSession $Cluster.Name -IsPrimordial:$False

                Set-StoragePool -InputObject $Pool -FaultDomainAwarenessDefault $FaultDomainAwareness

                $Message = "    Processing the Storage Subsystem"
                Write-Verbose -Message $Message

                $SubSystem = Get-StorageSubSystem -StoragePool $Pool
        
                Set-StorageSubSystem -InputObject $SubSystem -FaultDomainAwarenessDefault $FaultDomainAwareness

                $Message = "    Processing the Storage Tiers"
                Write-Verbose -Message $Message

                $Tier = Get-StorageTier -StoragePool $Pool

                Set-StorageTier -InputObject $Tier -FaultDomainAwareness $FaultDomainAwareness
        
                $Message = 'Refreshing the Storage Provider. This might take a while'
                Write-Verbose -Message $Message

                $StorageProvider = Get-scStorageProvider -Name $Cluster.Name
                $StorageProvider = Read-scStorageProvider -StorageProvider $StorageProvider
            }
            Else
            {
                $Message = "The cluster does not have S2D enabled yet, or there's a signle rack. Skipping storage fault domain configuration"
                Write-Verbose -Message $Message
            }

            $Cluster = Get-Cluster -Name $Cluster.Name
        }

        'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
        {
            $ClusterParam = @{

                StorageFileServer = $Cluster
                Description       = $Description                
            }
            $Cluster = Set-scStorageFileServer @ClusterParam

            $Cluster = Get-Cluster -Name $Cluster.Name
        }
    }

  # Misc cluster properties

    $Message = "Setting CSV cache size to $( $csvCacheSize/1gb ) Gb"
    Write-Verbose -Message $Message
    
    $Cluster.BlockCacheSize              = $csvCacheSize/1mb

  # Sometimes CSV Balancer is known to get disabled, e.g. after running load
  # testing with VM Fleet. Hence, we explicitly enable it back.

    $Cluster.CsvBalancer                 =    1
    $Cluster.ClusterEnforcedAntiAffinity =    1
    $Cluster.ClusterLogSize              = 4096
}