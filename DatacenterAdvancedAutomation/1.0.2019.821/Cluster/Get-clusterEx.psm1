<#
    create or retreive an existing cluster
#>

Function
Get-clusterEx
{
    [cmdletBinding()]
    
    Param(

      # Cluster Name Object (CNO)
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
      # Virtual Computer Object (VCO)
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $FileServerName
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
        [System.Net.ipAddress]
        $ipAddress
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({

            $psItem[0].GetType().FullName -in @(

              # Value type for pre-vmm environment, where you create Cluster
              # with Native CmdLets from hosts deployed out-of-band (manually)

                'System.Collections.Hashtable'
                'System.String'
                'Microsoft.SystemCenter.VirtualMachineManager.vm'

              # Value type for VM Host Clusters
              # (to be created with Vmm, or already existing in Vmm)

                'Microsoft.SystemCenter.VirtualMachineManager.Host'

              # Value type for File Server Clusters to be created with Vmm

                'Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig'

              # Value type for File Server Clusters already existing in Vmm

                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
            )
        })]
        [System.Object[]]
        $Node
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ManagementNetworkName = 'Management'
    ,
      # File Servers are not normally associated with any Host Group,
      # this we need to explicitly specify Site Name in order
      # to allocate IP Address from the correct Static IP Address Pool
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SiteName
    ,
      # This only applies VM Host Clusters
      # and not for Storage Server Clusers      
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
        $RunAsAccount
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateSet(
            'Management',
            'Compute',
            'Network',
            'Storage',
            'Virtual'
        )]
        [System.String]
        $ScaleUnitType
 <# ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $EnableS2D  #>
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.String]
        $NodeSetName
     )

    Begin
    {
        $Message = "Entering Get-ClusterEx for $Name"
        Write-Verbose -Message $Message

      # Resolve node name

        $NodeAddress = @()

        Switch
        (
            $Node[0].GetType().FullName
        )
        {
            {
                $psItem -in @(
                
                    'Microsoft.SystemCenter.VirtualMachineManager.vm'
                    'System.Collections.Hashtable'
                )
            }
            {
                $NodeAddress = Resolve-dnsNameEx -Name $Node.Name
            }

            'System.String'
            {
                $NodeAddress = Resolve-dnsNameEx -Name $Node
            }

            {
                $psItem -in @(
                
                    'Microsoft.SystemCenter.VirtualMachineManager.vm'
                    'System.Collections.Hashtable'
                    'System.String'
                )
            }
            {
                $InstallWindowsFeatureExParam = @{

                    ServerAddress = $NodeAddress
                    FeatureName   = "Failover-Clustering"
                }
                $WindowsFeature = Install-WindowsFeatureEx @InstallWindowsFeatureExParam
            }

            Default
            {
                $Message = "No need to resolve node address since an object of type `“$($Node[0].GetType().FullName)`” already exists"
                Write-Debug -Message $Message
            }
        }

      # Determine whether the cluster exits

        $Cluster  = $Null
        $Address  = [System.String]::Empty
        $Address  = Resolve-DnsNameEx -Name $Name -Wait:$False
    }

    Process
    {
        If
        (
            $Address
        )

      # There's an exising cluster. We need to fix IP Address Assignment
      # if we're in Vmm mode and the cluster was created out-of-band.

        {
            $Message = "Existing cluster name resolved to $Address"
            Write-Verbose -Message $Message

            Switch
            (
                $Node[0].GetType().FullName
            )
            {
                {
                    $psItem -in @(
                
                        'Microsoft.SystemCenter.VirtualMachineManager.vm'
                        'System.Collections.Hashtable'
                        'System.String'
                    )
                }
                {
                    $Cluster = Get-Cluster -Name $Address

                    $NodeAddressCurrent = Resolve-dnsNameEx -Name ( Get-ClusterNode -InputObject $Cluster ).Name

                    $NodeAddressAdd = $NodeAddress | Where-Object -FilterScript { $PSItem -notin $NodeAddressCurrent }

                    If
                    (
                        $NodeAddressAdd
                    )
                    {
                        $Message = '  Adding node(s):'
                        Write-Verbose -Message $Message

                        $NodeAddressAdd | ForEach-Object -Process {

                            $Message = "   * $psItem"
                            Write-Verbose -Message $Message
                        }

                        $NodeParam = @{

                            Name        = $NodeAddressAdd
                            Type        = 'Node'
                            InputObject = $Cluster
                        }
                        [System.Void]( Add-ClusterNode @NodeParam )
                    }
                }
                
                'Microsoft.SystemCenter.VirtualMachineManager.Host'                
                {
                    $Cluster = Get-scvmHostCluster -Name $Address

                  # Check whether all of the nodes are already in cluster.

                    $NodeCluster = $Cluster.Nodes

                    $NodeAdd = $Node | Where-Object -FilterScript {
                        
                        $NodeCurrent = $psItem
                        $NodeCurrent -NotIn $NodeCluster
                    }

                    If
                    (
                        $NodeAdd
                    )

                  # There are nodes which are already in VMM
                  # but not added to the cluster yet.

                    {
                        Write-Verbose -Message "Adding new node $($NodeAdd.Name) to Cluster $($Cluster.Name)"

                        $InstallscvmHostClusterParam = @{

                            vmHost         = $NodeAdd
                            vmHostCluster  = $Cluster
                            Credential     = $RunAsAccount
                          # SkipValidation = $True
                            vmmServer      = $vmmServer
                        }
                        $Cluster = Install-scvmHostCluster @InstallscvmHostClusterParam
                    }

                  # Refresh the cluster and figure out whether we need to fix
                  # the IP Address.

                    Write-Verbose -Message "Refreshing VM Host Cluster in VMM"

                    $Cluster = Read-scvmHostCluster -vmHostCluster $Cluster

                    $ClusterAddressIp = $Cluster.ipAddresses
                    $ClusterAddressIp | ForEach-Object -Process {
                        
                        $ClusterAddressIpCurrent = $psItem

                        $GetSCipAddressParam = @{

                            ipAddress = $ClusterAddressIpCurrent
                            vmmServer = $vmmServer
                        }
                        $ipAddressCurrent = Get-scipAddress @GetSCipAddressParam

                        If
                        (
                            $ipAddressCurrent.AssignedToType -eq "VirtualNetworkAdapter"
                        )
                        {
                            $ClusterId           = $Cluster.ID
                            $ClusterName         = $Cluster.Name
                            $StaticipAddressPool = $ipAddressCurrent.AllocatingAddressPool
                            $ipAddressCurrent    = Revoke-scipAddress -AllocatedipAddress $ipAddressCurrent
                            
                            $GrantSCipAddressParam = @{

                                ipAddress           = $ipAddressCurrent
                                Description         = $ClusterName
                                StaticipAddressPool = $StaticipAddressPool
                                GrantToObjectType   = "HostCluster"
                                GrantToObjectID     = $ClusterId                                
                            }
                            $ipAddressCurrent = Grant-scipAddress @GrantSCipAddressParam
                        }
                    }
                }

                'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'                
                {
                    $StorageProvider = Get-scStorageProvider -Name $Address
                    $Cluster         = $StorageProvider.StorageFileServers

                  # Nothing to fix here
                }
            }

            Write-Verbose -Message "Obtained Cluster object: $Cluster"
        }

        Else

      # There's no Cluster yet. We're going to Create the cluster.

        {
            $Message = 'Creating Cluster'
            Write-Verbose -Message $Message

          # If
          # (
          #     $ipAddress
          # )
          # {
          #     $ipAddressString = $ipAddress
          #     $ipAddress       = [System.Net.ipAddress]$ipAddressString
          # }
            
            Switch
            (
                $Node[0].GetType().FullName
            )
            {
                {
                    $psItem -in @(
                
                        'Microsoft.SystemCenter.VirtualMachineManager.vm'
                        'System.Collections.Hashtable'
                        'System.String'
                    )
                }
                {
                    $ClusterParam = @{

                        Name                      = $Name
                        Node                      = $NodeAddress
                        StaticAddress             = $ipAddress.ToString()
                        AdministrativeAccessPoint = 'ActiveDirectoryAndDns'
                    }
                    $Cluster = New-Cluster @ClusterParam
                }
                
                'Microsoft.SystemCenter.VirtualMachineManager.Host'                
                {
                    
                  # Cluster Properties and common properties among nodes
                  # are derived from the first node.

                    $SiteName     = $Node[0].vmHostGroup.ParentvmHostGroup.Name
                  # $RunAsAccount = $Node[0].RunAsAccount

                  # Grant IP Address from Vmm Static IP Address Pool
                  # This is done regardless of whether we have explicitly
                  # specified IP Address for cluster or not.

                  # Actually, this is not required since “Install-scvmHostCluster”
                  # assumes IP Address parameter as a string.

                    $GrantScipAddressExParam = @{

                        vmmServer         = $vmmServer
                        Description       = $Name
                        NetworkName       = $ManagementNetworkName
                        SiteName          = $SiteName
                        GrantToObjectType = 'HostCluster'
                        ScaleUnitType     = $ScaleUnitType
                    }

                    If
                    (
                        $ipAddress
                    )
                    {
                      # Temporarily grant IP address in order to validate that
                      # it belongs to the Static IP Address Pool and not already
                      # occupied

                        $GrantScipAddressExParam.Add(
                            "ipAddress", $ipAddress
                        )

                        If
                        (
                            $NodeSetName
                        )
                        {
                            $GrantScipAddressExParam.Add(
                                'NodeSetName', $NodeSetName
                            )
                        }

                        $ipAddressGrant = Grant-scipAddressEx @GrantScipAddressExParam

                        $ipAddressGrant = Revoke-scipAddress -AllocatedipAddress $ipAddressGrant

                        $ipAddress = [System.Net.ipAddress]$ipAddressGrant.Address
                    }

                    Write-Verbose -Message "Creating cluster $Name using Credentials of ""$RunAsAccount"". This account should have the following set of permissions:"
                    Write-Verbose -Message " * local admin permissions on all the nodes"
                    Write-Verbose -Message " * log on locally on VMM server"
                    Write-Verbose -Message " * permissions on the pre-staged computer account for Cluster Name Object (CNO)"
                    Write-Verbose -Message "Additionally, the VMM service account needs `“Replace a process level token`” (AssignPrimaryTokenPrivilege)"

                  # Explicitly add the Run As account to local administrators
                  # group on all perspective cluster nodes                    

                    [void]( Add-Account -ComputerName $Node.Name -AccountName $RunAsAccount.UserName )

                  # Build the cluster

                    $InstallscvmHostClusterParam = @{

                        ClusterName      = $Name
                        Description      = $Description
                        vmHost           = $Node
                        ClusteripAddress = $ipAddress.ToString()
                        Credential       = $RunAsAccount
                      # SkipValidation   = $False                        
                    }
                 
                  # We cannot Enable S2D before we define Fault domains

                 <# If
                    (
                        $EnableS2D
                    )
                    {
                        $Message = "The cluster will be enabled for Storage Spaces Direct (S2D)"
                        Write-Verbose -Message $Message

                        $InstallscvmHostClusterParam.Add(
                            "EnableS2D", $True
                        )
                    }  #>

                    $Cluster = Install-scvmHostCluster @InstallscvmHostClusterParam
                }

              # This assumes we created Physical Computer Configuration in order
              # to deploy File Server cluster. All other Scale Unit Types assume
              # we deploy each node individually, and thus Get-ClusterEx accepts
              # VM Host object for those types to provision a cluster.

                'Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig'
                {

                  # Grant IP Address from Vmm Static IP Address Pool
                  # This is done regardless of whether we have explicitly
                  # specified IP Address for cluster or not.

                    $GrantScipAddressExParam = @{

                        vmmServer         = $vmmServer
                        Description       = $Name
                        NetworkName       = $ManagementNetworkName
                        SiteName          = $SiteName
                        GrantToObjectType = "StorageArray"
                        ScaleUnitType     = $ScaleUnitType
                    }

                    If
                    (
                        $ipAddress
                    )
                    {
                        $GrantScipAddressExParam.Add(
                            "ipAddress", $ipAddress
                        )
                    }

                    $ipAddressGrant = Grant-scipAddressEx @GrantScipAddressExParam

                    $ipAddress = [System.Net.ipAddress]$ipAddressGrant.Address

                  # Create cluser

                    $InstallSCStorageFileServerParam = @{

                        ClusterName            = $Name
                        ScaleoutFileServerName = $FileServerName
                        PhysicalComputerConfig = $Node
                        ClusteripAddress       = $ipAddress
                        SkipClusterValidation  = $True
      
                      # Not applicable here. Will inherit from Physical Computer Template      
                      # RunAsAccount           = $RunAsAccount

                      # Not applicable here. Will inherit from input objects.
                      # vmmServer              = $vmmServer
                    }    
                    $Cluster = Install-scStorageFileServer @InstallSCStorageFileServerParam
                }
            }

          # This is to wait till cluster name is resolvable in DNS.

            $ClusterAddress = Resolve-DnsNameEx -Name $Name
        }
    }

    End
    {
        $Message = "Exiting Get-ClusterEx for $Name"
        Write-Verbose -Message $Message

        Return $Cluster
    }
}