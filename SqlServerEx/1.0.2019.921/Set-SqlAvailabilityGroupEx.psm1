Set-StrictMode -Version 'Latest'

Function
Set-SqlAvailabilityGroupEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[
            System.Collections.Generic.Dictionary[
                System.String,
                System.Collections.Generic.List[
                    System.String
                ]
            ]
        ]]
        $AvailabilityGroup
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Backup = ( Get-Item -Path '..\SQL Server Temporary Backup' )
    )

    Begin
    {
        $AvailabilityGroupAll =
            [System.Collections.Generic.List[Microsoft.SqlServer.Management.Smo.AvailabilityGroup]]::new()

      # $Module = Import-ModuleEx -Name "C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\SQLPS.PSD1"
      # $Module = Import-ModuleEx -Name "SqlServer"
      # $Module = Import-ModuleEx -Name $env:USERPROFILE\Downloads\SqlServer\21.0.17199\SqlServer.psd1
    }

    Process
    {        
        $AvailabilityGroup | ForEach-Object -Process {

           #region Variable

                $AvailabilityGroupCurrentProperty = $psItem
                $Name = $AvailabilityGroupCurrentProperty.Name[0]

                $Instance            =
                    [System.Collections.Generic.List[Microsoft.SqlServer.Management.Smo.Server]]::new()
                $AvailabilityReplica =
                    [System.Collections.Generic.List[Microsoft.SqlServer.Management.Smo.AvailabilityReplica]]::new()

                $NameParam = @{
                    Name = $AvailabilityGroupCurrentProperty.InstanceName[0]
                }
                $ClusterAddress = Resolve-dnsNameEx @NameParam
                $Cluster        = Get-Cluster -Name $ClusterAddress
                $ClusterGroup   = Get-ClusterGroup -InputObject $Cluster |
                    Where-Object -FilterScript { $psItem.Name -eq $Name }

                If
                (
                    $ClusterGroup
                )
                {
                    $Message = "Cluster Group for Availability Group `“$Name`” already exists"
                    Write-Verbose -Message $Message
                }

              # The assumption is that all Cluster Networks specified for
              # “Cluster And Client” have the same Subnet Mask. (That's the
              # only reason we need the network information.)

                $NetworkParam = @{
                    
                    InputObject = $Cluster
                    Verbose     = $False
                }

                $Network = Get-ClusterNetwork @NetworkParam |
                    Where-Object -FilterScript {
                        $psItem.Role -eq 'ClusterAndClient'
                } | Sort-Object | Select-Object -First 1

           #endregionregion Variable

           #region Backup location

              # This directory is only needed temporarily while seeding 
              # secondary replica(s) with database backup. However, the script
              # does not clean up after itself (unless a duplicate file name is
              # found), hence an existing backup location can be reused as well.

                $PathParam = @{
            
                    Path      = $Backup.FullName
                    ChildPath = $Name
                }
                $BackupPath = Join-Path @PathParam

                If
                (
                    Test-Path -Path $BackupPath
                )
                {
                    $Message = "    Backup location for Availability Group already exists at `“$BackupPath`”"
                    Write-Debug -Message $Message
                }
                Else
                {
                    $ItemParam = @{

                        Path     = $BackupPath
                        ItemType = 'Directory'
                    }
                    [System.Void]( New-Item @ItemParam )
                }

           #endregion Bakup location

           #region Instance(s) configuration

                $AvailabilityGroupCurrentProperty.InstanceName | ForEach-Object -Process {

                    $InstanceAddressCurrent = Resolve-dnsNameEx -Name $psItem

                    $ObjectParam = @{

                        TypeName     = 'Microsoft.SQLServer.Management.SMO.Server'
                        ArgumentList = $InstanceAddressCurrent
                    }
                    $InstanceCurrent = New-Object @ObjectParam

                    $Instance.Add( $InstanceCurrent )
                                          
                    icacls.exe "$BackupPath" /grant:r """$($InstanceCurrent.ServiceAccount)"":(OI)(CI)F"

                    $Endpoint = $InstanceCurrent.Endpoints |
                        Where-Object -FilterScript {
                            $psItem.EndpointType -eq 'DatabaseMirroring'
                        }

                    If
                    (
                        $Endpoint
                    )
                    {
                        $Message = "Endpoint `“$($Endpoint.Name)`” already exists"
                        Write-Verbose -Message $Message
                    }
                    Else
                    {
                        $Message = "Creating Endpoint for `“$( $InstanceCurrent.Name )`”"
                        Write-Verbose -Message $Message

                     <# As per cmdlet help, it should accept “-InputObject”
                        parameter which “Specifies the server object of the SQL
                        Server instance.” However, this does not seem to work.

                        https://docs.microsoft.com/en-us/powershell/module/sqlserver/enable-sqlalwayson
                        #>

                        $AlwaysOnParam = @{

                          # InputObject      = $InstanceCurrent
                            ServerInstance   = $InstanceCurrent.DomainInstanceName
                            NoServiceRestart = $True
                            Verbose          = $False
                        }
                        Enable-SqlAlwaysOn @AlwaysOnParam

                        $ClusterGroup = Get-ClusterGroup -InputObject $Cluster |
                            Where-Object -FilterScript {

                                $psItem.Name -like "*$( $InstanceCurrent.InstanceName )*" -or
                                $psItem.Name -like "*$( $InstanceCurrent.Name )*"
                            }

                        [System.Void]( Stop-ClusterGroup  -InputObject $ClusterGroup )
                        [System.Void]( Start-ClusterGroup -InputObject $ClusterGroup )

                        $HadrEndpointParam = @{

                            InputObject = $InstanceCurrent
                            Name        = 'AlwaysOn'
                            Verbose     = $False
                        }
                        $Endpoint = New-SqlHadrEndpoint @HadrEndpointParam

                     <# This is now handled by "New-NetFirewallRuleExSqlServer"
                        Create Windows Firewall rule for AlwaysOn Endpoint

                        $Cluster            = Get-Cluster -Name $InstanceCurrent.Information.FullyQualifiedNetName
                        $ClusterNode        = Get-ClusterNode -Cluster $Cluster
                        $ClusterNodeName    = $ClusterNode.Name
                        $ClusterNodeAddress = Resolve-DnsNameEx -Name $ClusterNodeName
                        $ServiceAll         = Get-WmiObject -Class "win32_service" -ComputerName $InstanceCurrent.Information.FullyQualifiedNetName
                        $ServiceSQL         = $ServiceAll | Where-Object -FilterScript {
                            ( $psItem.Name -like ( "MSSQL`$" + $InstanceCurrent.InstanceName ) ) -and
                            ( $psItem.State -eq "Running" )
                        }

                        $ServiceName           = $ServiceSQL.Name
                        $ServiceDisplayName    = $ServiceSQL.DisplayName
                        $ServicePath           = (( $ServiceSQL.PathName -split """ -s" )[0]).TrimStart( """" )

                        $NewNetFirewallRuleParam  = @{

                            DisplayName = $ServiceDisplayName + " — AlwaysOn Endpoint"
                            Service     = $ServiceName
                            Program     = $ServicePath
                            LocalPort   =  5022
                            Enabled     = "True"
                            Profile     = "Domain"
                            Direction   = "Inbound"
	                        Action      = "Allow"
	                        Protocol    = "TCP"
                            CimSession  = $ClusterNodeAddress
                        }
                        $NetFirewallRule = New-NetFirewallRule @NewNetFirewallRuleParam  #>

                      # Convert Service accountLogin Name from FQDN notation
                      # to a flat name
                      
                        $LoginAddress = $InstanceCurrent.ServiceAccount

                        $LoginName  = [System.String]::Empty
                        $LoginName += ( $LoginAddress.Split( '\' )[0] ).Split( '.' )[0]
                        $LoginName += '\'
                        $LoginName += $LoginAddress.Split( '\' )[1]

                      # Grant nesessary permissions
                      # http://support.microsoft.com/help/2847723

                        $Query = @"
CREATE LOGIN [$LoginName] FROM WINDOWS
GRANT CONNECT ON ENDPOINT::[AlwaysOn] TO [$LoginName]
GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM] AS SA
GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM] AS SA
GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM] AS SA
"@

                        $CmdParam = @{

                            ServerInstance = $InstanceCurrent
                            Query          = $Query
                            Verbose        = $False
                        }
                        Invoke-SqlCmd @CmdParam

                     <# Invoke-SqlCmd -ServerInstance $InstanceCurrent -Verbose:$False -Query "CREATE LOGIN [$LoginName] FROM WINDOWS"
                        Invoke-SqlCmd -ServerInstance $InstanceCurrent -Verbose:$False -Query "GRANT CONNECT ON ENDPOINT::[AlwaysOn] TO [$LoginName]"
                      # Invoke-SqlCmd -ServerInstance $InstanceCurrent -Verbose:$False -Query "CREATE LOGIN [NT AUTHORITY\SYSTEM] FROM WINDOWS"
                        Invoke-SqlCmd -ServerInstance $InstanceCurrent -Verbose:$False -Query "GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM] AS SA"
                        Invoke-SqlCmd -ServerInstance $InstanceCurrent -Verbose:$False -Query "GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM] AS SA"
                        Invoke-SqlCmd -ServerInstance $InstanceCurrent -Verbose:$False -Query "GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM] AS SA"
                        #>
                    }

                    $Message = "Starting Endpoint `“$($Endpoint.Name)`”"
                    Write-Verbose -Message $Message

                    $HadrEndpointParam = @{

                        InputObject = $Endpoint
                        State       = 'Started'
                        Verbose     = $False
                    }
                    $Endpoint = Set-SqlHadrEndpoint @HadrEndpointParam

                 <# The below creates an “Availability Replica” object as a
                    “Template” to be used when creating new “Availabiltiy Group”
                    next. However, if the “Availabiltiy Group” already exists, 
                    we no longer use “Templates” to add more “Availability
                    Replicas.” Hence, the “Template” object will be ignored.
                    Instead we will create a “live” configuration object for 
                    “Availability Replica” later directly in the existing 
                    “Availabiltiy Group”.  #>
         
                    $EndpointAddress          = $InstanceCurrent.Information.FullyQualifiedNetName
                    $EndpointPort             = $Endpoint.Protocol.Tcp.ListenerPort
                    $EndpointURL              = "TCP://${EndpointAddress}:${EndpointPort}"

                    $AvailabilityReplicaName  = [System.String]::Empty
                    $AvailabilityReplicaName += $InstanceCurrent.Information.NetName
                    $AvailabilityReplicaName += '\'
                    $AvailabilityReplicaName += $InstanceCurrent.InstanceName

                    $Message = "Creating Availability Replica `“$AvailabilityReplicaName`”"
                    Write-Verbose -Message $Message

                  # Note: This is a Failover Cluster Instance (FCI). Failover
                  # Cluster Instances do not support automatic failover for
                  # Always On Availability Groups

                    $AvailabilityReplicaParam = @{

                        Name                          = $AvailabilityReplicaName
                        EndpointUrl                   = $EndpointURL
                        AvailabilityMode              = 'SynchronousCommit'
                        FailoverMode                  = 'Manual'
                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                        ConnectionModeInSecondaryRole = 'AllowNoConnections'
                        Version                       = $InstanceCurrent.Version
                        AsTemplate                    = $True
                        Verbose                       = $False
                    }
                    $AvailabilityReplicaCurrent = New-SqlAvailabilityReplica @AvailabilityReplicaParam
            
                    $AvailabilityReplica.Add( $AvailabilityReplicaCurrent )
                }

                $Message = "We have $($AvailabilityReplica.Count) Replica(s)"
                Write-Verbose -Message $Message

           #endregion Instance(s) configuration

           #region Select Instance(s)

              # To-Do: Look which instance has the databases from the list specified in
              # and make sure the database is primary

                $AvailabilityGroupCurrentProperty.DatabaseName

                $InstanceDatabase = $Instance | Where-Object -FilterScript {
                    $psItem.AvailabilityGroups[ $Name ]
                } | Sort-Object | Select-Object -First 1

              # To-Do: select the current primary replica

                $InstanceAvailabilityGroup = $Instance | Where-Object -FilterScript {
                    $psItem.AvailabilityGroups[ $Name ]
                } | Sort-Object | Select-Object -First 1

                If
                (
                    $InstanceDatabase
                )
                {
                    $Message = "Database already exists on Instance `“$( $InstanceDatabase.Name )`”"
                    Write-Verbose -Message $Message

                    $InstancePrimary = $InstanceDatabase
                }
                ElseIf
                (
                    $InstanceAvailabilityGroup
                )
                {
                    $Message = "Availability group already exists on Instance `“$( $InstanceAvailabilityGroup.Name )`”"
                    Write-Verbose -Message $Message

                    $InstancePrimary = $InstanceAvailabilityGroup
                }
                Else
                {
                    $InstancePrimary = $Instance | Sort-Object |
                        Select-Object -First 1

                    $Message = "Instance `“$( $InstancePrimary.Name )`” is selected as the first (`“Primary`”) replica for Availability Group"
                    Write-Verbose -Message $Message
                }

                $InstanceSecondary = $Instance | Where-Object -FilterScript {
                    $psItem -ne $InstancePrimary
                }

           #endregion Select Instance(s)

           #region Database

             <# Obsolete:

              # You cannot instantiate an “empty”, Availability Group i.e. with
              # no databases. It is also necessary when adding new Availability
              # Replicas. Hence, if no database name is provided, we create a 
              # dummy temporary database. It can be safely deleted later, when 
              # any “real” databases are created and added to the Availability 
              # Group  #>

                $AvailabilityGroupCurrentProperty.DatabaseName |
                    ForEach-Object -Process {

                    $DatabaseName = $psItem

                   #region Path

                        $PathParam = @{

                            Path      = $BackupPath
                            ChildPath = "$DatabaseName.bak"
                        }
                        $BackupPathDatabase = Join-Path @PathParam

                        $PathParam = @{

                            Path      = $BackupPath
                            ChildPath = "$DatabaseName.trn"
                        }
                        $BackupPathLog = Join-Path @PathParam

                      # We need to clean up the older backups because if there are any,
                      # it can interfere with replica seeding procedure
        
                        If
                        (
                            Test-Path   -Path $BackupPathDatabase
                        )
                        {
                            Remove-Item -Path $BackupPathDatabase
                        }

                        If
                        (
                            Test-Path   -Path $BackupPathLog
                        )
                        {
                            Remove-Item -Path $BackupPathLog
                        }
                    
                   #endregion Path

                   #region Obtain

                        $DatabaseParam = @{

                            InputObject = $InstancePrimary
                            Verbose     = $False
                        }

                        If
                        (            
                            Get-SqlDatabase @DatabaseParam | Where-Object -FilterScript {
                                $psItem.Name -eq $DatabaseName
                            }
                        )
                        {
                            $Message = "Database `“$DatabaseName`” already exists"
                            Write-Verbose -Message $Message

                            If
                            (
                                $Database.AvailabilityGroupName
                            )
                            {
                                $Message = "Database $DatabaseCurrentName already participates in Availability Group `“$($Database.AvailabilityGroupName)`”"
                                Write-Verbose -Message $Message
                            }
                            Else
                            {
                              # Set Database Recovery Mode to “Full”,
                              # as required for AlwaysOn Availability Group
        
                                $Query = "ALTER DATABASE [$psItem] SET RECOVERY FULL"

                                $CmdParam = @{

                                    ServerInstance       = $InstancePrimary
                                    Database             = 'Master'
                                    Query                = $Query
                                    AbortOnError         = $True
                                  # IncludeSqlUserErrors = $True
                                    OutputSqlErrors      = $True
                                    Verbose              = $False
                                }
                                Invoke-Sqlcmd @CmdParam
                            }
                        }
                        Else
                        {
                            $Message = 'Creating temporary database for replica seeding'
                            Write-Verbose -Message $Message

                            $CmdParam = @{

                                ServerInstance = $InstancePrimary
                                Query          = "CREATE database `"$DatabaseName`""
                                Verbose        = $False
                            }
                            Invoke-SqlCmd @CmdParam
                        }

                   #endregion Obtain

                   #region Backup

                        $DatabaseParam = @{
                                    
                            Database     = $DatabaseName
                            BackupFile   = $BackupPathDatabase
                            InputObject  = $InstancePrimary
                            Verbose      = $False
                        }
                        Backup-SqlDatabase @DatabaseParam

                        $DatabaseParam = @{

                            Database     = $DatabaseName
                            BackupAction = 'Log'
                            BackupFile   = $BackupPathLog
                            InputObject  = $InstancePrimary
                            Verbose      = $False
                        }
                        Backup-SqlDatabase @DatabaseParam

                   #endregion Backup
                }

           #endregion Database

           #region Availability Group

                $AvailabilityGroupCurrent =
                    $InstancePrimary.AvailabilityGroups[ $Name ]

                If
                (
                    $AvailabilityGroupCurrent
                )
                {
                    $Message = "Availability Group `“$Name`” already exists"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $AvailabilityGroupParam = @{

                        Name                = $Name
                        InputObject         = $InstancePrimary
                        AvailabilityReplica = $AvailabilityReplica
                        Database            = $AvailabilityGroupCurrentProperty.DatabaseName
                        Verbose             = $False
                    }

                    $Message = "Creating Availability Group `“$Name`”"
                    Write-Verbose -Message $Message

                 <# $AvailabilityGroupParam.GetEnumerator() | ForEach-Object -Process {
                        Write-Verbose -Message "$($psItem.Name): $($psItem.Value)"
                    }  #>

                    $AvailabilityGroupCurrent = New-SqlAvailabilityGroup @AvailabilityGroupParam
                }

                $AvailabilityGroupAll.Add( $AvailabilityGroupCurrent )

           #endregion Availability Group

           #region Listener

                $AvailabilityGroupListener =
                    $AvailabilityGroupCurrent.AvailabilityGroupListeners[ $Name ]

                If
                (
                    $AvailabilityGroupListener
                )
                {
                    $Message = "Availability Group Listener `“$Name`” already exists"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $Message = "Creating Availability Group Listener `“$Name`”"
                    Write-Verbose -Message $Message

                    $StaticIp = [System.Collections.Generic.List[System.String]]::new()

                    $AvailabilityGroupCurrentProperty.ipAddress | ForEach-Object -Process {

                        $StaticIpCurrent  = [System.String]::Empty
                        $StaticIpCurrent += $psItem
                        $StaticIpCurrent += '/'
                        $StaticIpCurrent += $Network.AddressMask

                        $StaticIp.Add( $StaticIpCurrent )
                    }

                    $AvailabilityGroupListenerParam = @{
            
                        InputObject = $AvailabilityGroupCurrent
                        Name        = $Name
                        StaticIp    = $StaticIp
                        Verbose     = $False
                    }
                    $AvailabilityGroupListener =
                        New-SqlAvailabilityGroupListener @AvailabilityGroupListenerParam
                }

           #endregion Listener

           #region IP Address

                $AvailabilityGroupCurrentProperty.ipAddress | ForEach-Object -Process {

                    If
                    (
                        $psItem -in $AvailabilityGroupListener.AvailabilityGroupListenerIPAddresses.ipAddress
                    )
                    {
                        $Message = "IP Address `“$psItem`” already exists"
                        Write-Verbose -Message $Message
                    }
                    Else
                    {
                        $Message = "Adding IP Address `“$psItem`”"
                        Write-Verbose -Message $Message

                        $StaticIpCurrent  = [System.String]::Empty
                        $StaticIpCurrent += $psItem
                        $StaticIpCurrent += '/'
                        $StaticIpCurrent += $Network.AddressMask

                        $ListenerStaticIpParam = @{
                    
                            StaticIp    = $StaticIpCurrent
                            InputObject = $AvailabilityGroupListener
                            Verbose     = $False
                        }
                        Add-SqlAvailabilityGroupListenerStaticIp @ListenerStaticIpParam
                    }
                }

           #endregion IP Address

           #region Secondary Member(s)

                $InstanceSecondary | ForEach-Object -Process {

                    $InstanceCurrent = $psItem

                   #region Availability Group

                        If
                        (
                            $InstanceCurrent.AvailabilityGroups[ $Name ]
                        )
                        {
                            $Message = "Instance `“$( $InstanceCurrent.Name )`” already participates in Availability Group"
                            Write-Verbose -Message $Message
                        }
                        Else
                        {
                           #region Endpoint

                                $Endpoint = $InstanceCurrent.Endpoints |
                                    Where-Object -FilterScript {
                                        $psItem.EndpointType -eq 'DatabaseMirroring'
                                    }

                                $EndpointAddress            = $InstanceCurrent.Information.FullyQualifiedNetName
                                $EndpointPort               = $Endpoint.Protocol.Tcp.ListenerPort
                                $EndpointURL                = "TCP://${EndpointAddress}:${EndpointPort}"
                        
                                $AvailabilityReplicaName    = [System.String]::Empty
                                $AvailabilityReplicaName   += $InstanceCurrent.Information.NetName
                                $AvailabilityReplicaName   += '\'
                                $AvailabilityReplicaName   += $InstanceCurrent.InstanceName

                           #endregion Endpoint

                           #region Availability Replica

                                $AvailabilityReplicaCurrent =
                                    $AvailabilityGroupCurrent.AvailabilityReplicas[ $AvailabilityReplicaName ]

                                If
                                (
                                    $AvailabilityReplicaCurrent
                                )
                                {
                                    $Message = "Availability Replica `“$AvailabilityReplicaName`” already exists"
                                    Write-Verbose -Message $Message
                                }
                                Else
                                {
                                    $Message = "Creating Availability Replica `“$AvailabilityReplicaName`”"
                                    Write-Verbose -Message $Message

                                  # Note: This is a Failover Cluster Instance (FCI). Failover
                                  # Cluster Instances do not support automatic failover for
                                  # Always On Availability Groups

                                    $AvailabilityReplicaParam = @{

                                        InputObject                   = $AvailabilityGroupCurrent
                                        Name                          = $AvailabilityReplicaName
                                        EndpointUrl                   = $EndpointURL
                                        AvailabilityMode              = 'SynchronousCommit'
                                        FailoverMode                  = 'Manual'
                                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                                        ConnectionModeInSecondaryRole = 'AllowNoConnections'
                                      # Version                       = $InstanceCurrent.Version
                                      # AsTemplate                    = $True
                                      # BackupPriority                = 0
                                        Verbose                       = $False
                                    }
                                    $AvailabilityReplicaCurrent =
                                        New-SqlAvailabilityReplica @AvailabilityReplicaParam
                        
                                    $Message = "Adding Instance `“$($InstanceCurrent.Name)`” to Availability Group"
                                    Write-Verbose -Message $Message
                                }

                           #endregion Availability Replica

                           #region Join

                                $AvailabilityGroupParam = @{
                
                                    InputObject = $InstanceCurrent
                                    Name        = $Name
                                    Verbose     = $False
                                }
                                Join-SqlAvailabilityGroup @AvailabilityGroupParam

                           #endregion Join
                        }

                        $AvailabilityGroupCurrent = $InstanceCurrent.AvailabilityGroups[ $Name ]

                   #endregion Availability Group

                   #region Database

                        $AvailabilityGroupCurrentProperty.DatabaseName |
                            ForEach-Object -Process {

                            $DatabaseName = $psItem

                           #region Path

                                $PathParam = @{

                                    Path      = $BackupPath
                                    ChildPath = "$DatabaseName.bak"
                                }
                                $BackupPathDatabase = Join-Path @PathParam

                                $PathParam = @{

                                    Path      = $BackupPath
                                    ChildPath = "$DatabaseName.trn"
                                }
                                $BackupPathLog = Join-Path @PathParam
                  
                           #endregion Path

                           #region Relocate

                             <# Different Availability Replicas can have distinct 
                                default database paths. This is particularly special
                                to Failover Clusers using Clusgter Shared Volumes (CSV)
                                because CSV namespace is shared across all cluster nodes,
                                and hence each CSV path should be unique, cluster-wide.
                                Note that we restore database into default path  #>

                                $RelocateFile =
                                    [System.Collections.Generic.List[Microsoft.SqlServer.Management.Smo.RelocateFile]]::new()
                            
                              # Relocate Data

                                $PathParam = @{
                        
                                    Path      = $InstanceCurrent.Information.MasterDBPath
                                    ChildPath = "$DatabaseName.mdf"
                                }
                                $RelocateDataPath = Join-Path @PathParam

                                $Argument = @(
                                    $DatabaseName
                                    $RelocateDataPath
                                )

                                $ObjectParam = @{

                                    TypeName     = 'Microsoft.SqlServer.Management.Smo.RelocateFile'
                                    ArgumentList = $Argument
                                }
                                $RelocateFile.Add( ( New-Object @ObjectParam ) )

                              # Relocate Log

                                $PathParam = @{

                                    Path      = $InstanceCurrent.Information.MasterDBLogPath
                                    ChildPath = "$($DatabaseName)_log.ldf"
                                }
                                $RelocateLogPath  = Join-Path @PathParam

                                $Argument = @(
                                    "$($DatabaseName)_log"
                                    $RelocateLogPath
                                )

                                $ObjectParam = @{

                                    TypeName     = 'Microsoft.SqlServer.Management.Smo.RelocateFile'
                                    ArgumentList = $Argument
                                }
                                $RelocateFile.Add( ( New-Object @ObjectParam ) )

                           #endregion Relocate

                           #region Restore

                                $Message = "Restoring seeding database on Instance `“$($InstanceCurrent.Name)`”"
                                Write-Verbose -Message $Message

                                $DatabaseParam = @{

                                    Database     = $DatabaseName
                                    BackupFile   = $BackupPathDatabase
                                    NoRecovery   = $True
                                    RelocateFile = $RelocateFile
                                    InputObject  = $InstanceCurrent
                                    Verbose      = $False
                                }
                                Restore-SqlDatabase @DatabaseParam

                                $DatabaseParam = @{

                                    Database      = $DatabaseName
                                    BackupFile    = $BackupPathLog                        
                                    NoRecovery    = $True
                                    RestoreAction = 'Log'
                                    InputObject   = $InstanceCurrent
                                    Verbose       = $False
                                }
                                Restore-SqlDatabase @DatabaseParam

                           #endregion Restore

                           #region Add

                                $Message = "Adding Availability Database replica to Availability Group"
                                Write-Verbose -Message $Message

                                $AvailabilityDatabaseParam = @{

                                    InputObject = $AvailabilityGroupCurrent
                                    Database    = $DatabaseName
                                    Verbose     = $False
                                }
                                Add-SqlAvailabilityDatabase @AvailabilityDatabaseParam

                           #endregion Add
                        }

                   #endregion Database
                }
                
           #endregion Secondary Member(s)
        }
    }

    End
    {
        Return $AvailabilityGroupAll
    }
}