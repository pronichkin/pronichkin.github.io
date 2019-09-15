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
        [System.String]
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
        $Cluster = Test-clusterNodeEx -Name $Name

        If
        (
            $Cluster
        )
     
      # We are dealing with clustered services. They migh have multiple nodes,
      # and each service has its own set of addresses (Host names
      # and IP addresses).

        {
          # $ClusterAddress     = Resolve-DnsNameEx -Name $Name
          # $Cluster            = Get-Cluster -Name $ClusterAddress
            $ClusterResource    = Get-ClusterResource -InputObject $Cluster

            $ClusterResourceSqlServer = $ClusterResource |
                Where-Object -FilterScript {
                    $psItem.ResourceType -eq "SQL Server" -or
                    (
                        $psItem.ResourceType -eq "Generic Service" -and
                        $psItem.Name -notlike '*CEIP*'
                    )
                }

            $ClusterNode        = Get-ClusterNode -InputObject $Cluster
            $ClusterNodeName    = $ClusterNode.Name
            $ClusterNodeAddress = Resolve-DnsNameEx -Name $ClusterNodeName

          # Firewall Rules for Non-Clustered Services
          # Such as SQL Server Browser and Windows Management Instrumentation.

            $ClusterNodeAddress | ForEach-Object -Process {

                $ClusterNodeCurrentAddress = $psItem

              # The Browser service is not actually required since we're making
              # all instances to listen on default port (1433). We still create
              # the Firewall rule just in case, but make it disabled.

                $NetFirewallRuleName = "SQL Server Browser"

                $GetNetFirewallRuleParam = @{

                    DisplayName = $NetFirewallRuleName
                    cimSession  = $ClusterNodeCurrentAddress
                    ErrorAction = "Ignore"
                }                
                $NetFirewallRule = Get-netFirewallRule @GetNetFirewallRuleParam

                If
                (
                    $NetFirewallRule
                )
                {
                    $Message = "Firewall Rule for ""$NetFirewallRuleName"" already exists!"
                    
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $Message = "Creating Firewall rule for ""$NetFirewallRuleName"" on $ClusterNodeCurrentAddress"

                    Write-Verbose -Message $Message
                    
                    $NetFirewallRuleParam  = @{

                        DisplayName  = $NetFirewallRuleName
                        Description  = "Provides SQL Server connection information to client computers."
                        Service      = "SQLBrowser"
                        Program      = "C:\Program Files (x86)\Microsoft SQL Server\90\Shared\sqlbrowser.exe"
                        LocalPort    =  1434
                        Enabled      = "False"
                        Profile      = "Domain"
	                    Direction    = "Inbound"
	                    Action       = "Allow"
	                    Protocol     = "UDP"
                        Group        = "SQL Server"
                        cimSession   = $ClusterNodeCurrentAddress
                    }
                    $NetFirewallRule = New-netFirewallRule @NetFirewallRuleParam
                }

              # Enable default Firewall Rules for Windows Management
              # Instrumentation (WMI). This is required for SQL Server
              # Configuration Manager and obtaining management objects
              # later in this script.

                $EnableNetFirewallRuleParam = @{

                    DisplayGroup = "Windows Management Instrumentation (WMI)"
                    cimSession   = $ClusterNodeCurrentAddress
                }
                $NetFirewallRule = Enable-netFirewallRule @EnableNetFirewallRuleParam

              # Create a temporary rule which allows remote connection to SQL
              # Server without additional qualifications. This is required to
              # obtain detailed information about instances so that we can build
              # more specific rules for permanent use.

                $NetFirewallRuleName = "SQL Server — Temporary"

                $GetNetFirewallRuleParam = @{

                    DisplayName = $NetFirewallRuleName
                    cimSession  = $ClusterNodeCurrentAddress
                    ErrorAction = "Ignore"
                }                
                $NetFirewallRule = Get-netFirewallRule @GetNetFirewallRuleParam

                If
                (
                    $NetFirewallRule
                )
                {
                    $Message = "Firewall Rule for $NetFirewallRuleName already exists!"
                    
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $ipAddressLocal        = Get-netIPAddress -AddressFamily IPv4 -Type Unicast 
                    $ipAddressLocalNetwork = $ipAddressLocal | Where-Object -FilterScript { $psItem.PrefixOrigin -ne "WellKnown" }
                    $ipAddressLocalString  = $ipAddressLocalNetwork.IPAddress
                    
                    $Message = "Creating Firewall rule for ""$NetFirewallRuleName"" on $ClusterNodeCurrentAddress"

                    Write-Verbose -Message $Message

                    $NetFirewallRuleParam  = @{

                        DisplayName   = $NetFirewallRuleName
                        Description   = "Temporary SQL Server connection information to client computers."
                        LocalPort     =  1433
                        RemoteAddress = $ipAddressLocalString
                        Enabled       = "True"
                        Profile       = "Domain"
	                    Direction     = "Inbound"
	                    Action        = "Allow"
	                    Protocol      = "TCP"
                        Group         = "SQL Server"
                        cimSession    = $ClusterNodeCurrentAddress
                    }
                    $NetFirewallRule = New-netFirewallRule @NetFirewallRuleParam
                }
            }

          # Firewall Rules and network settings for Clustered Services
          # Such as SQL Server Database Engine.

            $ClusterResourceSqlServer | ForEach-Object -Process {

               #region Basic variables

                  # Obtain general values required to create Firewall Rules
                  # for an Clustered Instance.

                    $SqlServerClusterResourceCurrent = $psItem
    
                    $GetClusterOwnerNodeParam = @{

                        Resource    = $SqlServerClusterResourceCurrent
                        InputObject = $Cluster
                    }
                
                    $ClusterNodeOwner   = Get-ClusterOwnerNode @GetClusterOwnerNodeParam
                    $ClusterNode        = $ClusterNodeOwner.OwnerNodes
                    $ClusterNodeName    = $ClusterNode.Name
                    $ClusterNodeAddress = Resolve-DnsNameEx -Name $ClusterNodeName

                    $SqlServerClusterGroup =
                        $SqlServerClusterResourceCurrent.OwnerGroup

                  # Derive an IP Address from the parent Cluster Group.
                  # We will need it later to change Instance network properties.

                    $SqlServerClusterGroupResource =
                        Get-ClusterResource -InputObject $SqlServerClusterGroup

                    $SqlServerResourceIpAddress    =
                        $SqlServerClusterGroupResource |
                            Where-Object -FilterScript {
                                $psItem.ResourceType -eq "IP Address"
                            }

                    $GetClusterParameterParam = @{
                    
                        InputObject = $SqlServerResourceIpAddress
                        Name        = "Address"
                    }
                    $SqlServerParameterIpAddress =
                        Get-ClusterParameter @GetClusterParameterParam

                    $ClusterGroupIpAddressString =
                        $SqlServerParameterIpAddress.Value

                    Write-Verbose -Message "AO FCI Address: $ClusterGroupIpAddressString"

                    $IpAddressString = [System.String[]]@()

               #endregion Basic variables
               
               #region Resource type-specific properties

                    $ServiceNameDisplay = $SqlServerClusterResourceCurrent.Name

                    Write-Verbose -Message "Processing Cluster Resource: $($SqlServerClusterResourceCurrent.Name)"

                    Switch
                    (
                        $SqlServerClusterResourceCurrent.ResourceType
                    )
                    {
                        "SQL Server"
                        {
                            Write-Verbose -Message "This is Database Engine"

                          # Derive Instance Address from Cluster Resource properties.
                          # We will need it later to obtain WMI Object of the Instance.

                          # Instance Network Name, or Virtual Server Name is the flat
                          # (NetBios-style) VCO name.

                            $GetClusterParameterParam = @{
                
                                InputObject = $SqlServerClusterResourceCurrent
                                Name        = "VirtualServerName"
                            }
                            $SqlServerParameter =
                                Get-ClusterParameter @GetClusterParameterParam

                            $InstanceNetworkNameString = $SqlServerParameter.Value             

                          # Instance Network Address is the VCO address (FQDN).

                            $InstanceNetworkAddress =
                                Resolve-DnsNameEx -Name $InstanceNetworkNameString

                          # Instance Name could be different from the Network Name (that is,
                          # VCO flat name).

                            $GetClusterParameterParam = @{
                
                                InputObject = $SqlServerClusterResourceCurrent
                                Name        = "InstanceName"
                            }
                            $InstanceNameParameter =
                                Get-ClusterParameter @GetClusterParameterParam

                            $InstanceNameString = $InstanceNameParameter.Value

                          # Finally, construct the fully-qualified Instance address.
                          # Assuming we're always using the default port, we do not
                          # to specify Instance name. Otherwise, a running and
                          # available Browser service will be necessary.

                            $InstanceAddress =
                                $InstanceNetworkAddress # + "\" + $InstanceNameString

                            $Message = "Changing SQL Server network port binding"

                            Write-Verbose -Message $Message
                            
                           #region SQL Server Network Configuration

                              # Change the Port binding for SQL Server Database
                              # Engine (instance). This should be done only on the current
                              # Node which owns the cluster group.

                                $ClusterNodeCurrent     = $SqlServerClusterGroup.OwnerNode
                                $ClusterNodeCurrentName = $ClusterNodeCurrent.Name

                                $ClusterNodeCurrentAddress =
                                    Resolve-DnsNameEx -Name $ClusterNodeCurrentName

                              # Obtain WMI Object

                                $Message = "Connecting to SQL Server WMI Managed Computer at $ClusterNodeCurrentAddress (current cluster node)"

                                Write-Verbose -Message $Message

                                $ObjectParam = @{

                                    TypeName     = "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer"
                                    ArgumentList = $ClusterNodeCurrentAddress
                                }
                                $ManagedComputer = New-Object @ObjectParam

                                $Uri  = [System.String]::Empty
                                $Uri += "ManagedComputer[@Name='$ClusterNodeCurrentAddress']"
                                $Uri += "/ServerInstance[@Name='$InstanceNameString']"
                                $Uri += "/ServerProtocol[@Name='Tcp']"

                                $Tcp = $ManagedComputer.GetSmoObject( $uri )

                                $Tcp.IPAddresses | ForEach-Object -Process {

                                    $IpAddressCurrent = $psItem

                                    Switch
                                    (
                                        $IpAddressCurrent.IPAddress
                                    )
                                    {
                            
                                      # This is the “IP All” entry.
                            
                                        "0.0.0.0"
                                        {

                                          # On cluster, you cannot configure SQL Server to
                                          # listen on a specific IP addresses. You must chose
                                          # IPALL. The IP addresses on which the cluster
                                          # instance will be listening on is determined by
                                          # cluster resources (configurable through Cluster
                                          # Administrator, by adding IP Address resources
                                          # under SQL Network Name resource).

                                          # “Ip All” doesn't have an “Enabled” property.
                              
                                          # $IpAddressCurrent.IPAddressProperties["Enabled"].Value         = ""
                                            $IpAddressCurrent.IPAddressProperties["TcpDynamicPorts"].Value = ""
                                            $IpAddressCurrent.IPAddressProperties["TcpPort"].Value         = "1433"

                                        }

                                      # This is the “IPn” entry with relevant IP Address
                                      # for either our Clustered Instance or Availability
                                      # Group.

                                        {
                                            ( $psItem -Eq $ClusterGroupIpAddressString ) -Or
                                            (
                                                ( Test-Path -Path "Variable:\AvailabilityGroup" ) -And
                                                ( $psItem -Eq $IpAddressAvailabilityGroupString )
                                            )
                                        }
                                        {
                                            $IpAddressCurrent.IPAddressProperties["Enabled"].Value         = "1"
                                            $IpAddressCurrent.IPAddressProperties["TcpDynamicPorts"].Value = ""
                                            $IpAddressCurrent.IPAddressProperties["TcpPort"].Value         = "1433"
                                        }
                                    }
                                }

                                $Tcp.Alter()

                           #endregion SQL Server Network Configuration

                           #region Restart Cluster Group

                                $ClusterGroup =
                                    Stop-ClusterGroup  -InputObject $SqlServerClusterGroup

                                $ClusterGroup =
                                    Start-ClusterGroup -InputObject $SqlServerClusterGroup

                           #endregion Restart Cluster Group

                            $Message = "Successfully changed SQL Server network port binding"

                            Write-Verbose -Message $Message

                          # We need the WMI object since Powershell object of a Service
                          # does not contain the command line or executable path.

                          # Obtain the SQL Server Instance WMI object.
                            
                            $Message = "Connecting to SQL Server Management Object (SMO) at $InstanceAddress"

                            Write-Verbose -Message $Message

                            $ObjectParam = @{

                                TypeName     = "Microsoft.SQLServer.Management.SMO.Server"
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
                                $IpAddressAvailabilityGroupString = [system.string[]]@()

                                $AvailabilityGroup | ForEach-Object -Process {

                                    $AvailabilityGroupCurrent = $psItem
                                    $AvailabilityGroupName = $AvailabilityGroupCurrent.Name

                                    $AvailabilityGroupClusterResource = $ClusterResource |
                                        Where-Object -FilterScript {
                                            $psItem.ResourceType -eq "SQL Server Availability Group"
                                        }

                                    $AvailabilityGroupClusterResourceCurrent = $AvailabilityGroupClusterResource |
                                        Where-Object -FilterScript {
                                            $psItem.Name -eq $AvailabilityGroupName
                                        }

                                    $AvailabilityGroupClusterGroup = $AvailabilityGroupClusterResourceCurrent.OwnerGroup

                                  # Derive an IP Address from the parent Cluster Group.

                                    $AvailabilityGroupClusterGroupResource = Get-ClusterResource -InputObject $AvailabilityGroupClusterGroup
                                    
                                    $IpAddressAvailabilityGroupResource  = $AvailabilityGroupClusterGroupResource |
                                        Where-Object -FilterScript { $psItem.ResourceType -eq "IP Address" }
                                    
                                    $IpAddressAvailabilityGroupParameter =
                                        Get-ClusterParameter -InputObject $IpAddressAvailabilityGroupResource -Name "Address"
                                    
                                    $IpAddressAvailabilityGroupString   += $IpAddressAvailabilityGroupParameter.Value

                                    Write-Verbose -Message "AO AG Address count: $($IpAddressAvailabilityGroupString.Count)"
                                    $IpAddressAvailabilityGroupString | Write-Verbose
                                }

                              # Set of IP Addresses used by both Database Engine (Instance) and
                              # Availability Groups. We will use these IP Addresses combine for Windows
                              # Firewall rules created for SQL Server Database Engine. If Availability
                              # Groups are used, we do not strictly need to include the individual 
                              # Instance addresses. However, it is beneficial from remote management
                              # standpoint.

                                $IpAddressString += $ClusterGroupIpAddressString
                                $IpAddressString += $IpAddressAvailabilityGroupString
                            }
                            Else
                            {
                                $IpAddressString += $ClusterGroupIpAddressString
                            }
                        }

                        "Generic Service"
                        {
                            Write-Verbose -Message "This is Generic resource"

                            $SqlServerResourceNetworkName    =
                                $SqlServerClusterGroupResource |
                                    Where-Object -FilterScript {
                                        $psItem.ResourceType -eq "Network Name"
                                    }

                            $GetClusterParameterParam = @{
                    
                                InputObject = $SqlServerResourceNetworkName
                                Name        = "DnsName"
                            }
                            $SqlServerParameter =
                                Get-ClusterParameter @GetClusterParameterParam

                            $InstanceNetworkNameString = $SqlServerParameter.Value             

                          # Instance Network Address is the VCO address (FQDN).

                            $InstanceNetworkAddress =
                                Resolve-DnsNameEx -Name $InstanceNetworkNameString

                            $IpAddressString += $ClusterGroupIpAddressString
                        }
                    }

                    $GetCimInstanceParam = @{

                        ClassName  = "Win32_Service"
                        Filter     = "DisplayName like '%$ServiceNameDisplay'"
                        cimSession = $ClusterNodeAddress[0]
                    }
                    $Service = Get-CimInstance @GetCimInstanceParam

                    $ServiceNameShort   = $Service.Name
                    $ServiceDescription = $Service.Description
                    $ServicePathName    = $Service.PathName
                    $ServicePath        =
                         ( ( $ServicePathName -split """ -s" )[0] ).TrimStart( """" ).TrimEnd( """" )
                                                                
               #endregion Resource type-specific properties

               #region Windows Firewall Rule

                  # Windows Firewall Rules are created individually on each
                  # Cluster Node regardless of the current state of SQL Server
                  # services.

                    $ClusterNodeAddress | ForEach-Object -Process {

                        $ClusterNodeCurrentAddress = $psItem

                       #region Rule for Database Engine

                            $NetFirewallRuleName = $Service.Caption

                            $GetNetFirewallRuleParam = @{
                            
                                DisplayName  = $NetFirewallRuleName
                                cimSession   = $ClusterNodeCurrentAddress
                                ErrorAction  = "Ignore"
                            }
                            $NetFirewallRule =
                                Get-netFirewallRule @GetNetFirewallRuleParam

                            If
                            (
                                $NetFirewallRule
                            )
                            {
                                $Message =
                                    "The Firewall Rule for $NetFirewallRuleName already exists!"

                                Write-Verbose -Message $Message
                            }
                            Else
                            {
                                $Message = "Creating Firewall rule for ""$NetFirewallRuleName"" on $ClusterNodeCurrentAddress for $($IpAddressString.Count) address(es)"

                                Write-Verbose -Message $Message

                                $IpAddressString | Write-Verbose

                                $NetFirewallRuleParam = @{

                                    DisplayName  = $NetFirewallRuleName
                                    Description  = $ServiceDescription
                                    Service      = $ServiceNameShort
                                    Program      = $ServicePath
                                    LocalAddress = $IpAddressString
                                    Enabled      = "True"
                                    Profile      = "Domain"
	                                Direction    = "Inbound"
	                                Action       = "Allow"
	                                Protocol     = "TCP"
                                    Group        = "SQL Server"
                                    cimSession   = $ClusterNodeCurrentAddress
                                }

                                Switch
                                (
                                    $ServicePath.Split( "\" )[ -1 ]
                                )
                                {
                                    
                                  # Database Engine
                                    
                                    "sqlservr.exe"
                                    {
                                        $NetFirewallRuleParam.Add( "LocalPort", 1433 )
                                    }

                                  # Analysis Services

                                    "msmdsrv.exe"
                                    {
                                        $NetFirewallRuleParam.Add( "LocalPort", @( 2383, 1433 ) )
                                    }

                                  # Integration Services

                                    "MsDtsSrvr.exe"
                                    {
                                      # $NetFirewallRuleParam.Add( "LocalPort", 1433 )
                                    }
                                }
                                $NetFirewallRule = New-netFirewallRule @NetFirewallRuleParam
                            }

                       #endregion Rule for Database Engine

                       #region Rule for Database Mirroring Endpoint
                          
                          # Endpoint is used for AlwaysOn Availability Groups.

                            If
                            (
                                $AvailabilityGroup
                            )
                            {
                                $NetFirewallRuleName =
                                    $ServiceNameDisplay + " — Mirroring Endpoint"

                                $GetNetFirewallRuleParam = @{
                                
                                    DisplayName  = $NetFirewallRuleName
                                    cimSession   = $ClusterNodeCurrentAddress
                                    ErrorAction  = "Ignore"
                                }                                
                                $NetFirewallRule = Get-netFirewallRule @GetNetFirewallRuleParam

                                If
                                (
                                    $NetFirewallRule
                                )
                                {
                                    $Message =
                                        "The Firewall Rule for $NetFirewallRuleName already exists!"
                                    
                                    Write-Verbose -Message $Message
                                }
                                Else
                                {
                                    $Message = "Creating Firewall rule for ""$NetFirewallRuleName"" on $ClusterNodeCurrentAddress for"

                                    Write-Verbose -Message $Message

                                    $ClusterGroupIpAddressString | Write-Verbose

                                    $NetFirewallRuleParam = @{

                                        DisplayName  = $NetFirewallRuleName
                                        Description  = $ServiceDescription
                                        Service      = $ServiceNameShort
                                        Program      = $ServicePath
                                        LocalPort    =  5022
                                        LocalAddress = $ClusterGroupIpAddressString
                                        Enabled      = "True"
                                        Profile      = "Domain"
	                                    Direction    = "Inbound"
	                                    Action       = "Allow"
	                                    Protocol     = "TCP"
                                        Group        = "SQL Server"
                                        cimSession   = $ClusterNodeCurrentAddress
                                    }
                                    $NetFirewallRule = New-netFirewallRule @NetFirewallRuleParam
                                }
                            }

                       #endregion Rule for Database Mirroring 
                   }

               #endregion Windows Firewall Rule
            }

          # Clean up temporary firewall rule

            $ClusterNodeAddress | ForEach-Object -Process {

                $ClusterNodeCurrentAddress = $psItem

                $NetFirewallRuleName = "SQL Server — Temporary"

                $Message = "Removing Firewall rule for ""$NetFirewallRuleName"" on $ClusterNodeCurrentAddress for"

                Write-Verbose -Message $Message

                $NetFirewallRuleParam = @{

                    DisplayName = $NetFirewallRuleName
                    cimSession  = $ClusterNodeCurrentAddress
                }

                $NetFirewallRule = Remove-netFirewallRule @NetFirewallRuleParam
            }
        }

        Else

      # Not clustered services. They reside on a single machine and share
      # a common set of addresses (Host names IP address) across all services.

        {
            $ServerAddress = Resolve-DnsNameEx -Name $Name  # -Verbose:$False

            $Session = New-cimSessionEx -Name $Name

            $EnableNetFirewallRuleParam = @{

                DisplayGroup = "Windows Management Instrumentation (WMI)"
                cimSession   = $Session
            }
            $NetFirewallRule = Enable-netFirewallRule @EnableNetFirewallRuleParam

            $Message = "Connecting to SQL Server WMI Managed computer at $ServerAddress (standalone server)"

            Write-Verbose -Message $Message

            $ObjectParam = @{

                TypeName     = "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer"
                ArgumentList = $ServerAddress
            }
            $ManagedComputer = New-Object @ObjectParam

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
                        "AnalysisServer"
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

                            $NetFirewallRuleAll = Get-netFirewallRule -cimSession $Session

                            $NetFirewallRule = $NetFirewallRuleAll | Where-Object -FilterScript {

                                $psItem.DisplayName -eq $DisplayName
                            }

                            If
                            (
                                $NetFirewallRule
                            )
                            {
                                Remove-netFirewallRule -InputObject $NetFirewallRule
                            }

                            $Message = "Creating Firewall rule for ""$DisplayName"" on $ServerAddress"

                            Write-Verbose -Message $Message

                            $NetFirewallRuleParam = @{

                                DisplayName = $DisplayName
                                Description = $ServiceCurrent.Description
                                Service     = $ServiceCurrent.Name
                                Program     = $ServiceCurrent.PathName.Split( """" )[1]
                                LocalPort   = @( 2383, 1433 )
                                Protocol    = "TCP"
                                Profile     = "Domain"
                                Direction   = "Inbound"
                                Action      = "Allow"
                                Enabled     = "True"
                                cimSession  = $Session
                            }
                            $FirewallRule = New-netFirewallRule @NetFirewallRuleParam
                        }

                        "ReportServer"
                        {

                          # Create Firewall rule for SQL Server Reporting Services
                          # SC VMM integration requires access through unencrypted HTTP port (80)

                            $DisplayName = $ServiceCurrent.DisplayName

                            $NetFirewallRuleAll = Get-netFirewallRule -cimSession $Session

                            $NetFirewallRule = $NetFirewallRuleAll | Where-Object -FilterScript {

                                $psItem.DisplayName -eq $DisplayName
                            }

                            If
                            (
                                $NetFirewallRule
                            )
                            {
                                Remove-netFirewallRule -InputObject $NetFirewallRule
                            }

                            $Message = "Creating Firewall rule for ""$DisplayName"" on $ServerAddress"

                            Write-Verbose -Message $Message

                            $NetFirewallRuleParam = @{

                                DisplayName = $DisplayName
                                Description = $ServiceCurrent.Description
         
                              # We're not using Service SID here since the actual port is listened
                              # by HTTP.sys and not the Reporting Service.
                              # Service     = "MSSQLServerOLAPService"

                                Program     = "System"
                                LocalPort   =  80,443
                                Protocol    = "TCP"
                                Profile     = "Domain"
                                Direction   = "Inbound"
                                Action      = "Allow"
                                Enabled     = "True"
                                cimSession  = $Session
                            }
                            $FirewallRule = New-netFirewallRule @NetFirewallRuleParam
                        }

                        "SqlServerIntegrationService"
                        {
                            $DisplayName = $ServiceCurrent.DisplayName

                            $NetFirewallRuleAll = Get-netFirewallRule -cimSession $Session

                            $NetFirewallRule = $NetFirewallRuleAll | Where-Object -FilterScript {

                                $psItem.DisplayName -eq $DisplayName
                            }

                            If
                            (
                                $NetFirewallRule
                            )
                            {
                                Remove-netFirewallRule -InputObject $NetFirewallRule
                            }

                            $Message = "Creating Firewall rule for ""$DisplayName"" on $ServerAddress"

                            Write-Verbose -Message $Message

                            $NetFirewallRuleParam = @{

                                DisplayName = $DisplayName
                                Description = $ServiceCurrent.Description
                                Service     = $ServiceCurrent.Name
                                Program     = $ServiceCurrent.PathName.Split( """" )[1]
                              # LocalPort   =  80,443
                                Protocol    = "TCP"
                                Profile     = "Domain"
                                Direction   = "Inbound"
                                Action      = "Allow"
                                Enabled     = "True"
                                cimSession  = $Session
                            }
                            $FirewallRule = New-netFirewallRule @NetFirewallRuleParam
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

    End
    {
    }
}