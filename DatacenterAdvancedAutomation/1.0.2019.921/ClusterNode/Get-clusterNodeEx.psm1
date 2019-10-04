<#
    Create or retreive an existing Cluster Node
    (or a standalone Hyper-V Host server as a perspective Cluster Node).
    
    This is only intended to work in an environment where we alaready have
    Vmm server up and running. In case there's no Vmm yet, we cannot deploy
    Bare-Metal computers, and there's also no need to add already deployed
    servers to Vmm.
#>

Set-StrictMode -Version 'Latest'

Function
Get-clusterNodeEx
{

   #region Data

        [cmdletBinding()]

        Param(

           #region Generic parameters

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
                Mandatory = $True
            )]
            [ValidateScript(
                {
                    $psItem -is [Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerProfile] -or
                    $psItem -is [Microsoft.SystemCenter.VirtualMachineManager.Template]
                }            
            )]
          # [ValidateNotNullOrEmpty()]
          # [Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerProfile]
            $Template
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateSet(
                'Compute'    ,
                'Management' ,
                'Storage'    ,
                'Network'    ,
                'External'   ,
                'Virtual'
            )]
            [System.String]
            $ScaleUnitType
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $SiteName
        ,
          # Node Set Name is only required if there are multiple Node Sets
          # in the same Cluster, i.e. we have a multi-site cluster.

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
            [System.Net.IPAddress]
            $ipAddressManagement
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
            $vmmServer = $RunAsAccount.ServerConnection
        ,
           #endregion Generic parameters

           #region Parameter Set “Virtual”

            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'Virtual'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $ClusterName
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'Virtual'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $DomainAddress
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'Virtual'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $CloudName
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'Virtual'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Owner
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'Virtual'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $NetworkName
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'Virtual'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $PortClassificationName
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'Virtual'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $ShieldingDataName
        ,
           #endregion Parameter Set “Virtual”

           #region Parameter Set “vmHost”

            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'vmHost'
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $bmcAddress
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'vmHost'
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccount
        ,
          # Optional BMC password in case we need to connect directly
          # using BMC management tools in order to obtain additional information
          # such as physical NIC info
            
            [Parameter(
                Mandatory        = $False,
                ParameterSetName = 'vmHost'
            )]
            [ValidateNotNullOrEmpty()]
            [System.Security.SecureString]
            $bmcPassword
        ,
            [Parameter(
                Mandatory        = $True,
                ParameterSetName = 'vmHost'
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccountBMC

           #endregion Parameter Set “vmHost”
        )

   #endregion Data

    Process
    {
        $Message = "  Entering Get-ClusterNodeEx for $Name"
        Write-Debug -Message $Message

        $Module = Import-ModuleEx -Name "FailoverClusters"

      # Perform some validation. We will use the results later
      # when deciding what exaclty we need to provision the computer.

        Switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            'vmHost'
            {            

              # Check whether the Computer exists in Active Directory Domain Services
              # (AD DS). This means that the node was deployed already.
      
              # Note that we cannot use “Validate Computer” syntax for
              # “Find-scComputer”, i.e. pass the “-ComputerName” parameter
              # because it will error in case computer name not found.
              # Instead we're using “Search Computers By Name Filter” syntax,
              # i.e. provide both “-Domain” and “-ComputerNameFilter”.
              # This way we're searching Active Directory instead of 
              # connecting the specified computer directly. And there's
              # no error in case there's no such computer.

                $FindScComputerParam = @{

                    ComputerNameFilter = $Name
                    Domain             = $Template.JoinDomain
                    Credential         = $RunAsAccount
                    vmmServer          = $vmmServer
                }
                $Computer = Find-scComputer @FindScComputerParam
            }

            'Virtual'
            {
                $Message = "Checking if computer `“$Name`” already exists"
                Write-Debug -Message $Message

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain
                )
                {
                    $Message = "Running in the same domain, checking `“$DomainAddress`”"
                    Write-Debug -Message $Message

                    $ComputerParam = @{

                        Identity   = $Name
                        Properties = 'ServicePrincipalNames'
                    }                    
                    $adComputer = Get-adComputer @ComputerParam
                }

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain -and
                    $adComputer.Enabled
                )
                {
                    $Message = "Found enabled computer account, the machine is already deployed"
                    Write-Debug -Message $Message

                    $Computer = $adComputer
                }                
                Else
                {
                    $Message = "Computer account is disabled or running in different domain, checking for existing Virtual Machine"
                    Write-Debug -Message $Message

                    $Computer = Get-scVirtualMachine -Name $Name
                }
            }
        }

        If
        (
            $Computer
        )

      # The node is already deployed and present in AD DS.

        {
            Write-Verbose -Message "Computer found in Active Directory Domain Services (AD DS)"

          # Check whether the Node is already in VMM. Please note that the
          # following step will hang in case there's an active Computer
          # object in AD, but no DNS records for it. This is not a normal
          # situation anyway, and we don't handle it specifically.

            $NodeAddress = Resolve-DnsNameEx -Name $Name

            $NodeVmm = @()

          # Obtain all Nodes of the relevant Scale Unit type from Vmm

            $GetNodeParam = @{
                    
                vmmServer = $vmmServer
            }

            Switch
            (
                $ScaleUnitType
            ) 
            { 
                {
                    ( $psItem -eq "Management" ) -or
                    ( $psItem -eq "Compute"    ) -or
                    ( $psItem -eq "Network"    )
                }

              # Get all VM Hosts

                {
                    $NodeVmm = Get-scvmHost @GetNodeParam
                }

                "Storage"

              # Get all Cluster Nodes for existing Scale-Out File Servers.
              # A File server does not exist in Vmm unless it already
              # is a member of Scale-Out File Server Cluster.

                {
                    
                  # Get all Scale-Out File Servers

                    $StorageFileServer = Get-scStorageFileServer @GetNodeParam

                  # Get all nodes of all Scale-Out File Servers

                    $NodeVmm = $StorageFileServer.StorageNodes
                }
            }

          # The names of all Nodes of the given type in Vmm

            If
            (
                $NodeVmm -And
                $NodeAddress -in $NodeVmm.Name
            )

          # The Node already exists in Vmm.
          # We just need to obtain the single object in question.

            {
                Write-Verbose -Message "Node is already in VMM. Skipping deployment."

                $Node = $NodeVmm | Where-Object -FilterScript {

                    $psItem.Name -eq $NodeAddress
                }
            }

            Else

          # The Node is not in Vmm yet.
          # However, it already exists in Active Directory.
          # Thus, we need to add existing Node to Vmm.

            {
                Write-Verbose -Message "The node does not exist in VMM"

                Switch
                (
                    $ScaleUnitType
                ) 
                { 
                    {
                        ( $psItem -eq "Management" ) -or
                        ( $psItem -eq "Compute"    ) -or
                        ( $psItem -eq "Network"    )
                    }

                  # This is currently only applicable to VM Hosts. We can,
                  # potentially, bring an already existing Scale-Out File Server
                  # under management with VMM. However, this scenario is not yet
                  # implemented by this script.

                    {

                      # Obtain target VM Host Group

                        $GetscvmHostGroupExParam = @{

                            vmmServer     = $vmmServer
                            SiteName      = $SiteName
                            ScaleUnitType = $ScaleUnitType
                        }

                        If
                        (
                            $NodeSetName
                        )
                        {
                            $GetscvmHostGroupExParam.Add(
                                'NodeSetName', $NodeSetName
                            )
                        }
                        $vmHostGroup = Get-scvmHostGroupEx @GetscvmHostGroupExParam

                      # Determine whether the node is a cluster member already

                        If
                        (
                            Test-Path -Path "Variable:\Cluster"
                        )
                        {
                            Remove-Variable -Name "Cluster"
                        }

                      # The following command is expected to fail in case
                      # the hosts are not clustered yet. Thus we specify
                      # Error Action and suppress Verbose output.

                        $GetClusterParam = @{

                            Name        = $NodeAddress
                            ErrorAction = "Ignore"
                            Verbose     = $False
                        }
                        $Cluster = Get-Cluster @GetClusterParam

                        If
                        (
                            $Cluster
                        )

                      # Add existing VM Host Cluster

                        {
                            $ClusterName      = $Cluster.Name
                            $ClusterAddress   = Resolve-DnsNameEx -Name $ClusterName
                            $ClusterNode      = Get-ClusterNode -InputObject $Cluster
                            $ClusterNodeCount = $ClusterNode.Count

                            If
                            (
                                $ClusterNodeCount -eq 1
                            )
                            {
                                $ClusterReserve = 0
                            }
                            Else
                            {
                                $ClusterReserve = 1
                            }
                                
                            $AddscvmHostClusterParam = @{

                                Name           = $ClusterAddress
                                Description    = $Description
                                vmHostGroup    = $vmHostGroup
                                ClusterReserve = $ClusterReserve
                                Credential     = $RunAsAccount
                                vmmServer      = $vmmServer
                            }                        
                            $vmHostCluster =
                                Add-scvmHostCluster @AddscvmHostClusterParam

                            $vmHostClusterNode = $vmHostCluster.Nodes

                          # Restart Cluster Nodes

                            If
                            (
                                $ClusterNodeCount -eq 1
                            )

                          # We cannot Disable (put into Maintenance Mode)
                          # the only node in Cluster. Thus, simply reboot.

                            {
                                $Node = $vmHostClusterNode[0]
                                
                                $scvmHostParam = @{
                                
                                    vmHost  = $Node
                                  # Confirm = $False
                                    Force   = $True
                                }                                
                                $Node = Restart-scvmHost @scvmHostParam
                            }
                            Else
                            {
                                $vmHostClusterNode | ForEach-Object -Process {

                                    $NodeCurrent = $psItem

                                    $scvmHostParam = @{
                                    
                                        vmHost  = $NodeCurrent
                                      # Confirm = $False
                                      # Force   = $True
                                    }

                                    $NodeCurrent = Disable-scvmHost @scvmHostParam
                                    $NodeCurrent = Restart-scvmHost @scvmHostParam
                                    $NodeCurrent = Enable-scvmHost  @scvmHostParam
                                }
                            }

                            $Node = Get-scvmHost -ComputerName $NodeAddress
                        }

                        Else

                      # Add existing Stand-Alone Hyper-V Host

                        {
                            $AddscvmHostParam = @{

                                ComputerName = $NodeAddress
                                vmHostGroup  = $vmHostGroup
                                Credential   = $RunAsAccount
                                vmmServer    = $vmmServer
                              # EnableLiveMigration
                              # IsDedicatedToNetworkVirtualizationGateway 
                              # RemoteConnectEnabled
                            }
                            $Node = Add-scvmHost @AddscvmHostParam

                            $scvmHostParam = @{
                                    
                                vmHost  = $Node
                              # Confirm = $False
                              # Force   = $True
                            }

                            $Node = Disable-scvmHost @scvmHostParam
                            $Node = Restart-scvmHost @scvmHostParam
                            $Node = Enable-scvmHost  @scvmHostParam
                        }
                    }

                    {
                        $psItem -in @( 'Storage', 'Virtual' )
                    }

                  # We cannot add an individual File Server by itself.
                  # (Only create a cluster altogether.
                  # This should be handled by Get-ClusterEx).

                    {
                        $Node = $Computer
                    }
                }
            }
        }

        Else

      # The node is not deployed yet.
      # Deploy the Node with Bare-Metal Operating System Deployment

        {
            $Message = 'Computer not found. Preparing to deploy. Building configuration'
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
                        'Storage'
                    )
                }

              # We're deploying a physical computer managed by VMM.
              # Alternatively, we could handle some other provisioning methods,
              # e.g. VM Deployment. Other Switch cases are reserved for that.

                {

                  # Generic steps to prepare Physical Computer Configuration.

                    $PhysicalComputerConfigExParam = @{
     
                        Name            = $Name
                        Description     = $Description
                        SiteName        = $SiteName
                        bmcAddress      = $bmcAddress
      
                      # Not applicable here. Will inherit from Physical Computer Template      
                      # RunAsAccount    = $RunAsAccount

                        RunAsAccountBMC = $RunAsAccountBMC
                        Template        = $Template
                        vmmServer       = $vmmServer
                    }

                    If
                    (
                        $ScaleUnitType -in @(
                        
                            'Management'
                            'Compute'
                            'Network'
                        )
                    )
    
                  # Obtain target VM Host Group    

                    {
                        $GetscvmHostGroupExParam = @{

                            vmmServer     = $vmmServer
                            SiteName      = $SiteName
                            ScaleUnitType = $ScaleUnitType
                        }

                        If
                        (
                            $NodeSetName
                        )
                        {
                            $GetscvmHostGroupExParam.Add(
                                'NodeSetName', $NodeSetName
                            )
                        }

                        $vmHostGroup = Get-scvmHostGroupEx @GetscvmHostGroupExParam

                        $PhysicalComputerConfigExParam.Add(
                            "vmHostGroup", $vmHostGroup
                        )
                    }

                    If
                    (
                        $ipAddressManagement
                    )
                    {
                        $PhysicalComputerConfigExParam.Add(
                            "ipAddressManagement", $ipAddressManagement
                        )
                    }

                    If
                    (
                        $bmcPassword
                    )
                    {
                        $PhysicalComputerConfigExParam.Add(
                            "bmcPassword", $bmcPassword
                        )
                    }

                  # [Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig]
                    
                    $Node = New-scConfigurationEx @PhysicalComputerConfigExParam

                  # $Message = "  Object obtained, name: `“Configuration`”, type: `”$( $Configuration.GetType().FullName )`”"
                  # Write-Verbose -Message $Message

                  # $Message = "  Count: $( @( $Configuration ).Count )"
                  # Write-Verbose -Message $Message

                  # $Configuration | Write-Verbose
                }

                'Virtual'
                {
                    $ClusterAddress = $ClusterName + '.' + $DomainAddress

                    $Node = [System.Collections.Generic.Dictionary[System.String, System.String]]::New()

                    $Node.Add( 'Name'                   , $Name                   )
                    $Node.Add( 'DomainAddress'          , $DomainAddress          )
                    $Node.Add( 'Description'            , $Description            )
                    $Node.Add( 'CloudName'              , $CloudName              )
                    $Node.Add( 'Owner'                  , $Owner                  )
                    $Node.Add( 'TemplateName'           , $Template.Name          )
                    $Node.Add( 'StartAction'            , 'AlwaysAutoTurnOnVM'    )  # other option: TurnOnVMIfRunningWhenVSStopped
                    $Node.Add( 'StopAction'             , 'ShutdownGuestOS'       )  # other option: SaveVM
                    $Node.Add( 'NetworkName'            , $NetworkName            )
                    $Node.Add( 'PortClassificationName' , $PortClassificationName )
                    $Node.Add( 'ShieldingDataName'      , $ShieldingDataName      )
                    $Node.Add( 'AvailabilitySetName'    , $ClusterAddress         )
                }
            }
        }

        $Message = "  Exiting  Get-ClusterNodeEx for $Name, returning $($Node.GetType().FullName)"
        Write-Debug -Message $Message

        Return $Node
    }
}