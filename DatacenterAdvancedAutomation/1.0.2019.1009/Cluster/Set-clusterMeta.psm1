Set-StrictMode -Version 'Latest'

Function
Set-clusterMeta
{
    [cmdletBinding()]
 
    Param(

        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $vmmServerName
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $OpsMgrManagementServerName
 <# ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $VirtualHardDiskName  #>
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $SoftwareRoot = ( Get-Item -Path '..' )
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]
        $SiteProperty
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]
        $OperatingSystemProfile
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]
        $HardwareProfile
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]
        $ClusterProperty
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $ModuleName
    )

    Begin
    {
        If
        (
            $ModuleName            
        )
        {
            $HardwareProfile.Manufacturer | Sort-Object -Unique | ForEach-Object -Process {

                If
                (
                    $ModuleName[ $psItem ]
                )
                {
                    $Message = "Importing $psItem PowerShell module(s). Please respond to any prompts. (They may appear in the background)"
                    Write-Verbose -Message $Message
            
                    $ModulePath = $ModuleName[ $psItem ] | ForEach-Object -Process {

                        [System.IO.Path]::Combine( $SoftwareRoot.FullName, 'PowerShell Modules', $psItem )
                    }

                  # $Module = Import-ModuleEx -Name "$SoftwareRootPath\PowerShell Modules\HPEiLOCmdlets\2.0.0.0\HPEiLOCmdlets.psd1"
                  # $Module = Import-ModuleEx -Name "$SoftwareRootPath\PowerShell Modules\HPEiLOCmdlets"
            
                    [System.Void]( Import-ModuleEx -Name $ModulePath )
                }
            }
        }

      # We assume if VMM server name is not specified, the script is running in
      # pre-VMM mode and hence no VMM objects are available. However, if running
      # in VMM mode we need to load both modules. Otherwise, OpsMgr object types
      # are not available. And in this case, scripts fail to load if the type
      # is specified as parameter, even if the parameter is not used.

        If
        (
            $vmmServerName
        )
        {
            [System.Void]( Import-ModuleEx -Name 'VirtualMachineManager' )
            [System.Void]( Import-ModuleEx -Name 'OperationsManager'     )

            $vmmServer = Get-scvmmServerEx -Name $vmmServerName
        }

        If
        (
            $OpsMgrManagementServerName
        )
        {
            $OpsMgrManagementServerAddress = Resolve-dnsNameEx -Name $OpsMgrManagementServerName
        
            $ConnectionParam = @{

                ComputerName = $OpsMgrManagementServerAddress
                PassThru     = $True
            }
            $OpsMgrConnection = New-scManagementGroupConnection @ConnectionParam
        }
    }

    Process
    {
        $ClusterProperty | ForEach-Object -Process {

            $ClusterPropertyCurrent = $psItem

            Write-Verbose -Message '###'
            Write-Verbose -Message "Set-ClusterEx: Processing cluster `“$( $ClusterPropertyCurrent.Name )`”"
            Write-Verbose -Message '###'

           #region     Variable

                Set-dcaaDescription -Define $ClusterPropertyCurrent -Verbose:$False

                If
                (
                    $ClusterPropertyCurrent[ 'DomainAddress' ]
                )
                {
                    $DomainAddress = $ClusterPropertyCurrent.DomainAddress
                }
                Else
                {
                    $DomainAddress = $env:UserDnsDomain.toLower()
                }

           #endregion  Variable

           #region     Step I.     Obtain individual Cluster Nodes
       
                Write-Verbose -Message '***'
                $Message = 'Step I.     Obtain individual Cluster Nodes'
                Write-Verbose -Message $Message
              # Write-Verbose -Message '***'

                $NodeCluster = @()

              # Check whether we have input data.

                If
                (
                    Test-Path -Path 'variable:\vmmServer'
                )

              # This is advanced scenario which only works
              # in case we already have VMM in place.
            
                {
                    Write-Verbose -Message "Running in VMM mode"

                   #region Obtain the matching Operating System Profile

                        If
                        (
                            $ClusterPropertyCurrent.ScaleUnitType -eq 'Virtual'
                        )
                        {
                            $OperatingSystemProfileCurrent = Get-scGuestOSProfile -Name $ClusterPropertyCurrent.OperatingSystemProfileName

                            $Message = "OS Profile: `“$( $OperatingSystemProfileCurrent.Name )`”"
                        }
                        Else
                        {
                            $OperatingSystemProfileCurrent =

                                $OperatingSystemProfile | Where-Object -FilterScript {

                                    $psItem.ScaleUnitType -eq $ClusterPropertyCurrent.ScaleUnitType
                                }

                            $Message = "OS Profile: `“$( $OperatingSystemProfileCurrent.ScaleUnitType )`”"
                        }
                    
                        Write-Verbose -Message $Message

                        $TemplateParam = @{

                            OperatingSystemProfile    = $OperatingSystemProfileCurrent
                            VirtualHardDiskName       = $ClusterPropertyCurrent.VirtualHardDiskName

                          # For physical clusters we assume there's just one Node Set
                          # as VMM currently does not support stretched clusters.

                            SiteName                  = $ClusterPropertyCurrent.NodeSet[0].SiteName
                            
                            vmmServer                 = $vmmServer
                        }

                   #endregion Obtain the matching Physical Computer OS Profile

                   #region Obtain the matching Hardware Profile

                        Switch
                        (
                            $ClusterPropertyCurrent.ScaleUnitType
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
                                $TemplateRole = 'vmHost'
                            }

                            'Storage'
                            {
                                $TemplateRole = 'FileServer'
                            }

                            'Virtual'
                            {
                                $TemplateRole = 'Virtual'
                            }
                        }

                        Switch
                        (
                            $TemplateRole
                        )
                        {
                            {
                                $psItem -in @( 'vmHost', 'FileServer' )
                            }
                            {
                                $TemplateParam.Add(
                                    'SoftwareRoot', $SoftwareRoot
                                )

                               #region Obtain Run As Accounts

                                  # Obtain Run As Account for Domain Join

                                    If
                                    (
                                        $OperatingSystemProfileCurrent[ "RunAsAccountNameDomainJoin" ]
                                    )
                                    {
                                        $GetScRunAsAccountParam = @{

                                            Name      = $OperatingSystemProfileCurrent.RunAsAccountNameDomainJoin
                                            vmmServer = $vmmServer
                                        }
                                        $RunAsAccountDomainJoin = Get-scRunAsAccount @GetSCRunAsAccountParam

                                        Write-Verbose -Message "  Run As Account for Domain Join/Attach: $RunAsAccountDomainJoin"

                                        $TemplateParam.Add(
                                            'RunAsAccountDomainJoin', $RunAsAccountDomainJoin
                                        )
                                    }                    

                                  # Obtain Run As Account for Host management

                                    If
                                    (
                                        $OperatingSystemProfileCurrent[ "RunAsAccountNameComputerAccess" ]
                                    )
                                    {
                                        $GetScRunAsAccountParam = @{

                                            Name      = $OperatingSystemProfileCurrent.RunAsAccountNameComputerAccess
                                            vmmServer = $vmmServer
                                        }
                                        $RunAsAccountComputerAccess = Get-scRunAsAccount @GetSCRunAsAccountParam

                                        Write-Verbose -Message "  Run As Account for Host Management:    $RunAsAccountComputerAccess"

                                        $TemplateParam.Add(
                                            'RunAsAccountComputerAccess', $RunAsAccountComputerAccess
                                        )
                                    }                    

                                  # Obtain Run As Account for BMC management

                                    If
                                    (
                                        $OperatingSystemProfileCurrent[ "RunAsAccountNameBmc" ]
                                    )
                                    {
                                        $GetScRunAsAccountParam = @{

                                            Name      = $OperatingSystemProfileCurrent.RunAsAccountNameBmc
                                            vmmServer = $vmmServer
                                        }
                                        $RunAsAccountBmc = Get-scRunAsAccount @GetSCRunAsAccountParam

                                        Write-Verbose -Message "  Run As Account for BMC:                $RunAsAccountBmc"

                                        $TemplateParam.Add(
                                            'RunAsAccountBmc', $RunAsAccountBmc
                                        )
                                    }                    

                                  # Obtain Run As Account for Local Administrator

                                    If
                                    (
                                        $OperatingSystemProfileCurrent[ "RunAsAccountNameLocal" ]
                                    )
                                    {
                                        $GetScRunAsAccountParam = @{

                                            Name      = $OperatingSystemProfileCurrent.RunAsAccountNameLocal
                                            vmmServer = $vmmServer
                                        }
                                        $RunAsAccountLocal = Get-scRunAsAccount @GetScRunAsAccountParam

                                        Write-Verbose -Message "  Run As Account for Local Admin:        $RunAsAccountLocal"

                                        $TemplateParam.Add(
                                            'RunAsAccountLocal', $RunAsAccountLocal
                                        )
                                    }                    

                                  # Obtain Run As Account for Cluster Build

                                    If
                                    (
                                        $OperatingSystemProfileCurrent[ "RunAsAccountNameBuild" ]
                                    )
                                    {
                                        $GetScRunAsAccountParam = @{

                                            Name      = $OperatingSystemProfileCurrent.RunAsAccountNameBuild
                                            vmmServer = $vmmServer
                                        }
                                        $RunAsAccountBuild = Get-scRunAsAccount @GetScRunAsAccountParam

                                        Write-Verbose -Message "  Run As Account for building Cluster:   $RunAsAccountBuild"
                                    }                    

                               #endregion Obtain Run As Accounts
                       
                              # Obtain the Physical Computer properties from the first Cluster
                              # Node. The assumption is that every node in a given Cluster
                              # is the same.
                    
                                $Message = "Looking for a matching Physical Computer Hardware Profile, based on the hardware of the first node"
                                Write-Verbose -Message $Message

                                $NodeCurrentProperty = $ClusterPropertyCurrent.NodeSet[0].Node[0]

                              # Quick Discovery — “Discover baseboard management controler”
                              # to obtain Server's Manufacturer and Model.

                                $BmcAddress = Resolve-DnsNameEx -Name $NodeCurrentProperty.BmcAddress
    
                                $FindScComputerExParam = @{

                                    BmcAddress      = $BmcAddress
                                    RunAsAccountBmc = $RunAsAccountBmc
                                    vmmServer       = $vmmServer
                                }
                                $Computer = Find-scComputerEx @FindScComputerExParam 

                                $TemplateParam.Add(
                                    'Computer', $Computer
                                )

                                $HardwareProfileCurrent = 
                                    $HardwareProfile | 
                                        Where-Object -FilterScript {
                
                                            (
                                                $psItem.Role -eq $TemplateRole
                                            ) -And                
                                            (
                                                $psItem.Manufacturer -eq $Computer.Manufacturer
                                            ) -And
                                            (
                                                $psItem.Model -eq $Computer.Model
                                            )
                                        }

                                $Message = "Hardware Profile: `“$($HardwareProfileCurrent.Manufacturer) $($HardwareProfileCurrent.Model)`”"
                            }

                            'Virtual'
                            {
                                $TemplateParam.Add(
                                    'InstallationOptionName',   'Core'
                                )

                                $StorageClassification = Get-scStorageClassification -Name $ClusterPropertyCurrent.StorageClassificationName

                                $TemplateParam.Add(
                                    'StorageClassification', $StorageClassification
                                )

                                $HardwareProfileCurrent = Get-scHardwareProfile | Where-Object -FilterScript {

                                    $psItem.Name -eq $ClusterPropertyCurrent.HardwareProfileName
                                }

                                $Message = "Hardware Profile: `“$( $HardwareProfileCurrent.Name )`”"
                            }

                            Default
                            {
                                $Message = 'No Hardware Profile specified'
                            }
                        }

                        $TemplateParam.Add(
                            'HardwareProfile',     $HardwareProfileCurrent
                        )
                    
                        Write-Verbose -Message $Message

                   #endregion Obtain the matching Physical Computer Hardware Profile

                   #region Obtain the matching Template

                        If
                        (
                            $ClusterPropertyCurrent[ 'NodeSet' ][0][ 'Name' ]
                        )
                        {
                            $TemplateParam.Add( 'NodeSetName', $ClusterPropertyCurrent.NodeSet[0].Name )
                        }

                        $Template = Get-scTemplateEx @TemplateParam

                   #endregion Obtain the matching Physical Computer Template

                   #region Loop through Node Sets and obtain all nodes in Cluster

                    $ClusterPropertyCurrent.NodeSet | ForEach-Object -Process {

                        $ClusterPropertyNodeSetCurrent = $psItem

                      # Loop through Cluster Nodes in Node Set
               
                        $ClusterPropertyNodeSetCurrent.Node | ForEach-Object -Process {

                            $ClusterPropertyNodeSetNodeCurrent = $psItem

                            $Message = @(

                                "***"
                                "Obtaining Cluster Node `“$($ClusterPropertyNodeSetNodeCurrent.Name)`”"
                              # "***"
                            )
                            $Message | ForEach-Object -Process { Write-Verbose -Message $psItem }

                          # Define some variables

                            Set-dcaaDescription -Define $ClusterPropertyNodeSetNodeCurrent                        

                            $NodeParam = @{

                                Name          = $ClusterPropertyNodeSetNodeCurrent.Name
                                Description   = $ClusterPropertyNodeSetNodeCurrent.Description
                                ScaleUnitType = $ClusterPropertyCurrent.ScaleUnitType                            
                                SiteName      = $ClusterPropertyNodeSetCurrent.SiteName
                                Template      = $Template
                                vmmServer     = $vmmServer
                            }

                            Switch
                            (
                                $TemplateRole
                            )
                            {
                                'vmHost'
                                {
                                    $BmcAddress = Resolve-DnsNameEx -Name $ClusterPropertyNodeSetNodeCurrent.BmcAddress

                                    $NodeParam.Add(
                                        'BmcAddress',
                                        $BmcAddress
                                    )

                                    $NodeParam.Add(
                                        'RunAsAccount',
                                        $RunAsAccountComputerAccess
                                    )

                                    $NodeParam.Add(
                                        'RunAsAccountBmc',
                                        $RunAsAccountBmc
                                    )

                                    If
                                    (
                                        $OperatingSystemProfileCurrent[ 'RunAsAccountBmcPassword' ]
                                    )
                                    {
                                        $SecureStringParam = @{
                            
                                            String      = $OperatingSystemProfileCurrent.RunAsAccountBmcPassword
                                            AsPlainText = $True
                                            Force       = $True
                                        }
                                        $bmcPassword = ConvertTo-SecureString @SecureStringParam
                        
                                        $NodeParam.Add(
                                            'bmcPassword',
                                            $bmcPassword
                                        )
                                    }

                                 <# If
                                    (
                                        $HardwareProfileCurrent[ 'appliancePassword' ]
                                    )
                                    {
                                        $SecureStringParam = @{
                            
                                            String      = $HardwareProfileCurrent.appliancePassword
                                            AsPlainText = $True
                                            Force       = $True
                                        }
                                        $appliancePassword = ConvertTo-SecureString @SecureStringParam
                                    }  #>
                                }

                                'Virtual'
                                {
                                    $NodeParam.Add(
                                        'ClusterName',
                                        $ClusterPropertyCurrent.Name
                                    )

                                    $NodeParam.Add(
                                        'DomainAddress',
                                        $DomainAddress
                                    )

                                    $NodeParam.Add(
                                        'CloudName',
                                        $ClusterPropertyNodeSetCurrent.CloudName
                                    )

                                    $NodeParam.Add(
                                        'Owner',
                                        $ClusterPropertyCurrent.Owner
                                    )

                                    $NodeParam.Add(
                                        'NetworkName',
                                        $ClusterPropertyCurrent.NetworkName
                                    )

                                    $NodeParam.Add(
                                        'PortClassificationName',
                                        $ClusterPropertyCurrent.PortClassificationName
                                    )

                                    $NodeParam.Add(
                                        'ShieldingDataName',
                                        $ClusterPropertyCurrent.ShieldingDataName
                                    )
                                }
                            }

                            If
                            (
                                $ClusterPropertyNodeSetCurrent[ 'Name' ]
                            )
                            {
                                $NodeParam.Add(
                                    'NodeSetName',
                                    $ClusterPropertyNodeSetCurrent.Name
                                )
                            }

                            If
                            (
                                $ClusterPropertyNodeSetNodeCurrent[ 'ipAddress' ] 
                            )
                            {
                                $NodeParam.Add(
                                    'ipAddressManagement',
                                    [System.Net.ipAddress]$ClusterPropertyNodeSetNodeCurrent.ipAddress
                                )
                            }

                            $NodeCluster += Get-clusterNodeEx @NodeParam
                        }
                    }

                    Write-Verbose -Message "***"

                   #endregion Loop through Node Sets and obtain all nodes in Cluster

                }

                Else

              # There's no VMM server yet. Thus, no settings to define and
              # nothng to provision. We assume the Node is already deployed
              # somehow. However, we need to obtain it.
              # (This code should be added later).

                {
                    Write-Verbose -Message "Running in pre-VMM environment"
                }

           #endregion  Step I.     Obtain individual Cluster Nodes

           #region     Step II.    Deploy Cluster Nodes
       
                Write-Verbose -Message '***'
                $Message = 'Step II.    Deploy Cluster Nodes'
                Write-Verbose -Message $Message
              # Write-Verbose -Message '***'

             <# If
                (
                    Test-Path -Path 'Variable:\Node'
                )
                {
                    Remove-Variable -Name $Node
                }  #>

                $NodeParam = @{

                    Node = $NodeCluster
                }

                If
                (
                    Test-Path -Path 'Variable:\vmmServer'
                )
                {
                    $NodeParam.Add( 'vmmServer', $vmmServer )
                }

                $NodeCluster = Get-clusterNodeJob @NodeParam

           #endregion  Step II.    Deploy Cluster Nodes

           #region     Step III.   Build parameters to create the cluster

                Write-Verbose -Message '***'
                $Message = 'Step III.   Build parameters to create the cluster'
                Write-Verbose -Message $Message

              # OS Configuration only works for machines in the same domain

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {
                    $Message = @(

                        "***"
                        "Obtaining Cluster `“$($ClusterPropertyCurrent.Name)`”"
                        "***"
                    )
                  # $Message | ForEach-Object -Process { Write-Verbose -Message $psItem }
           
                    Set-dcaaDescription -Define $ClusterPropertyCurrent

                  # The following properties are common across any Scale Unit Type

                    $ClusterParam = @{
            
                        Name                  = $ClusterPropertyCurrent.Name
                        Description           = $ClusterPropertyCurrent.Description
                        Node                  = $NodeCluster
                        ScaleUnitType         = $ClusterPropertyCurrent.ScaleUnitType                        
                    }

                    If
                    (
                        $ClusterPropertyCurrent.Contains( 'ipAddress' )
                    )
                    {
                        $ipAddressString = $ClusterPropertyCurrent.ipAddress
                        $ipAddress       = [System.Net.ipAddress]$ipAddressString
                
                        $ClusterParam.Add(
                            'ipAddress',
                            $ipAddress
                        )
                    }

                  # The following properties are only present for specific Scale Unit
                  # Types.

                    Switch
                    (
                        $ClusterPropertyCurrent.ScaleUnitType
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
                          # Management Network Name can only be specified for the clusters
                          # consisting of Physical Machines deployed with VMM—that is, 
                          # when Template was an object of “Phyisical Computer Profile”
                          # type, and hence it was defined with a custom “Hardware Profile”
                          # which was actually a hashtable.
                  
                          # For clusters consisting of Virtual Machines, we do not use 
                          # VMM to build the cluster, and hence do not need to validate 
                          # the IP address in advance (and this validation is the 
                          # purpose of “Management Network Name” paramemter.)

                          # Node Set name is used only for temorarily granting IP address
                          # This is only done for VM Host clusters, and such clusters
                          # never span across locations. (All cluster nodes are located
                          # at the same place.) Hence, there's only one Node Set.

                            $NetworkAdapterProfileManagement = 
                                $HardwareProfileCurrent.NetworkAdapterGroupProperty.StaticipAddressProperty | 
                                    Where-Object -FilterScript { $psItem[ 'TransferipAddress' ] }

                            $ClusterParam.Add(
                                'ManagementNetworkName',
                                 $NetworkAdapterProfileManagement.NetworkName
                            )

                            If
                            (
                                $ClusterPropertyCurrent.NodeSet[0][ 'Name' ]
                            )
                            {
                                $ClusterParam.Add(
                                    'NodeSetName',
                                    $ClusterPropertyCurrent.NodeSet[0].Name
                                )
                            }

                            If
                            (
                                $OperatingSystemProfileCurrent.Contains( 'RunAsAccountNameBuild' )
                            )
                            {
                                $GetSCRunAsAccountParam = @{

                                    Name      = $OperatingSystemProfileCurrent.RunAsAccountNameBuild
                                    vmmServer = $vmmServer
                                }
                                $RunAsAccountBuild = Get-scRunAsAccount @GetSCRunAsAccountParam
                                
                                $ClusterParam.Add(
                                    'RunAsAccount',
                                    $RunAsAccountBuild
                                )
                            }

                         <# If
                            (
                                $ClusterPropertyCurrent.StorageType -eq "S2D"
                            )
                            {
                                $ClusterParam.Add(
                                    "EnableS2D", $True
                                )
                            }  #>
                        }

                        'Storage'
                        {
                            $FileServerName = $ClusterPropertyCurrent.NodeSet[0].Role.Name

                            $ClusterParam.Add(
                                'FileServerName',
                                $FileServerName
                            )

                          # File Servers are not normally associated with any Host Group,
                          # thus we need to explicitly specify Site Name in order
                          # to allocate IP Address from the correct Static IP Address Pool.

                            $ClusterParam.Add(
                                'SiteName',
                                $ClusterPropertyCurrent.NodeSet[0].SiteName
                            )
                        }
                    }                    
                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Cluster creation'
                    Write-Verbose -Message $Message
                }

           #endregion  Step III.   Build parameters to create the cluster later

           #region     Step IV.    Obtain the cluster—only for Scale-out File Server (SoFS)
            
                Write-Verbose -Message '***'
                $Message = 'Step IV.    Obtain the cluster—only for Scale-out File Server (SoFS)'
                Write-Verbose -Message $Message

              # OS Configuration only works for machines in the same domain

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {
                    Switch
                    (
                        $NodeCluster[0].GetType().FullName
                    )
                    {
                        {
                            $psItem -in @(

                                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                'Microsoft.SystemCenter.VirtualMachineManager.VM'
                                'Microsoft.ActiveDirectory.Management.adComputer'
                              # 'System.String'
                            )
                        }
                        {
                            $Message = 'The cluster will be created at Step VI after individual nodes are configured. Nothing to do at this step'
                            Write-Verbose -Message $Message
                        }

                        'Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig'
                        {
                            $Cluster = Get-clusterEx @ClusterParam
                        }

                        Default
                        {
                            $Message = "Unexpected Node object type `“$( $NodeCluster[0].GetType().FullName )`”"
                            Write-Warning -Message $Message
                        }
                    }
                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Cluster creation'
                    Write-Verbose -Message $Message
                }

           #endregion  Step IV.    Obtain the cluster—only for Scale-out File Server (SoFS)
           
           #region     Step V.     Configure individual Cluster Nodes
       
                Write-Verbose -Message '***'
                $Message = 'Step V.     Configure individual Cluster Nodes'
                Write-Verbose -Message $Message

             <# OS Configuration only works for machines in the same domain.

                This is applicable for all types of cluster nodes—i.e. Hyper-V
                hosts in VMM as well as generic future cluster nodes (typically VMs)
                currently represented as address strings (because there's no cluster
                yet.)

                The only exception is perspective Storage server (SoFS) cluster nodes
                because they are not yet deployed at this point.  #>

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {

                  # We need to run this after cluster was actually created
                  # because for File Server, the nodes actually get deployed
                  # only when the cluster is being created. And before that,
                  # the nodes do not actually exist.

                    $NodeCluster | ForEach-Object -Process {

                        $NodeCurrent = $psItem

                        Switch
                        (
                            $NodeCurrent.GetType().FullName
                        )
                        {
                          # Prepare name

                            {
                                $psItem -in @(

                                    'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                    'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                    'Microsoft.SystemCenter.VirtualMachineManager.VM'
                                    'Microsoft.ActiveDirectory.Management.adComputer'
                                )
                            }
                            {
                                $NodeAddress = $NodeCurrent.Name
                            }

                            'System.String'
                            {
                                $NodeAddress = $NodeCurrent
                            }

                          # Build the properties

                            {
                                $True
                            }
                            {
                              # To obtain properties like Description, we need to fetch the
                              # original Node properties in Cluster Properties.

                                $NodeCurrentName = $NodeAddress.Split( '.' )[0]
                
                                $NodeCurrentProperty = $ClusterPropertyCurrent.NodeSet.Node |
                                    Where-Object -FilterScript {

                                        $psItem.Name -eq $NodeCurrentName
                                    }

                                $NodeSetCurrent = $ClusterPropertyCurrent.NodeSet |
                                    Where-Object -FilterScript { $NodeCurrentProperty -in $psItem.Node }

                                $SitePropertyCurrent = $SiteProperty |
                                    Where-Object -FilterScript { $psItem.Name -eq $NodeSetCurrent.SiteName }

                                $NodeParam = @{

                                    Node          = @( $NodeCurrent )
                                    Description   = $NodeCurrentProperty.Description
                                    ScaleUnitType = $ClusterPropertyCurrent.ScaleUnitType
                                  # SiteProperty  = $SitePropertyCurrent
                                  # vmmServer     = $vmmServer
                                }

                             <# If
                                (
                                    $HardwareProfileCurrent
                                )
                                {
                                    $NodeParam.Add(
                                        "HardwareProfile",
                                        $HardwareProfileCurrent
                                    )
                                }

                                If
                                (
                                    $NodeSetCurrent
                                )
                                {
                                    $NodeParam.Add(
                                        "NodeSetName", $NodeSetCurrent.Name
                                    )
                                }  #>
                            }

                            'Microsoft.SystemCenter.VirtualMachineManager.Host'
                            {
                                If
                                (
                                    $HardwareProfileCurrent[ 'appliancePassword' ]
                                )
                                {
                                    $SecureStringParam = @{
                            
                                        String      = $HardwareProfileCurrent.appliancePassword
                                        AsPlainText = $True
                                        Force       = $True
                                    }
                                    $appliancePassword = ConvertTo-SecureString @SecureStringParam

                                    $CredentialArgument = @(

                                        $HardwareProfileCurrent.applianceUserName
                                        $appliancePassword
                                    )

                                    $CredentialParam = @{

                                        TypeName     = 'System.Management.Automation.PSCredential'
                                        ArgumentList = $CredentialArgument
                                    }
                                    $applianceCredential = New-Object @CredentialParam

                                 <# $NodeParam.Add(
                                        'applianceAddress',
                                        $applianceAddress    
                                    )  #>

                                    $NodeParam.Add(
                                        'applianceCredential',
                                        $applianceCredential
                                    )
                                }

                                If
                                (
                                    $OperatingSystemProfileCurrent[ 'Guarded' ]
                                )
                                {
                                    $NodeParam.Add(
                                        'Guarded',
                                        $OperatingSystemProfileCurrent.Guarded
                                    )

                                    $NodeParam.Add(
                                        'HgsUriScheme',
                                        $OperatingSystemProfileCurrent.HgsUriScheme
                                    )

                                    $NodeParam.Add(
                                        'MemoryDumpEncryptionCertificateThumbPrint',
                                        $OperatingSystemProfile.ThumbPrint
                                    )

                                    $NodeParam.Add(
                                        'MemoryDumpEncryptionCertificatePublicKey',
                                        $OperatingSystemProfile.PublicKey
                                    )
                                }

                                If
                                (
                                    $RunAsAccountBmc
                                )
                                {
                                    $BmcAddress = Resolve-DnsNameEx -Name $NodeCurrentProperty.BmcAddress
                                    
                                    $NodeParam.Add(
                                        'BmcAddress',
                                        $BmcAddress
                                    )

                                    $NodeParam.Add(
                                        'RunAsAccountBmc',
                                        $RunAsAccountBmc
                                    )
                                }

                                If
                                (
                                    $OpsMgrManagementServerName
                                )
                                {
                                    $NodeParam.Add(
                                        'OpsMgrConnection',
                                        $OpsMgrConnection
                                    )
                                }
                            }

                            Default
                            {
                                $Message = "Unexpected node type: `“$psItem`”"
                                Write-Verbose -Message $Message
                            }
                        }

                        Set-clusterNodeEx @NodeParam
                    }
                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Cluster node configuration'
                    Write-Verbose -Message $Message
                }

           #endregion  Step V.     Configure individual Cluster Nodes

           #region     Step VI.    Configure individual Cluster Nodes networking
       
                Write-Verbose -Message '***'
                $Message = 'Step VI.    Configure individual Cluster Nodes networking'
                Write-Verbose -Message $Message

              # OS Configuration only works for machines in the same domain.

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {
                    $NodeCluster | ForEach-Object -Process {

                        $NodeCurrent = $psItem

                        Switch
                        (
                            $NodeCurrent.GetType().FullName
                        )
                        {
                          # Prepare name

                            {
                                $psItem -in @(

                                    'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                    'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                                    'Microsoft.SystemCenter.VirtualMachineManager.VM'
                                    'Microsoft.ActiveDirectory.Management.adComputer'
                                )
                            }
                            {
                                $NodeAddress = $NodeCurrent.Name
                            }

                            'System.String'                            
                            {
                                $NodeAddress = $NodeCurrent
                            }

                          # Build the properties

                            {
                                $True
                            }
                            {
                              # To obtain properties like Description, we need to fetch the
                              # original Node properties in Cluster Properties.

                                $NodeCurrentName = $NodeAddress.Split( '.' )[0]
                
                                $NodeCurrentProperty = $ClusterPropertyCurrent.NodeSet.Node |
                                    Where-Object -FilterScript {

                                        $psItem.Name -eq $NodeCurrentName
                                    }

                                $NodeSetCurrent = $ClusterPropertyCurrent.NodeSet |
                                    Where-Object -FilterScript { $NodeCurrentProperty -in $psItem.Node }

                                $SitePropertyCurrent = $SiteProperty |
                                    Where-Object -FilterScript { $psItem.Name -eq $NodeSetCurrent.SiteName }

                                $AdapterParam = @{

                                    Node                        = @( $NodeCurrent )
                                    SiteName                    = $SitePropertyCurrent.Name
                                }

                                If
                                (
                                    $HardwareProfileCurrent -is [System.Collections.Hashtable]
                                )
                                {
                                    $AdapterParam.Add(
                                        'NetworkAdapterGroupProperty',
                                        $HardwareProfileCurrent.NetworkAdapterGroupProperty
                                    )
                                }

                                If
                                (
                                    $NodeSetCurrent[ 'Name' ]
                                )
                                {
                                    $AdapterParam.Add(
                                        'NodeSetName',
                                        $NodeSetCurrent.Name
                                    )
                                }

                                If
                                (
                                    $OperatingSystemProfileCurrent -is [System.Collections.Hashtable] -and
                                    $OperatingSystemProfileCurrent[ 'RunAsAccountBmcPassword' ]
                                )
                                {
                                    $SecureStringParam = @{
                            
                                        String      = $OperatingSystemProfileCurrent.RunAsAccountBmcPassword
                                        AsPlainText = $True
                                        Force       = $True
                                    }
                                    $bmcPassword = ConvertTo-SecureString @SecureStringParam
                        
                                    $AdapterParam.Add(
                                        'bmcPassword',
                                        $bmcPassword
                                    )
                                }                                
                            }

                            Default
                            {
                                $Message = "Unexpected node type: `“$psItem`”"
                                Write-Verbose -Message $Message
                            }
                        }

                        Set-netAdapterEx @AdapterParam
                    }

                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Cluster node network configuration'
                    Write-Verbose -Message $Message
                }

           #endregion  Step VI.    Configure individual Cluster Nodes networking

           #region     Step VII.   Obtain Cluster or add Nodes—except for Scale-out File Server (SoFS)

                Write-Verbose -Message '***'
                $Message = 'Step VII.   Obtain Cluster or add Nodes'
                Write-Verbose -Message $Message

              # OS Configuration only works for machines in the same domain

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {
                    Switch
                    (
                        $NodeCluster[0].GetType().FullName
                    )
                    {
                        {
                            $psItem -in @(

                                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                'Microsoft.SystemCenter.VirtualMachineManager.VM'
                                'Microsoft.ActiveDirectory.Management.adComputer'
                                'System.String'
                            )
                        }
                        {
                            $Cluster = Get-clusterEx @ClusterParam
                        }

                        'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServerNode'
                        {
                            $Message = 'This is a Scale-out File Server (SoFS) cluster. It was already created at Step III. Nothing to do at this step'
                            Write-Verbose -Message $Message
                        }

                        Default
                        {
                            $Message = "Unexpected Node object type `“$( $NodeCluster[0].GetType().FullName )`”"
                            Write-Warning -Message $Message
                        }
                    }
                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Cluster creation'
                    Write-Verbose -Message $Message
                }

           #endregion  Step VII.   Obtain Cluster or add Nodes—except for Scale-out File Server (SoFS)

           #region     Step VIII.  Configure Cluster

                Write-Verbose -Message '***'
                $Message = 'Step VIII.  Configure Cluster'
                Write-Verbose -Message $Message

              # OS Configuration only works for machines in the same domain

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {
                    $ClusterParam = @{
                
                        Cluster      = $Cluster
                        Description  = $ClusterPropertyCurrent.Description
                    }

                    Switch
                    (
                        $ClusterPropertyCurrent.ScaleUnitType
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
                            $ClusterParam.Add(                
                                'csvCacheSize',
                                $HardwareProfileCurrent.csvCacheSize
                            )

                            $ClusterParam.Add(
                                'Reserve',
                                2
                            )

                            $ClusterParam.Add(
                                'RunAsAccount',
                                $RunAsAccountComputerAccess
                            )
                        }

                        'Virtual'
                        {
                            $ClusterParam.Add(
                                'NodeSet',
                                $ClusterPropertyCurrent.NodeSet
                            )
                        }
                    }

                    $Cluster = Set-clusterEx @ClusterParam
                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Cluster configuration'
                    Write-Verbose -Message $Message
                }

           #endregion  Step VIII.  Configure Cluster

           #region     Step IX.    Configure Cluster Storage (Provision Physical Disks and setup Cluster Disks)

                Write-Verbose -Message '***'
                $Message = 'Step IX.    Configure Cluster Storage'
                Write-Verbose -Message $Message

                If
                (
                    Test-Path -Path 'Variable:\Cluster'
                )
                {
                    $Message = $Cluster.Name
                }
                Else
                {
                    $Cluster = $ClusterPropertyCurrent.Name + '.' + $DomainAddress

                    $Message = "Cluster is not defined. Will atempt to just provision storage for `“$Cluster`”"                
                }

                Write-Verbose -Message $Message

                $ClusterDiskParam = @{
                
                    Cluster       = $Cluster

                  # Pass the cluster nodes (potentially as VMs) in case the cluster
                  # is Cluster Management object or String
                  # Node          = $NodeCluster
                  # SiteName      = $ClusterPropertyCurrent.NodeSet[0].SiteName
                    NodeSet       = $ClusterPropertyCurrent.NodeSet
                    StorageType   = $ClusterPropertyCurrent.StorageType
                }

                If
                (
                    $vmmServer
                )
                {
                    $ClusterDiskParam.Add( 'vmmServer', $vmmServer )
                }

                If
                (
                    $ClusterPropertyCurrent[ 'FileShareName' ]
                )
                {
                    $ClusterDiskParam.Add(
                        'FileShareName', $ClusterPropertyCurrent.FileShareName
                    )
                }

                If
                (
                    $ClusterPropertyCurrent[ 'FileShareWitness' ]
                )
                {
                    $ClusterDiskParam.Add(
                        'FileShareWitness', $ClusterPropertyCurrent.FileShareWitness
                    )
                }

                Set-clusterDiskEx @ClusterDiskParam

           #endregion  Step IX.    Configure Cluster Storage (Provision Physical Disks and setup Cluster Disks)

           #region     Step X.     Configure Cluster Networking
            
                Write-Verbose -Message '***'
                $Message = 'Step X.     Configure Cluster Networking'
                Write-Verbose -Message $Message

              # Network Configuration only works for machines in the same domain

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {
                    If
                    (
                        $ClusterPropertyCurrent.NodeSet[0].SiteName
                    )
                    {
                     <# $SitePropertyCurrent = $SiteProperty | Where-Object -FilterScript {
                            $psItem.Name -eq $ClusterPropertyCurrent.NodeSet[0].SiteName
                        }  #>

                        $SetClusterNetworkExParam = @{
        
                            Cluster             = $Cluster
                          # ClusterNetworkParam = $SitePropertyCurrent.ClusterNetworkParam
                            SiteProperty        = $SiteProperty
                        }
                        Set-clusterNetworkEx @SetClusterNetworkExParam
                    }

                    If
                    (
                        $ClusterPropertyCurrent[ 'BrokerName' ]
                    )
                    {
                      # Enable Hyper-V Replica Broker
                      # This should be done after volumes are created

                        $ClusterCurrent = Get-Cluster -Name $Cluster.Name

                        $ReplicationServerParam = @{
                
                            Cluster   = $ClusterCurrent
                            Name      = $ClusterPropertyCurrent.BrokerName
                            ipAddress = $ClusterPropertyCurrent.BrokeripAddress                
                        }
                        Set-vmReplicationServerEx @ReplicationServerParam
                    }
                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Network configuration'
                    Write-Verbose -Message $Message
                }

           #endregion  Step X.     Configure Cluster Networking

           #region     Step XI.    Validation

                Write-Verbose -Message '***'
                $Message = 'Step XI.    Validation'
                Write-Verbose -Message $Message

              # Network Configuration only works for machines in the same domain

                If
                (
                    $DomainAddress -eq $env:UserDnsDomain.toLower()
                )
                {
                    Test-ClusterEx -Cluster $Cluster
                }
                Else
                {
                    $Message = 'The nodes are in a different domain. Skipping Cluster validation'
                    Write-Verbose -Message $Message
                }

           #endregion  Step XI.    Validation

            Write-Verbose -Message "###"
            Write-Verbose -Message "Set-ClusterEx: completed cluster $($ClusterPropertyCurrent.Name)"
            Write-Verbose -Message "###"

            Remove-Variable -Name 'Cluster'
        }
    }

    End
    {}
}