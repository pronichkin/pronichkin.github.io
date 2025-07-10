Set-StrictMode -Version 'Latest'

Function
New-netFirewallRuleEx
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.String]]
        $Name = ( HostName )
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'SQL Server'
        )]
        [System.String]
        $Role

    )

    Begin
    {
      # $Module = Import-ModuleEx -Name "${env:ProgramFiles(x86)}\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\SQLPS.PSD1"
      # $Module = Import-ModuleEx -Name "${env:ProgramFiles(x86)}\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\SQLPS.PSD1"
      # $Module = Import-ModuleEx -Name "$env:userprofile\Downloads\SqlServer\21.0.17199\SqlServer.psd1"
      # $Module = Import-ModuleEx -Name "SqlServer"

        $ModuleName = @(		
		    
		    'NetSecurity'
            'NetTCPIP'
		    'FailoverClusters'
		)

        If
        (
            $Role -eq 'SQL Server'
        )
        {
            $ModuleName += 'SqlServer'            
        }

		[System.Void]( Import-ModuleEx -Name $ModuleName )
    }

    Process
    {
        $Name | ForEach-Object -Process {

            Write-Verbose -Message '***'
            $Message = "Configuring Firewall Rule(s) for `“$psItem`”"
            Write-Verbose -Message $Message

            $Cluster = Test-clusterNodeEx -Name $psItem

            If
            (
                $Cluster
            )
     
          # We are dealing with clustered services. They migh have multiple nodes,
          # and each service has its own set of addresses (Host names
          # and IP addresses).

            {
              # $ClusterAddress     = Resolve-DnsNameEx -Name $psItem
              # $Cluster            = Get-Cluster -Name $ClusterAddress
                $ClusterResource    = Get-ClusterResource -InputObject $Cluster

                $ClusterResourceSqlServer = $ClusterResource |
                    Where-Object -FilterScript {
                        $psItem.ResourceType -eq 'SQL Server' -or
                        (
                            $psItem.ResourceType -eq 'Generic Service' -and
                            $psItem.Name -notlike '*CEIP*'
                        )
                    }

                $ClusterNode        = Get-ClusterNode -InputObject $Cluster
                $ClusterNodeAddress = Resolve-DnsNameEx -Name $ClusterNode.Name
                $Session            = New-cimSessionEx -Name $ClusterNodeAddress

              # Firewall Rules for Non-Clustered Services
              # Such as SQL Server Browser and Windows Management Instrumentation.

                $ClusterNodeAddress | ForEach-Object -Process {

                    $ClusterNodeAddressCurrent = $psItem

                    Write-Verbose -Message '***'
                    $Message = "Non-Clustered Services on Cluster Node `“$ClusterNodeAddressCurrent`”"
                    Write-Verbose -Message $Message

                    $SessionCurrent = $Session | Where-Object -FilterScript {
                        $psItem.ComputerName -eq $ClusterNodeAddressCurrent
                    }

                    $Rule = Get-netFirewallRule -CimSession $SessionCurrent

                  # The Browser service is not actually required since we're making
                  # all instances to listen on default port (1433). We still create
                  # the Firewall rule just in case, but make it disabled

                    $RuleName = 'SQL Server Browser'

                    If
                    (
                        $Rule | Where-Object -FilterScript { $psItem.DisplayName -eq $RuleName }
                    )
                    {
                        $Message = "Firewall Rule for `“$RuleName`” already exists on $psItem"                    
                        Write-Verbose -Message $Message
                    }
                    Else
                    {
                        $Message = "Creating Firewall rule for `“$RuleName`” on $psItem"
                        Write-Verbose -Message $Message
                    
                        $RuleParam  = @{

                            DisplayName  = $RuleName
                            Description  = 'Provides SQL Server connection information to client computers'
                            Service      = 'SqlBrowser'
                            Program      = 'C:\Program Files (x86)\Microsoft SQL Server\90\Shared\sqlbrowser.exe'
                            LocalPort    =  1434
                            Enabled      = 'False'
                            Profile      = 'Domain'
	                        Direction    = 'Inbound'
	                        Action       = 'Allow'
	                        Protocol     = 'UDP'
                            Group        = 'SQL Server'
                            cimSession   = $SessionCurrent
                        }
                        [System.Void]( New-netFirewallRule @RuleParam )
                    }

                  # Enable default Firewall Rules for Windows Management
                  # Instrumentation (WMI). This is required for SQL Server
                  # Configuration Manager and obtaining management objects
                  # later in this script.

                    $RuleParam = @{

                        DisplayGroup = 'Windows Management Instrumentation (WMI)'
                        cimSession   = $SessionCurrent
                    }
                    [System.Void]( Enable-netFirewallRule @RuleParam )

                  # Create a temporary rule which allows remote connection to SQL
                  # Server without additional qualifications. This is required to
                  # obtain detailed information about instances so that we can build
                  # more specific rules for permanent use.

                    $RuleName = 'SQL Server — Temporary'

                    If
                    (
                        $Rule | Where-Object -FilterScript { $psItem.DisplayName -eq $RuleName }
                    )
                    {
                        $Message = "Firewall Rule for `“$RuleName`” already exists on $psItem"                    
                        Write-Verbose -Message $Message
                    }
                    Else
                    {
                        $ipAddressLocal        = Get-netIPAddress -AddressFamily IPv4 -Type Unicast -CimSession $SessionCurrent
                        $ipAddressLocalNetwork = $ipAddressLocal | Where-Object -FilterScript { $psItem.PrefixOrigin -ne 'WellKnown' }
                        $ipAddressLocalString  = $ipAddressLocalNetwork.IPAddress
                    
                        $Message = "Creating Firewall rule for `“$RuleName`” on $psItem"
                        Write-Verbose -Message $Message

                        $RuleParam  = @{

                            DisplayName   = $RuleName
                            Description   = 'Temporary SQL Server connection information to client computers'
                            LocalPort     =  1433
                            RemoteAddress = $ipAddressLocalString
                            Enabled       = 'True'
                            Profile       = 'Domain'
	                        Direction     = 'Inbound'
	                        Action        = 'Allow'
	                        Protocol      = 'TCP'
                            Group         = 'SQL Server'
                            cimSession    = $SessionCurrent
                        }
                        [System.Void]( New-netFirewallRule @RuleParam )
                    }
                }

              # Firewall Rules and network settings for Clustered Services
              # Such as SQL Server Database Engine.

                $ClusterResourceSqlServer | ForEach-Object -Process {

                   #region Basic variables

                        $SqlServerClusterResourceCurrent = $psItem

                        Write-Verbose -Message '***'
                        $Message = "Cluster instance `“$($SqlServerClusterResourceCurrent.Name)"
                        Write-Verbose -Message $Message

                        $AddressFCI = [System.Collections.Generic.List[System.Net.ipAddress]]::new()
                        $AddressAG  = [System.Collections.Generic.List[System.Net.ipAddress]]::new()
                        $Address    = [System.Collections.Generic.List[System.Net.ipAddress]]::new()

                      # Obtain general values required to create Firewall Rules
                      # for an Clustered Instance.
   
                        $NodeParam = @{

                            Resource    = $SqlServerClusterResourceCurrent
                            InputObject = $Cluster
                        }
                
                        $ClusterNodeOwner   = Get-ClusterOwnerNode @NodeParam
                        $ClusterNode        = $ClusterNodeOwner.OwnerNodes
                        $ClusterNodeAddress = Resolve-DnsNameEx -Name $ClusterNode.Name

                        $ClusterNodeAddress | ForEach-Object -Process {

                            $Message = "  * $psItem"
                            Write-Verbose -Message $Message
                        }

                        $SessionCurrent = $Session | Where-Object -FilterScript {
                            $psItem.ComputerName -eq $ClusterNodeAddress[0]
                        }

                      # Derive an IP Address from the parent Cluster Group.
                      # We will need it later to change Instance network properties

                        $SqlServerClusterGroup =
                            $SqlServerClusterResourceCurrent.OwnerGroup

                        $SqlServerClusterGroupResource =
                            Get-ClusterResource -InputObject $SqlServerClusterGroup

                        $SqlServerClusterGroupResource |
                            Where-Object -FilterScript {
                                $psItem.ResourceType -eq 'IP Address'
                            } | ForEach-Object -Process {

                            $ClusterParameterParam = @{
                    
                                InputObject = $psItem
                                Name        = 'Address'
                            }
                            $SqlServerParameterIpAddress =
                                Get-ClusterParameter @ClusterParameterParam

                            $AddressFCI.Add( [System.Net.ipAddress]$SqlServerParameterIpAddress.Value )
                        }

                        $Message = "Always On Failover Cluster Instance (FCI) Address(es):"
                        Write-Verbose -Message $Message

                        $AddressFCI | ForEach-Object -Process {

                            $Message = "  * $($psItem.toString())"
                            Write-Verbose -Message $Message
                        }

                        $Address.AddRange( $AddressFCI )

                   #endregion Basic variables
               
                   #region Resource type-specific properties

                        $ServiceNameDisplay = $SqlServerClusterResourceCurrent.Name

                        $InstanceParam = @{

                            ClassName  = 'Win32_Service'
                            Filter     = "DisplayName like '%$ServiceNameDisplay'"
                            cimSession = $SessionCurrent
                            Verbose    = $False
                        }
                        $Service = Get-CimInstance @InstanceParam

                        $ServiceNameShort   = $Service.Name
                        $ServiceDescription = $Service.Description
                        $ServicePathName    = $Service.PathName
                        $ServicePath        =
                             ( ( $ServicePathName -split """ -s" )[0] ).TrimStart( """" ).TrimEnd( """" )

                     <# $Message = "Processing Cluster Resource: $($SqlServerClusterResourceCurrent.Name)"
                        Write-Verbose -Message $Message  #>

                        Switch
                        (
                            $SqlServerClusterResourceCurrent.ResourceType
                        )
                        {
                            'SQL Server'
                            {
                                $Message = 'This is Database Engine'
                                Write-Verbose -Message $Message

                              # Derive Instance Address from Cluster Resource properties.
                              # We will need it later to obtain WMI Object of the Instance.

                              # Instance Network Name, or Virtual Server Name is the flat
                              # (NetBios-style) VCO name.

                                $ClusterParameterParam = @{
                
                                    InputObject = $SqlServerClusterResourceCurrent
                                    Name        = 'VirtualServerName'
                                }
                                $SqlServerParameter =
                                    Get-ClusterParameter @ClusterParameterParam

                                $InstanceNetworkNameString = $SqlServerParameter.Value             

                              # Instance Network Address is the VCO address (FQDN).

                                $InstanceNetworkAddress =
                                    Resolve-DnsNameEx -Name $InstanceNetworkNameString

                              # Instance Name could be different from the Network Name (that is,
                              # VCO flat name).

                                $ClusterParameterParam = @{
                
                                    InputObject = $SqlServerClusterResourceCurrent
                                    Name        = 'InstanceName'
                                }
                                $InstanceNameParameter =
                                    Get-ClusterParameter @ClusterParameterParam

                                $InstanceNameString = $InstanceNameParameter.Value

                              # Finally, construct the fully-qualified Instance address.
                              # Assuming we're always using the default port, we do not
                              # to specify Instance name. Otherwise, a running and
                              # available Browser service will be necessary.

                                $InstanceAddress =
                                    $InstanceNetworkAddress # + "\" + $InstanceNameString

                                $Message = 'Changing SQL Server network port binding'
                                Write-Verbose -Message $Message
                            
                               #region SQL Server Network Configuration

                                  # Change the Port binding for SQL Server Database
                                  # Engine (instance). This should be done only on the current
                                  # Node which owns the cluster group.

                                    $ClusterNodeCurrent     = $SqlServerClusterGroup.OwnerNode
                                    $ClusterNodeCurrentName = $ClusterNodeCurrent.Name

                                    $ClusterNodeCurrentAddress =
                                        Resolve-DnsNameEx -Name $ClusterNodeCurrentName

                                    $SessionCurrent = $Session | Where-Object -FilterScript {
                                        $psItem.ComputerName -eq $ClusterNodeCurrentAddress
                                    }

                                  # Obtain WMI Object

                                    $Message = "Connecting to SQL Server WMI Managed Computer at $ClusterNodeCurrentAddress (current cluster node)"
                                    Write-Verbose -Message $Message

                                    $ObjectParam = @{

                                        TypeName     = 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer'
                                        ArgumentList = $ClusterNodeCurrentAddress
                                    }
                                    $ManagedComputer = New-Object @ObjectParam

                                 <# $Uri  = [System.String]::Empty
                                    $Uri += "ManagedComputer[@Name='$ClusterNodeCurrentAddress']"
                                    $Uri += "/ServerInstance[@Name='$InstanceNameString']"
                                    $Uri += "/ServerProtocol[@Name='Tcp']"

                                    $Tcp = $ManagedComputer.GetSmoObject( $uri )  #>

                                    $Tcp = $ManagedComputer.ServerInstances[ $InstanceNameString ].ServerProtocols[ 'Tcp' ]

                                    $Alter = $False

                                    $Tcp.IPAddresses | ForEach-Object -Process {

                                        $IpAddressCurrent = $psItem

                                        Switch
                                        (
                                            $IpAddressCurrent.IPAddress
                                        )
                                        {
                            
                                          # This is the “IP All” entry.
                            
                                            '0.0.0.0'
                                            {
                                              # On cluster, you cannot configure SQL Server to
                                              # listen on a specific IP addresses. You must chose
                                              # IPALL. The IP addresses on which the cluster
                                              # instance will be listening on is determined by
                                              # cluster resources (configurable through Cluster
                                              # Administrator, by adding IP Address resources
                                              # under SQL Network Name resource).
                             
                                                $Property = [System.Collections.Generic.Dictionary[System.String, System.String]]::new()

                                              # “Ip All” doesn't have an “Enabled” property
                                              # $Property.Add( 'Enabled',         '1'                    )
                                                $Property.Add( 'TcpDynamicPorts', [System.String]::Empty )
                                                $Property.Add( 'TcpPort',         '1433'                 )

                                                $Property.GetEnumerator() | ForEach-Object -Process {

                                                    $PropertyCurrent = $IpAddressCurrent.IPAddressProperties[ $psItem.Key ]

                                                    If
                                                    (
                                                        $PropertyCurrent.Value -eq $psItem.Value
                                                    )
                                                    {
                                                        $Message = "  * `“$($PropertyCurrent.Name)`” for `“$($IpAddressCurrent.Name)`” already has expected value `“$($psItem.Value)`”"
                                                    }
                                                    Else
                                                    {
                                                        $Message = "  * Setting value `“$($psItem.Value)`” on `“$($PropertyCurrent.Name)`” for `“$($IpAddressCurrent.Name)`”"

                                                        $PropertyCurrent.Value = $psItem.Value

                                                        $Alter = $True
                                                    }
                                                    Write-Verbose -Message $Message
                                                }
                                            }

                                          # This is the “IPn” entry with relevant IP Address
                                          # for either our Clustered Instance or Availability
                                          # Group.

                                            {
                                                ( [System.Net.ipAddress]$psItem -In $AddressFCI ) -Or
                                                ( [System.Net.ipAddress]$psItem -In $AddressAG  )
                                            }
                                            {
                                                $Property = [System.Collections.Generic.Dictionary[System.String, System.String]]::new()

                                                $Property.Add( 'Enabled',         '1'                    )
                                                $Property.Add( 'TcpDynamicPorts', [System.String]::Empty )
                                                $Property.Add( 'TcpPort',         '1433'                 )

                                                $Property.GetEnumerator() | ForEach-Object -Process {

                                                    $PropertyCurrent = $IpAddressCurrent.IPAddressProperties[ $psItem.Key ]

                                                    If
                                                    (
                                                        $PropertyCurrent.Value -eq $psItem.Value
                                                    )
                                                    {
                                                        $Message = "  * `“$($PropertyCurrent.Name)`” for `“$($IpAddressCurrent.Name)`” already has expected value `“$($psItem.Value)`”"
                                                    }
                                                    Else
                                                    {
                                                        $Message = "  * Setting value `“$($psItem.Value)`” on `“$($PropertyCurrent.Name)`” for `“$($IpAddressCurrent.Name)`”"

                                                        $PropertyCurrent.Value = $psItem.Value

                                                        $Alter = $True
                                                    }
                                                    Write-Verbose -Message $Message
                                                }
                                             <# $IpAddressCurrent.IPAddressProperties["Enabled"].Value         = "1"
                                                $IpAddressCurrent.IPAddressProperties["TcpDynamicPorts"].Value = ""
                                                $IpAddressCurrent.IPAddressProperties["TcpPort"].Value         = "1433"  #>
                                            }

                                            Default
                                            {
                                                $Message = "  * No special configuration for IP Address `“$psItem`”. It should not normally be accessed"
                                                Write-Verbose -Message $Message
                                            }
                                        }                                        
                                    }

                                    If
                                    (
                                        $Alter
                                    )
                                    {
                                        $Tcp.Alter()

                                        $ClusterGroup =
                                            Stop-ClusterGroup  -InputObject $SqlServerClusterGroup

                                        $ClusterGroup =
                                            Start-ClusterGroup -InputObject $SqlServerClusterGroup

                                        $Message = "Successfully changed SQL Server network port binding"
                                        Write-Verbose -Message $Message
                                    }
                                    Else
                                    {
                                        $Message = "No network configuration was changed, skipping cluster group recycle"
                                        Write-Verbose -Message $Message
                                    }

                               #endregion SQL Server Network Configuration

                              # We need the WMI object since Powershell object of a Service
                              # does not contain the command line or executable path.

                              # Obtain the SQL Server Instance WMI object.
                            
                                $Message = "Connecting to SQL Server Management Object (SMO) at $InstanceAddress"

                                Write-Verbose -Message $Message

                                $ObjectParam = @{

                                    TypeName     = 'Microsoft.SQLServer.Management.SMO.Server'
                                    ArgumentList = $InstanceAddress
                                }
                                $Instance = New-Object @ObjectParam

                              # Check whether there are Always On Availability Groups. This
                              # will affect the set of IP Addresses used in Firewall Rules.
                              # If there are Always On Availability Groups, they will have
                              # their own IP Addresses

                                $AvailabilityGroup = $Instance.AvailabilityGroups

                                If
                                (
                                    $AvailabilityGroup
                                )
                                {
                                    $AvailabilityGroup | ForEach-Object -Process {

                                        $AvailabilityGroupCurrent = $psItem
                                        $AvailabilityGroupName    = $AvailabilityGroupCurrent.Name

                                        $AvailabilityGroupClusterResource = $ClusterResource |
                                            Where-Object -FilterScript {
                                                $psItem.ResourceType -eq 'SQL Server Availability Group'
                                            }

                                        $AvailabilityGroupClusterResourceCurrent = $AvailabilityGroupClusterResource |
                                            Where-Object -FilterScript {
                                                $psItem.Name -eq $AvailabilityGroupName
                                            }

                                        $AvailabilityGroupClusterGroup = $AvailabilityGroupClusterResourceCurrent.OwnerGroup

                                      # Derive an IP Address from the parent Cluster Group

                                        $AvailabilityGroupClusterGroupResource = Get-ClusterResource -InputObject $AvailabilityGroupClusterGroup
                                    
                                        $IpAddressAvailabilityGroupResource  = $AvailabilityGroupClusterGroupResource |
                                            Where-Object -FilterScript { $psItem.ResourceType -eq 'IP Address' }
                                    
                                        $IpAddressAvailabilityGroupResource | ForEach-Object -Process {

                                            $IpAddressAvailabilityGroupParameter =
                                                Get-ClusterParameter -InputObject $psItem -Name 'Address'
                                    
                                            $AddressAG.Add( [System.Net.ipAddress]$IpAddressAvailabilityGroupParameter.Value )
                                        }

                                        $Message = "Always On Availability Group Address count: $($AddressAG.Count)"
                                        Write-Verbose -Message $Message

                                        $AddressAG | ForEach-Object -Process {

                                            $Message = "  * $($psItem.toString())"
                                            Write-Verbose -Message $Message
                                        }
                                    }

                                  # Set of IP Addresses used by both Database Engine (Instance) and
                                  # Availability Groups. We will use these IP Addresses combine for Windows
                                  # Firewall rules created for SQL Server Database Engine. If Availability
                                  # Groups are used, we do not strictly need to include the individual 
                                  # Instance addresses. However, it is beneficial from remote management
                                  # standpoint.

                                    $Address.AddRange( $AddressAG  )
                                }
                            }

                            'Generic Service'
                            {
                                Write-Verbose -Message 'This is Generic resource'

                                $SqlServerResourceNetworkName    =
                                    $SqlServerClusterGroupResource |
                                        Where-Object -FilterScript {
                                            $psItem.ResourceType -eq 'Network Name'
                                        }

                                $ClusterParameterParam = @{
                    
                                    InputObject = $SqlServerResourceNetworkName
                                    Name        = 'DnsName'
                                }
                                $SqlServerParameter =
                                    Get-ClusterParameter @ClusterParameterParam

                                $InstanceNetworkNameString = $SqlServerParameter.Value             

                              # Instance Network Address is the VCO address (FQDN).

                                $InstanceNetworkAddress =
                                    Resolve-DnsNameEx -Name $InstanceNetworkNameString
                            }

                            Default
                            {
                                $Message = "No specific configuration for Cluster Resource Type `“$psItem`”"
                                Write-Verbose -Message $Message
                            }
                        }
                                                                
                   #endregion Resource type-specific properties

                   #region Windows Firewall Rule

                      # Windows Firewall Rules are created individually on each
                      # Cluster Node regardless of the current state of SQL Server
                      # services.

                        $ClusterNodeAddress | ForEach-Object -Process {                            

                            $ClusterNodeAddressCurrent = $psItem

                            Write-Verbose -Message '***'
                            $Message = "Cluster instances on Cluster Node `“$ClusterNodeAddressCurrent`”"
                            Write-Verbose -Message $Message

                            $SessionCurrent = $Session | Where-Object -FilterScript {
                                $psItem.ComputerName -eq $ClusterNodeAddressCurrent
                            }

                            $Rule = Get-netFirewallRule -CimSession $SessionCurrent

                           #region Rule for the primary service

                                $RuleName = $Service.Caption

                                If
                                (
                                    $Rule | Where-Object -FilterScript { $psItem.DisplayName -eq $RuleName }
                                )
                                {
                                    $Message = "Firewall Rule for `“$RuleName`” already exists on $psItem. Removing"
                                    Write-Verbose -Message $Message

                                    $RuleParam = @{

                                        DisplayName = $RuleName
                                        CimSession  = $SessionCurrent
                                    }
                                    [System.Void]( Remove-NetFirewallRule @RuleParam )
                                }
                              # Else
                              # {
                                    $Message = "Creating Firewall rule for `“$RuleName`” on $psItem for $($Address.Count) address(es):"
                                    Write-Verbose -Message $Message

                                    $Address | ForEach-Object -Process {

                                        $Message = "  * $($psItem.toString())"
                                        Write-Verbose -Message $Message
                                    }

                                    $RuleParam = @{

                                        DisplayName  = $RuleName
                                        Description  = $ServiceDescription
                                        Service      = $ServiceNameShort
                                        Program      = $ServicePath
                                        LocalAddress = $Address | ForEach-Object -Process { $psItem.ToString() }
                                        Enabled      = 'True'
                                        Profile      = 'Domain'
	                                    Direction    = 'Inbound'
	                                    Action       = 'Allow'
	                                    Protocol     = 'TCP'
                                        Group        = 'SQL Server'
                                        cimSession   = $SessionCurrent
                                    }

                                    Switch
                                    (
                                        $ServicePath.Split( "\" )[ -1 ]
                                    )
                                    {
                                    
                                      # Database Engine
                                    
                                        'sqlservr.exe'
                                        {
                                            $RuleParam.Add( 'LocalPort', 1433 )
                                        }

                                      # Analysis Services

                                        'msmdsrv.exe'
                                        {
                                            $RuleParam.Add( 'LocalPort', @( 2383, 1433 ) )
                                        }

                                      # Integration Services

                                        'MsDtsSrvr.exe'
                                        {
                                          # $RuleParam.Add( 'LocalPort', 1433 )
                                        }
                                    }
                                    [System.Void]( New-netFirewallRule @RuleParam )
                              # }

                           #endregion Rule for Database Engine

                           #region Rule for Service Broker Endpoint

                                $RuleName = $ServiceNameDisplay + ' — Service Broker Endpoint'

                                If
                                (
                                    $Rule | Where-Object -FilterScript { $psItem.DisplayName -eq $RuleName }
                                )
                                {
                                    $Message = "Firewall Rule for `“$RuleName`” already exists on $psItem. Removing"
                                    Write-Verbose -Message $Message

                                    $RuleParam = @{

                                        DisplayName = $RuleName
                                        CimSession  = $SessionCurrent
                                    }
                                    [System.Void]( Remove-NetFirewallRule @RuleParam )
                                }
                              # Else
                              # {
                                    $Message = "Creating Firewall rule for `“$RuleName`” on $psItem for $($Address.Count) address(es):"
                                    Write-Verbose -Message $Message

                                    $Address | ForEach-Object -Process {

                                        $Message = "  * $($psItem.toString())"
                                        Write-Verbose -Message $Message
                                    }

                                    $RuleParam = @{

                                        DisplayName  = $RuleName
                                        Description  = $ServiceDescription
                                        Service      = $ServiceNameShort
                                        Program      = $ServicePath
                                        LocalPort    =  5022
                                        LocalAddress = $Address | ForEach-Object -Process { $psItem.ToString() }
                                        Enabled      = 'True'
                                        Profile      = 'Domain'
	                                    Direction    = 'Inbound'
	                                    Action       = 'Allow'
	                                    Protocol     = 'TCP'
                                        Group        = 'SQL Server'
                                        cimSession   = $SessionCurrent
                                    }
                                    [System.Void]( New-netFirewallRule @RuleParam )
                              # }

                           #endregion Service Broker

                           #region Rule for Database Mirroring Endpoint
                          
                              # Endpoint is used for AlwaysOn Availability Groups

                                If
                                (
                                    $AvailabilityGroup
                                )
                                {
                                    $RuleName = $ServiceNameDisplay + ' — Mirroring Endpoint'

                                    If
                                    (
                                        $Rule | Where-Object -FilterScript { $psItem.DisplayName -eq $RuleName }
                                    )
                                    {
                                        $Message = "Firewall Rule for `“$RuleName`” already exists on $psItem. Removing"
                                        Write-Verbose -Message $Message

                                        $RuleParam = @{

                                            DisplayName = $RuleName
                                            CimSession  = $SessionCurrent
                                        }
                                        [System.Void]( Remove-NetFirewallRule @RuleParam )
                                    }
                                  # Else
                                  # {
                                        $Message = "Creating Firewall rule for `“$RuleName`” on $psItem for $($AddressFCI.Count) address(es):"
                                        Write-Verbose -Message $Message

                                        $AddressFCI | ForEach-Object -Process {

                                            $Message = "  * $($psItem.toString())"
                                            Write-Verbose -Message $Message
                                        }

                                        $RuleParam = @{

                                            DisplayName  = $RuleName
                                            Description  = $ServiceDescription
                                            Service      = $ServiceNameShort
                                            Program      = $ServicePath
                                            LocalPort    =  5022
                                            LocalAddress = $AddressFCI | ForEach-Object -Process { $psItem.ToString() }
                                            Enabled      = 'True'
                                            Profile      = 'Domain'
	                                        Direction    = 'Inbound'
	                                        Action       = 'Allow'
	                                        Protocol     = 'TCP'
                                            Group        = 'SQL Server'
                                            cimSession   = $SessionCurrent
                                        }
                                        [System.Void]( New-netFirewallRule @RuleParam )
                                  # }
                                }

                           #endregion Rule for Database Mirroring 
                       }

                   #endregion Windows Firewall Rule
                }
            
              # Cleanup

                $RuleName = 'SQL Server — Temporary'

                $ClusterNodeAddress | ForEach-Object -Process {

                    $ClusterNodeAddressCurrent = $psItem

                    $SessionCurrent = $Session | Where-Object -FilterScript {
                        $psItem.ComputerName -eq $ClusterNodeAddressCurrent
                    }

                    $Message = "Removing Firewall rule for `“$RuleName`” on $psItem"
                    Write-Verbose -Message $Message

                    $RuleParam = @{

                        DisplayName = $RuleName
                        cimSession  = $SessionCurrent
                    }
                    [System.Void]( Remove-netFirewallRule @RuleParam )
                }            
            }

            Else

          # Not clustered services. They reside on a single machine and share
          # a common set of addresses (Host names IP address) across all services.

            {
                $ServerAddress = Resolve-DnsNameEx -Name $psItem  # -Verbose:$False

                $Session = New-cimSessionEx -Name $psItem

                $RuleParam = @{

                    DisplayGroup = 'Windows Management Instrumentation (WMI)'
                    cimSession   = $Session
                }
                [System.Void]( Enable-netFirewallRule @RuleParam )

                $Message = "Connecting to SQL Server WMI Managed computer at $ServerAddress (standalone server)"

                Write-Verbose -Message $Message

                $ObjectParam = @{

                    TypeName     = 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer'
                    ArgumentList = $ServerAddress
                }
                $ManagedComputer = New-Object @ObjectParam

                $Rule = Get-netFirewallRule -cimSession $Session

                If
                (
                    $ManagedComputer.Properties.Count -or
                    $ManagedComputer.Services.Count
                )
                {
                    $ManagedComputer.Services | ForEach-Object -Process {

                        $ServiceCurrent = $psItem

                        Switch
                        (
                            $ServiceCurrent.Type
                        )

                      # http://msdn.microsoft.com/library/microsoft.sqlserver.management.smo.wmi.managedservicetype.aspx

                        {
                            'AnalysisServer'
                            {

                              # Create Firewall rule for SQL Server Analysis Services
                        
                                $DisplayName = $ServiceCurrent.DisplayName

                                If
                                (
                                    $ServiceCurrent.AdvancedProperties[ 'INSTANCEID' ].Value.Split( '.' )[ 1 ] -eq 'msSqlServer'
                                )
                                {
                                    $Message = 'This is a default instance'
                                    Write-Verbose -Message $Message
                                }
                                Else
                                {
                                    $Message = 'This is a named instance'
                                    Write-Verbose -Message $Message

                                    $Path = "\\$ServerAddress\c$\Program Files\Microsoft SQL Server\$( $ServiceCurrent.AdvancedProperties[ 'INSTANCEID' ].Value )\OLAP\Config\msmdsrv.ini"

                                    $Content = Get-Content -Path $path

                                    If
                                    (
                                        $Content.Contains( '	<Port>2383</Port>' )
                                    )
                                    {
                                        $Message = 'The port is already set to static 2383. Nothing to change'
                                        Write-Verbose -Message $Message
                                    }
                                    ElseIf
                                    (
                                        $Content.Contains( '	<Port>0</Port>' )
                                    )
                                    {
                                        $Message = 'The port is currently set to dynamic. Changing'
                                        Write-Verbose -Message $Message

                                        $New = $Content.replace( '<Port>0</Port>', '<Port>2383</Port>' )
                                        Set-Content -Value $New -Path $Path

                                        $ServiceCurrent.Stop()
                                    
                                        $Message = 'Stopping'
                                        Write-Verbose -Message $Message

                                        $ServiceCurrent.Refresh()
                                
                                        While
                                        (
                                            $ServiceCurrent.ServiceState -eq 'Running'
                                        )
                                        {
                                            $Message = 'Waiting to stop'
                                            Write-Verbose -Message $Message
                                            Start-Sleep -Seconds 1
                                            $ServiceCurrent.Refresh()
                                        }

                                        $ServiceCurrent.Start()

                                        $Message = 'Starting'
                                        Write-Verbose -Message $Message

                                        $ServiceCurrent.Refresh()
                                
                                        While
                                        (
                                            $ServiceCurrent.ServiceState -ne 'Running'
                                        )
                                        {
                                            $Message = 'Waiting to start'
                                            Write-Verbose -Message $Message
                                            Start-Sleep -Seconds 1
                                            $ServiceCurrent.Refresh()
                                        }
                                    }
                                    Else
                                    {
                                        $Message = 'Unknonw port settings'
                                        Write-Warning -Message $Message
                                    }
                                }

                                $RuleCurrent = $Rule | Where-Object -FilterScript {
                                    $psItem.DisplayName -eq $DisplayName
                                }

                                If
                                (
                                    $RuleCurrent
                                )
                                {
                                    Remove-netFirewallRule -InputObject $RuleCurrent
                                }

                                $Message = "Creating Firewall rule for `“$DisplayName`” on $ServerAddress"
                                Write-Verbose -Message $Message

                                $RuleParam = @{

                                    DisplayName = $DisplayName
                                    Description = $ServiceCurrent.Description
                                    Service     = $ServiceCurrent.Name
                                    Program     = $ServiceCurrent.PathName.Split( """" )[1]
                                    LocalPort   = @( 2383, 1433 )
                                    Protocol    = 'TCP'
                                    Profile     = 'Domain'
                                    Direction   = 'Inbound'
                                    Action      = 'Allow'
                                    Enabled     = 'True'
                                    cimSession  = $Session
                                }
                                [System.Void]( New-netFirewallRule @RuleParam )
                            }

                            'ReportServer'
                            {

                              # Create Firewall rule for SQL Server Reporting Services
                              # SC VMM integration requires access through unencrypted HTTP port (80)

                                $DisplayName = $ServiceCurrent.DisplayName

                                $RuleCurrent = $Rule | Where-Object -FilterScript {
                                    $psItem.DisplayName -eq $DisplayName
                                }

                                If
                                (
                                    $RuleCurrent
                                )
                                {
                                    Remove-netFirewallRule -InputObject $RuleCurrent
                                }

                                $Message = "Creating Firewall rule for `“$DisplayName`” on $ServerAddress"
                                Write-Verbose -Message $Message

                                $RuleParam = @{

                                    DisplayName = $DisplayName
                                    Description = $ServiceCurrent.Description
         
                                  # We're not using Service SID here since the actual port is listened
                                  # by HTTP.sys and not the Reporting Service.
                                  # Service     = "MSSQLServerOLAPService"

                                    Program     = 'System'
                                    LocalPort   =  80,443
                                    Protocol    = 'TCP'
                                    Profile     = 'Domain'
                                    Direction   = 'Inbound'
                                    Action      = 'Allow'
                                    Enabled     = 'True'
                                    cimSession  = $Session
                                }
                                [System.Void]( New-netFirewallRule @RuleParam )
                            }

                            'SqlServerIntegrationService'
                            {
                                $DisplayName = $ServiceCurrent.DisplayName

                                $RuleCurrent = $Rule | Where-Object -FilterScript {
                                    $psItem.DisplayName -eq $DisplayName
                                }

                                If
                                (
                                    $RuleCurrent
                                )
                                {
                                    Remove-netFirewallRule -InputObject $RuleCurrent
                                }

                                $Message = "Creating Firewall rule for `“$DisplayName`” on $ServerAddress"
                                Write-Verbose -Message $Message

                                $RuleParam = @{

                                    DisplayName = $DisplayName
                                    Description = $ServiceCurrent.Description
                                    Service     = $ServiceCurrent.Name
                                    Program     = $ServiceCurrent.PathName.Split( """" )[1]
                                  # LocalPort   =  80,443
                                    Protocol    = 'TCP'
                                    Profile     = 'Domain'
                                    Direction   = 'Inbound'
                                    Action      = 'Allow'
                                    Enabled     = 'True'
                                    cimSession  = $Session
                                }
                                [System.Void]( New-netFirewallRule @RuleParam )
                            }
                        }
                    }
                }
                Else
                {
                    $Message = 'There are no SQL Server services configured'
                    Write-Verbose -Message $Message
                }
            }
        }
    }

    End
    {
    }
}