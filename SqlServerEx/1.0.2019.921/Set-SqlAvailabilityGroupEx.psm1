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
        [System.Collections.Hashtable]
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
            [System.Collections.Generic.List[
                Microsoft.SqlServer.Management.Smo.AvailabilityGroup
            ]]::new()

      # $Module = Import-ModuleEx -Name "C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\SQLPS.PSD1"
      # $Module = Import-ModuleEx -Name "SqlServer"
      # $Module = Import-ModuleEx -Name $env:USERPROFILE\Downloads\SqlServer\21.0.17199\SqlServer.psd1
    }

    Process
    {        
        $AvailabilityGroup.GetEnumerator() | ForEach-Object -Process {

           #region Variable

                $Name                      = $psItem.Key
                $AvailabilityGroupProperty = $psItem.Value

                Write-Verbose -Message '***'
                $Message = "Configuring Availability Group `“$Name`”"
                Write-Verbose -Message $Message

                $Instance            =
                    [System.Collections.Generic.List[
                        Microsoft.SqlServer.Management.Smo.Server
                    ]]::new()

                $AvailabilityReplica =
                    [System.Collections.Generic.List[
                        Microsoft.SqlServer.Management.Smo.AvailabilityReplica
                    ]]::new()

                $NameParam = @{
                    Name = @( $AvailabilityGroupProperty.Instance.GetEnumerator() )[0].Key
                }

                $ClusterAddress = Resolve-dnsNameEx @NameParam
                $Cluster        = Get-Cluster -Name $ClusterAddress

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
              # found), hence an existing backup location can be reused as well

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

             <# Prerequisistes for configuring Availability Group or other
                configuration actions which apply equally to all instances
                (i.e. where it does not matter which instance is currently
                “Primary”)  #>

                $AvailabilityGroupProperty.Instance.GetEnumerator() | ForEach-Object -Process {

                    $InstanceAddressCurrent = Resolve-dnsNameEx -Name $psItem.Key

                    $ObjectParam = @{

                        TypeName     = 'Microsoft.SQLServer.Management.SMO.Server'
                        ArgumentList = $InstanceAddressCurrent
                    }
                    $InstanceCurrent = New-Object @ObjectParam

                    $Instance.Add( $InstanceCurrent )
                }

                $Instance | ForEach-Object -Process {

                    $InstanceCurrent = $psItem

                    [System.Void]( icacls.exe "$BackupPath" /grant:r """$($InstanceCurrent.ServiceAccount)"":(OI)(CI)F" )

                   #region Mirroring Endpoint

                        $Endpoint = $InstanceCurrent.Endpoints |
                            Where-Object -FilterScript {
                                $psItem.EndpointType -eq 'DatabaseMirroring'
                            }

                        If
                        (
                            $Endpoint
                        )
                        {
                            $Message = "`“Database Mirroring`” Endpoint `“$($Endpoint.Name)`” already exists"
                            Write-Verbose -Message $Message
                        }
                        Else
                        {
                            $Message = "Creating `“Database Mirroring`” Endpoint for `“$( $InstanceCurrent.Name )`”"
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

                                ServerInstance       = $InstanceCurrent
                                Query                = $Query
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
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

                   #endregion Mirroring Endpoint

                   #region Availability Replica

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
                            ConnectionModeInSecondaryRole = 'AllowAllConnections'
                          # ConnectionModeInSecondaryRole = 'AllowNoConnections'                        
                            Version                       = $InstanceCurrent.Version
                            AsTemplate                    = $True
                            Verbose                       = $False
                        }
                        $AvailabilityReplicaCurrent = New-SqlAvailabilityReplica @AvailabilityReplicaParam
            
                        $AvailabilityReplica.Add( $AvailabilityReplicaCurrent )

                   #endregion Availability Replica

                   #region Service Broker Endpoint

                        $Endpoint = $InstanceCurrent.Endpoints |
                            Where-Object -FilterScript {
                                $psItem.EndpointType -eq 'ServiceBroker'
                            }

                        If
                        (
                            $Endpoint
                        )
                        {
                            $Message = "`“Service Broker`” Endpoint `“$($Endpoint.Name)`” already exists"
                            Write-Verbose -Message $Message
                        }
                        Else
                        {
                            $Message = "Creating `“Service Broker`” Endpoint for `“$( $InstanceCurrent.Name )`”"
                            Write-Verbose -Message $Message

                            $Query = @"
Create Endpoint [SsbEndpoint]
    State = Started
    As TCP ( Listener_Port = 4022, Listener_IP = All )
    For Service_Broker ( Authentication = Windows )

Grant Connect on Endpoint::[SsbEndpoint] to [Public]
"@

                            $CmdParam = @{

                                ServerInstance       = $InstanceCurrent
                                Query                = $Query
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            Invoke-SqlCmd @CmdParam
                        }

                   #endregion Service Broker Endpoint
                
                   #region Custom Script(s), e.g. for SysMessages
                        
                        $AvailabilityGroupProperty.Script +

                      # Creates the “Sync Logins” procedure
                        '.\ag-sync-master\SyncLogins.sql' | ForEach-Object -Process {

                            $Message = "  * Running Script `“$psItem`” on `“$($InstanceCurrent.Name)`”"
                            Write-Verbose -Message $Message

                            $Path = ( Get-Item -Path $psItem ).FullName

                            $CmdParam = @{

                                ServerInstance       = $InstanceCurrent
                                InputFile            = $Path
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            Invoke-SqlCmd @CmdParam
                        }

                   #endregion Custom Script(s), e.g. for SysMessages

                   #region Linked Servers

                      # This is a prerequisite for “Sync Logins” procedure

                        $Instance | Where-Object -FilterScript {
                            $psItem -ne $InstanceCurrent
                        } | ForEach-Object -Process {

                            $Query = "select * from sys.servers where name = '$($psItem.Name)'"

                            $CmdParam = @{

                                ServerInstance       = $InstanceCurrent
                                Query                = $Query
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            
                            If
                            (
                                Invoke-SqlCmd @CmdParam
                            )
                            {
                                $Message = "Linked Server `“$($psItem.Name)`” already exists on `“$($InstanceCurrent.Name)`”"
                                Write-Verbose -Message $Message
                            }
                            Else
                            {
                                $Message = "Creating Linked Server `“$($psItem.Name)`” on `“$($InstanceCurrent.Name)`”"
                                Write-Verbose -Message $Message

                                $Query = @"
                                
                                    Exec sp_AddLinkedServer
                                        @Server     = '$($psItem.Name)',
                                        @SrvProduct = 'SQL Server'
                                     -- @SrvProduct = '',
                                     -- @Provider   = 'SqlNcli',
                                     -- @DataSrc    = '$($psItem.Name)',
                                     -- @ProvStr    = 'Integrated Security=SSPI;';
"@

                                $CmdParam = @{

                                    ServerInstance       = $InstanceCurrent
                                    Query                = $Query
                                    AbortOnError         = $True
                                    OutputSqlErrors      = $True
                                    IncludeSqlUserErrors = $True
                                    Verbose              = $False
                                }
                                Invoke-SqlCmd @CmdParam
                            }
                        }

                   #endregion Linked Servers
                }

                $Message = "Total number of Availability Replica(s) defined in configuration: $($AvailabilityReplica.Count)"
                Write-Verbose -Message $Message

           #endregion Instance(s) configuration

           #region Select Instance(s)

                $InstanceAvailabilityGroup = $Instance | Where-Object -FilterScript {
                    $psItem.AvailabilityGroups[ $Name ]
                }

                If
                (
                    $InstanceAvailabilityGroup
                )
                {
                    $Message = "Availability Group `“$Name`” already exists on Instance(s):"
                    Write-Verbose -Message $Message

                    $InstanceAvailabilityGroup | ForEach-Object -Process {

                        $Message = "  * $($psItem.Name)"
                        Write-Verbose -Message $Message
                    }

                  # Instance(s) that have existing Databases added to Availability Group

                    $InstanceDatabaseAvailabilityGroup = $InstanceAvailabilityGroup | Where-Object -FilterScript {

                        $InstancePrimary = $psItem

                        $AvailabilityGroupProperty.DatabaseName.GetEnumerator() | ForEach-Object -Process {

                            $Database = $InstancePrimary.AvailabilityGroups[ $Name ].AvailabilityDatabases[ $psItem.Key ]

                            $Database -and $Database.SynchronizationState -eq 'Synchronized'

                        } | Select-Object -First 1
                    }

                  # Instance(s) that have existing Databases not yet added to Availability Group

                    $InstanceDatabase = $InstanceAvailabilityGroup | Where-Object -FilterScript {

                        $InstancePrimary = $psItem

                        $AvailabilityGroupProperty.DatabaseName.GetEnumerator() | ForEach-Object -Process {

                            $InstancePrimary.Databases[ $psItem.Key ]

                        } | Select-Object -First 1
                    }

                    If
                    (
                        $InstanceDatabaseAvailabilityGroup
                    )
                    {
                        $Message = "Database already exists on Instance(s) and added to the Availability Group:"
                        Write-Verbose -Message $Message

                        $InstanceDatabaseAvailabilityGroup | ForEach-Object -Process {

                            $Message = "  * $($psItem.Name)"
                            Write-Verbose -Message $Message
                        }

                        $InstancePrimary = $InstanceDatabaseAvailabilityGroup | Where-Object -FilterScript {
                        
                            $psItem.AvailabilityGroups[ $Name ].LocalReplicaRole -eq 'Primary'
                        }
                    }

                 <# This is potentially ambigous scenario because the same 
                    database on multiple instances is either result of an
                    error, or previous Availability Group participation. In
                    theory we should look which copy of the database is the 
                    latest, and then forcibly delete the copy which appears
                    stale. However, it's too much work for what seems to be
                    a corner case, so we'd skip it for now  #>

                    ElseIf
                    (
                        $InstanceDatabase
                    )
                    {
                        $Message = "Database already exists on Instance(s), but not added to the Availability Group:"
                        Write-Verbose -Message $Message

                        $InstanceDatabase | ForEach-Object -Process {

                            $Message = "  * $($psItem.Name)"
                            Write-Verbose -Message $Message
                        }

                        $InstancePrimary = $InstanceDatabase | Sort-Object | Select-Object -First 1
                    }
                    
                 <# No databases were detected, so it's relatively safe to assume
                    that any Instance can be primary for now  #>

                    Else
                    {
                        $InstancePrimary = $InstanceAvailabilityGroup | Sort-Object | Select-Object -First 1
                    }

                    If
                    (
                        $InstancePrimary.AvailabilityGroups[ $Name ].LocalReplicaRole -eq 'Primary'
                    )
                    {
                        $Message = "Instance `“$( $InstancePrimary.Name )`” is already the `“Primary`” replica for Availability Group `“$Name`”"
                        Write-Verbose -Message $Message
                    }
                    Else
                    {
                        $AvailabilityGroupParam = @{
                    
                            InputObject = $InstancePrimary.AvailabilityGroups[ $Name ]
                            Verbose     = $False
                        }
                        Switch-SqlAvailabilityGroup @AvailabilityGroupParam
                    }
                }
                Else
                {
                    $InstancePrimary = $Instance | Sort-Object | Select-Object -First 1
                }

                $Message = "Instance `“$( $InstancePrimary.Name )`” is selected as the initial (`“Primary`”) replica for Availability Group `“$Name`”"
                Write-Verbose -Message $Message
                
                $Message = "Addtional (`“Secondary`”) replica(s):"
                Write-Verbose -Message $Message

                $Instance | Where-Object -FilterScript {
                    $psItem -ne $InstancePrimary
                } | ForEach-Object -Process {

                    $Message = "  * $($psItem.Name)"
                    Write-Verbose -Message $Message
                }

           #endregion Select Instance(s)

           #region Database

             <# This prepares existing databases to be used in Availability
                Group. It includes creating the database if it does not exist
                yet. (This helps to instantiate and validate the Availability
                Group if there are no real databases yet.)
                
                These databases can be safely deleted later and replaced with 
                “real” production databases. In this case, the script should
                be re-run later on, so that newly created databases get 
                configured correctly and added to the Availability Group  #>

             <# Obsolete:

              # You cannot instantiate an “empty”, Availability Group i.e. with
              # no databases. It is also necessary when adding new Availability
              # Replicas. Hence, if no database name is provided, we create a 
              # dummy temporary database. It can be safely deleted later, when 
              # any “real” databases are created and added to the Availability 
              # Group  #>

                $AvailabilityGroupProperty.DatabaseName.GetEnumerator() |
                    ForEach-Object -Process {

                    $DatabaseName = $psItem.Key

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

                        $Database = Get-SqlDatabase @DatabaseParam |
                            Where-Object -FilterScript {
                                $psItem.Name -eq $DatabaseName
                            }

                        If
                        (            
                            $Database
                        )
                        {
                            $Message = "Database `“$DatabaseName`” already exists"
                            Write-Verbose -Message $Message

                            If
                            (
                                $Database.AvailabilityGroupName
                            )
                            {
                                $Message = "Database `“$DatabaseName`” already participates in Availability Group `“$($Database.AvailabilityGroupName)`”"
                                Write-Verbose -Message $Message
                            }
                            Else
                            {
                              # Set Database Recovery Mode to “Full”,
                              # as required for AlwaysOn Availability Group
        
                                $Query = "ALTER DATABASE [$DatabaseName] SET RECOVERY FULL"

                                $CmdParam = @{

                                    ServerInstance       = $InstancePrimary
                                  # Database             = 'Master'
                                    Query                = $Query
                                    AbortOnError         = $True
                                    IncludeSqlUserErrors = $True
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

                            $Query = "CREATE database `"$DatabaseName`""

                            $CmdParam = @{

                                ServerInstance       = $InstancePrimary
                                Query                = $Query
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            Invoke-SqlCmd @CmdParam
                        }

                   #endregion Obtain

                   #region Property

                        $psItem.Value.GetEnumerator() | ForEach-Object -Process {

                            $Query = "Select $($psItem.Key) From sys.databases where name = '$DatabaseName'"

                            $CmdParam = @{

                                ServerInstance       = $InstancePrimary
                                Query                = $Query                                
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            $Out = Invoke-SqlCmd @CmdParam    
    
                            If
                            (
                                $Out.$($psItem.Key)
                            )
                            {
                                $Message = "  * Database `“$DatabaseName`” already has `“$($psItem.Key)`” on `“$($InstancePrimary.Name)`”"
                                Write-Verbose -Message $Message
                            }
                            Else
                            {
                                $Message = "  * Setting `“$($psItem.Value)`” on database `“$DatabaseName`” on `“$($InstancePrimary.Name)`”"
                                Write-Verbose -Message $Message

                                $Query = "Alter Database '$DatabaseName' set $($psItem.Value)"

                                $CmdParam = @{

                                    ServerInstance       = $InstancePrimary
                                    Query                = $Query                                    
                                    AbortOnError         = $True
                                    OutputSqlErrors      = $True
                                    IncludeSqlUserErrors = $True
                                    Verbose              = $False
                                }
                                Invoke-SqlCmd @CmdParam
                            }
                        }                    

                   #endregion Property

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

               #region Create

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
                            Database            = $AvailabilityGroupProperty.DatabaseName.Keys
                            Verbose             = $False
                        }

                        $Message = "Creating Availability Group `“$Name`”"
                        Write-Verbose -Message $Message

                     <# $AvailabilityGroupParam.GetEnumerator() | ForEach-Object -Process {
                            Write-Verbose -Message "$($psItem.Name): $($psItem.Value)"
                        }  #>

                        $AvailabilityGroupCurrent = New-SqlAvailabilityGroup @AvailabilityGroupParam
                    }

               #endregion Create

               #region Configure

                    $AvailabilityGroupParam = @{

                        InputObject               = $AvailabilityGroupCurrent
                        AutomatedBackupPreference = 'Secondary'
                        DatabaseHealthTrigger     = $True
                        FailureConditionLevel     = 'OnAnyQualifiedFailureCondition'
                        Verbose                   = $False
                    }
                    Set-SqlAvailabilityGroup @AvailabilityGroupParam

               #endregion Configure

               #region Automatic Seeding

                 <# $Query = @"

Alter Availability Group [$Name]
    Grant Create Any Database
"@

                    $CmdParam = @{

                        ServerInstance = $InstancePrimary
                        Query          = $Query
                        Verbose        = $False
                    }
                    Invoke-SqlCmd @CmdParam  #>

                    $CreateAnyDatabaseParam = @{

                        InputObject = $AvailabilityGroupCurrent
                        Verbose     = $False
                    }
                    Grant-SqlAvailabilityGroupCreateAnyDatabase @CreateAnyDatabaseParam

               #endregion Automatic Seeding

                $AvailabilityGroupAll.Add( $AvailabilityGroupCurrent )

           #endregion Availability Group

           #region Listener

                $AvailabilityGroupListener =
                    $AvailabilityGroupCurrent.AvailabilityGroupListeners[ $Name ]

               #region Create

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

                        $AvailabilityGroupProperty.ipAddress | ForEach-Object -Process {

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

               #endregion Create

               #region IP Address

                    $AvailabilityGroupProperty.ipAddress | ForEach-Object -Process {

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

               #region Cluster properties
                
                    $Message = "Setting Cluster Resource parameters for Availability Group Listener"
                    Write-Verbose -Message $Message

                    $Group = Get-ClusterGroup -InputObject $Cluster |
                        Where-Object -FilterScript { $psItem.Name -like "$Name*" }

                    $Resource = Get-ClusterResource -InputObject $Group |
                        Where-Object -FilterScript { $psItem.ResourceType -eq 'Network Name' }

                  # The following parameters are recommended because none of 
                  # the System Center components currently support “Multi-
                  # Subnet Failover”

                    $Parameter = [System.Collections.Generic.Dictionary[
                        System.String,
                        System.UInt32
                    ]]::new()

                    $Parameter.Add( 'RegisterAllProvidersIP', 0   )
                    $Parameter.Add( 'HostRecordTTL'         , 300 )                    
                    $Parameter.Add( 'PublishPTRRecords'     , 1   )

                    $Alter = $False

                    $Parameter.GetEnumerator() | ForEach-Object -Process {

                        $ParameterParam = @{
                        
                            Name        = $psItem.Key
                            InputObject = $Resource
                        }
                        $ParameterCurrent = Get-ClusterParameter @ParameterParam

                        If
                        (
                            $ParameterCurrent.Value -eq $psItem.Value
                        )
                        {
                            $Message = "  * Parameter `“$($psItem.Key)`” for `“$($Group.Name)`” already has value `“$($psItem.Value)`”"
                            Write-Verbose -Message $Message
                        }
                        Else
                        {
                            $Message = "  * Setting Parameter `“$($psItem.Key)`” for `“$($Group.Name)`” to value `“$($psItem.Value)`”"
                            Write-Verbose -Message $Message

                            $ParameterParam = @{
                                
                                InputObject = $Resource
                                Name        = $psItem.Key
                                Value       = $psItem.Value
                            }
                            Set-ClusterParameter @ParameterParam

                            $Alter = $True
                        }                        
                    }

                    If
                    (
                        $Alter
                    )
                    {
                        $Message = "Recycling `“$($Group.Name)`” group"
                        Write-Verbose -Message $Message

                      # If we only cycle the individual resource, the dependent
                      # resources (such as Availability Group Listener itself)
                      # will come offline but won't atomatically come back 
                      # online. To avoid bringing them online manually, we 
                      # cycle the entire group already

                        $GroupParam = @{

                            InputObject = $Group
                            Verbose     = $False
                        }

                        [System.Void]( Stop-ClusterGroup  @GroupParam )
                        [System.Void]( Start-ClusterGroup @GroupParam )
                    }
                    Else
                    {
                        $Message = "All parameter values are already current, skipping recycle"
                        Write-Verbose -Message $Message
                    }

                  # Rename the Cluster Group for consistency with other groups
                  # representing Failover Cluster Instances (FCIs)

                    $Group.Name = ( Resolve-dnsNameEx $Name ).Replace( $Name, $Name.ToUpper() )

               #endregion Cluster properties

           #endregion Listener

           #region Database

             <# If the Availability Group was just created, the existing 
                Databases were added to it directly when creating the 
                Availability Group. However, if the databases were added
                after the Availability Group was created, this part will
                add them to Availabiltiy Group on the current Primary
                Replica. (The secondary replicas are handled later below.)  #>

                $AvailabilityGroupProperty.DatabaseName.GetEnumerator() |
                    ForEach-Object -Process {

                    $DatabaseName = $psItem.Key

                   #region Add

                        $Database = $InstancePrimary.AvailabilityGroups[ $Name ].AvailabilityDatabases[ $DatabaseName ]

                        If
                        (
                            $Database -and $Database.SynchronizationState -eq 'Synchronized'
                        )
                        {
                            $Message = "Database `“$DatabaseName`” is already added as `“Availability Database`” for `“Availability Replica`” on `“$($InstancePrimary.Name)`”"
                            Write-Verbose -Message $Message
                        }
                        Else
                        {
                            $Message = "Adding Replica for Database `“$DatabaseName`” on `“$($InstancePrimary.Name)`”"
                            Write-Verbose -Message $Message

                            $AvailabilityDatabaseParam = @{

                                InputObject = $AvailabilityGroupCurrent
                                Database    = $DatabaseName
                                Verbose     = $False
                            }
                            Add-SqlAvailabilityDatabase @AvailabilityDatabaseParam
                        }

                   #endregion Add

                   #region Validate

                        $InstancePrimary.AvailabilityGroups[ $Name ].DatabaseReplicaStates |
                            Where-Object -FilterScript {
                                $psItem.AvailabilityDatabaseName -eq $DatabaseName
                            } | ForEach-Object -Process {

                                $DatabaseReplicaStateParam = @{

                                    InputObject = $psItem
                                    Verbose     = $False
                                }
                                $Test = Test-SqlDatabaseReplicaState @DatabaseReplicaStateParam

                                $Message = "Replica for Database `“$($Test.Name)`” on `“$($Test.AvailabilityReplica)`” is `“$($Test.HealthState)`”"
                                Write-Verbose -Message $Message
                            }     
                        
                   #endregion Validate                                       
                }

           #endregion Database

           #region Secondary Member(s)

                $Instance | Where-Object -FilterScript {
                    $psItem -ne $InstancePrimary
                } | ForEach-Object -Process {

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

                           #endregion Endpoint

                           #region Availability Replica

                                $AvailabilityReplicaName    = [System.String]::Empty
                                $AvailabilityReplicaName   += $InstanceCurrent.Information.NetName
                                $AvailabilityReplicaName   += '\'
                                $AvailabilityReplicaName   += $InstanceCurrent.InstanceName

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
                                        ConnectionModeInSecondaryRole = 'AllowAllConnections'
                                      # ConnectionModeInSecondaryRole = 'AllowNoConnections'
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

                       #region Automatic Seeding

                             <# $Query = @"
Alter Availability Group [$Name]
    Grant Create Any Database
"@

                                $CmdParam = @{

                                    ServerInstance = $InstanceCurrent
                                    Query          = $Query
                                    Verbose        = $False
                                }
                                Invoke-SqlCmd @CmdParam  #>

                            $CreateAnyDatabaseParam = @{

                                InputObject = $AvailabilityGroupCurrent
                                Verbose     = $False
                            }
                            Grant-SqlAvailabilityGroupCreateAnyDatabase @CreateAnyDatabaseParam

                       #endregion Automatic Seeding

                       #region Sync Login

                            $Query = @"

                            Execute dbo.SyncLogins
                                @Primary_Replica = '$($InstancePrimary.Name)';
"@

                            $CmdParam = @{

                                ServerInstance       = $InstanceCurrent
                                Query                = $Query
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            Invoke-SqlCmd @CmdParam

                       #endregion Sync Login

                       #region CRL Integration

                            $Query = "select value from sys.configurations where name = 'clr enabled'"

                            $CmdParam = @{

                                ServerInstance       = $InstancePrimary
                                Query                = $Query
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            $Out = Invoke-SqlCmd @CmdParam

                            $Query = @"

                                sp_configure 'clr enabled', $($Out.Value);
                                Reconfigure
"@

                            $CmdParam = @{

                                ServerInstance       = $InstanceCurrent
                                Query                = $Query
                                AbortOnError         = $True
                                OutputSqlErrors      = $True
                                IncludeSqlUserErrors = $True
                                Verbose              = $False
                            }
                            Invoke-SqlCmd @CmdParam

                       #endregion CRL Integration

                   #endregion Availability Group

                   #region Database

                        $AvailabilityGroupProperty.DatabaseName.GetEnumerator() |
                            ForEach-Object -Process {

                            $DatabaseName = $psItem.Key

                            $Database = $InstanceCurrent.AvailabilityGroups[ $Name ].AvailabilityDatabases[ $DatabaseName ]

                            If
                            (
                                $Database -and $Database.SynchronizationState -eq 'Synchronized'
                            )
                            {
                                $Message = "Database `“$DatabaseName`” is already added as `“Availability Database`” for `“Availability Replica`” on `“$($InstanceCurrent.Name)`”"
                                Write-Verbose -Message $Message
                            }
                            Else
                            {
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
                                        [System.Collections.Generic.List[
                                            Microsoft.SqlServer.Management.Smo.RelocateFile
                                        ]]::new()
                            
                                    $DatabaseParam = @{

                                      # Name        = $DatabaseName
                                        InputObject = $InstancePrimary                                        
                                        Verbose     = $False
                                    }

                                 <# $Database = Get-SqlDatabase @DatabaseParam |
                                        Where-Object -FilterScript {
                                            $psItem.Name -eq $DatabaseName
                                        }  #>

                                    $Database = $InstancePrimary.Databases[ $DatabaseName ]

                                    While
                                    (
                                       -not $Database
                                    )
                                    {
                                        $Message = "Database `“$DatabaseName`” was not found on the Primary Instance `“$($InstancePrimary.Name)`”, retrying"
                                        Write-Verbose -Message $Message

                                        Start-Sleep -Seconds 5

                                        $InstancePrimary.Refresh()
                                        $InstancePrimary.Databases.Refresh()

                                        $Database = $InstancePrimary.Databases[ $DatabaseName ]

                                     <# $Database = Get-SqlDatabase @DatabaseParam |
                                            Where-Object -FilterScript {
                                                $psItem.Name -eq $DatabaseName
                                            }  #>
                                    }

                                  # Relocate Data

                                    $Database.FileGroups | ForEach-Object -Process {

                                        $psItem.Files | ForEach-Object -Process {

                                            $PathParam = @{
                        
                                                Path      = $InstanceCurrent.Information.MasterDBPath
                                                ChildPath = Split-Path -Path $psItem.FileName -Leaf
                                            }
                                            $RelocateDataPath = Join-Path @PathParam

                                            $Argument = @(

                                                $psItem.Name
                                                $RelocateDataPath
                                            )

                                            $ObjectParam = @{

                                                TypeName     = 'Microsoft.SqlServer.Management.Smo.RelocateFile'
                                                ArgumentList = $Argument
                                            }
                                            $RelocateFile.Add( ( New-Object @ObjectParam ) )
                                        }
                                    }

                                  # Relocate Log

                                    $Database.LogFiles | ForEach-Object -Process {

                                        $PathParam = @{

                                            Path      = $InstanceCurrent.Information.MasterDBLogPath
                                            ChildPath = Split-Path -Path $psItem.FileName -Leaf
                                        }
                                        $RelocateLogPath  = Join-Path @PathParam

                                        $Argument = @(

                                            $psItem.Name
                                            $RelocateLogPath
                                        )

                                        $ObjectParam = @{

                                            TypeName     = 'Microsoft.SqlServer.Management.Smo.RelocateFile'
                                            ArgumentList = $Argument
                                        }
                                        $RelocateFile.Add( ( New-Object @ObjectParam ) )
                                    }

                               #endregion Relocate

                               #region Restore

                                    $Message = "Restoring database `“$DatabaseName`” on Instance `“$($InstanceCurrent.Name)`”"
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

                                    $Message = "Adding Replica for Database `“$DatabaseName`” on `“$($InstanceCurrent.Name)`”"
                                    Write-Verbose -Message $Message

                                    $AvailabilityDatabaseParam = @{

                                        InputObject = $AvailabilityGroupCurrent
                                        Database    = $DatabaseName
                                        Verbose     = $False
                                    }
                                    Add-SqlAvailabilityDatabase @AvailabilityDatabaseParam

                               #endregion Add
                            }

                           #region Property

                                $psItem.Value.GetEnumerator() | ForEach-Object -Process {

                                    $Query = "Select $($psItem.Key) From sys.databases where name = '$DatabaseName'"

                                    $CmdParam = @{

                                        ServerInstance       = $InstanceCurrent
                                        Query                = $Query                                        
                                        AbortOnError         = $True
                                        OutputSqlErrors      = $True
                                        IncludeSqlUserErrors = $True
                                        Verbose              = $False
                                    }
                                    $Out = Invoke-SqlCmd @CmdParam    
    
                                    If
                                    (
                                        $Out.$($psItem.Key)
                                    )
                                    {
                                        $Message = "  * Database `“$DatabaseName`” already has `“$($psItem.Key)`” on `“$($InstanceCurrent.Name)`”"
                                        Write-Verbose -Message $Message
                                    }
                                    Else
                                    {
                                     <# If
                                        (
                                            $psItem.Key -eq 'is_trustworthy_on'
                                        )
                                        {
                                            $Message = "  * Changing owner on database `“$DatabaseName`” on `“$($InstanceCurrent.Name)`”"
                                            Write-Verbose -Message $Message

                                            $Query = "Alter Database '$DatabaseName' set $($psItem.Value)"

                                            $CmdParam = @{

                                                ServerInstance       = $InstanceCurrent
                                                Query                = $Query
                                                Verbose              = $False
                                                AbortOnError         = $True
                                                OutputSqlErrors      = $True
                                                IncludeSqlUserErrors = $True
                                            }
                                            Invoke-SqlCmd @CmdParam
                                        }  #>

                                        $Message = "  * Setting `“$($psItem.Value)`” on database `“$DatabaseName`” on `“$($InstanceCurrent.Name)`”"
                                        Write-Verbose -Message $Message

                                        $Query = "Alter Database '$DatabaseName' set $($psItem.Value)"

                                        $CmdParam = @{

                                            ServerInstance       = $InstanceCurrent
                                            Query                = $Query                                            
                                            AbortOnError         = $True
                                            OutputSqlErrors      = $True
                                            IncludeSqlUserErrors = $True
                                            Verbose              = $False
                                        }
                                        Invoke-SqlCmd @CmdParam
                                    }
                                }                    

                           #endregion Property

                           #region Validate

                                $InstanceCurrent.AvailabilityGroups[ $Name ].DatabaseReplicaStates |
                                    Where-Object -FilterScript {
                                        $psItem.AvailabilityDatabaseName -eq $DatabaseName
                                    } | ForEach-Object -Process {

                                        $DatabaseReplicaStateParam = @{

                                            InputObject = $psItem
                                            Verbose     = $False
                                        }
                                        $Test = Test-SqlDatabaseReplicaState @DatabaseReplicaStateParam

                                        $Message = "Replica for Database `“$($Test.Name)`” on `“$($Test.AvailabilityReplica)`” is `“$($Test.HealthState)`”"
                                        Write-Verbose -Message $Message
                                    }

                           #endregion Validate
                        }

                   #endregion Database

                   #region Trusted Assemblies

                     <# Because of the “CLR Security” feature, software (e.g. 
                        OpsMgr) sometimes has to “whitelist” its components as
                        “Trusted Assemblies.” This is an instance-level (not
                        database-level) setting. Hence, it does not naturally
                        “replicate” to secondary Availability Group member(s).
                     
                        We need to mirror the “Trusted Assemblies” settings for 
                        all the Secondary Replica(s) to match those of the
                        Primary Replica #>

                        $Query = 'Select * From sys.trusted_assemblies'

                        $CmdParam = @{

                            ServerInstance       = $InstancePrimary
                            Query                = $Query                            
                            AbortOnError         = $True
                            OutputSqlErrors      = $True
                            IncludeSqlUserErrors = $True
                            Verbose              = $False
                        }
                        $OutPrimary = Invoke-SqlCmd @CmdParam

                        $CmdParam.ServerInstance = $InstanceCurrent

                        $OutCurrent = Invoke-SqlCmd @CmdParam

                      # Apparently we cannot compare two byte arrays, so have to convert
                      # them to strings

                        $HashPrimary   = [System.Collections.Generic.List[System.String]]::new()
                        $OutPrimary | ForEach-Object -Process {
                            $HashPrimary.Add( [System.Bitconverter]::ToString( $psItem.Hash ) )
                        }

                        $HashCurrent = [System.Collections.Generic.List[System.String]]::new()
                        $OutCurrent | ForEach-Object -Process {
                            $HashCurrent.Add( [System.Bitconverter]::ToString( $psItem.Hash ) )
                        }

                        If
                        (
                            $HashCurrent -eq $HashPrimary
                        )
                        {
                            $Message = "The list of Trusted Assemblies on the Secondary Instance `“$($InstanceCurrent.Name)`” already matches the one of the Primary Instance `“$($InstancePrimary.Name)`”"
                            Write-Verbose -Message $Message
                        }
                        Else
                        {
                            $Message = "The list of Trusted Assemblies on the Secondary Instance `“$($InstanceCurrent.Name)`” does not match the one of the Primary Instance `“$($InstancePrimary.Name)`”"
                            Write-Verbose -Message $Message

                            $OutPrimary | ForEach-Object -Process {
    
                                If
                                (
                                    [System.Bitconverter]::ToString( $psItem.Hash ) -in $HashCurrent
                                )
                                {
                                    $Message = "  * Assembly `“$($psItem.Description)`” is already present"
                                    Write-Verbose -Message $Message
                                }
                                Else
                                {
                                    $Message = "  * Adding assembly `“$($psItem.Description)`”"
                                    Write-Verbose -Message $Message

                                    $HashString = '0x' + [System.Bitconverter]::ToString( $psItem.Hash ).replace( '-', [system.string]::Empty).Substring( 0, 128 )

                                    $Query = @"

USE master;
GO

DECLARE @clrName    nvarchar(4000)   = '$($psItem.Description)'
DECLARE @HashString varbinary(64)    = $HashString;

EXEC sys.sp_add_trusted_assembly
    @hash        = @HashString,
    @description = @clrName;

"@

                                    $CmdParam = @{

                                        ServerInstance       = $InstanceCurrent
                                        Query                = $Query                                        
                                        AbortOnError         = $True
                                        OutputSqlErrors      = $True
                                        IncludeSqlUserErrors = $True
                                        Verbose              = $False
                                    }
                                    Invoke-SqlCmd @CmdParam
                                }
                            }
                        }

                   #endregion Trusted Assemblies
      
                }
                
           #endregion Secondary Member(s)
        
           #region Configure and Validate Availability Repica(s)

             <# Final configuration steps which apply equally to all
                Availability Replica(s) regardless of which one is 
                currently “Primary”  #>

                $InstancePrimary.AvailabilityGroups[ $Name ].AvailabilityReplicas | ForEach-Object -Process {

                    $AvailabilityReplicaParam = @{
                                
                        InputObject                   = $psItem
                        AvailabilityMode              = 'SynchronousCommit'
                        FailoverMode                  = 'Manual'
                        ConnectionModeInPrimaryRole   = 'AllowAllConnections'
                        ConnectionModeInSecondaryRole = 'AllowAllConnections'
                        SeedingMode                   = 'Automatic'
                        Verbose                       = $False
                    }
                    Set-SqlAvailabilityReplica @AvailabilityReplicaParam

                    $AvailabilityReplicaParam = @{
                        
                        InputObject = $psItem
                        Verbose     = $False
                    }
                    $Test = Test-SqlAvailabilityReplica @AvailabilityReplicaParam

                    $Message = "State of Availability Replica `“$($Test.AvailabilityGroup)`” on `“$($Test.Name)`” is `“$($Test.HealthState)`”"
                    Write-Verbose -Message $Message
                }

           #endregion Configure and Validate Availability Repica(s)

           #region Final Availability Group-level validation

                $AvailabilityGroupParam = @{

                    InputObject = $InstancePrimary.AvailabilityGroups[ $Name ]
                    Verbose     = $False
                }
                $Test = Test-SqlAvailabilityGroup @AvailabilityGroupParam

                $Message = "Availability Group `“$Name`” state is `“$($Test.HealthState)`”"
                Write-Verbose -Message $Message

           #endregion Final Availability Group-level validation
        }
    }

    End
    {
        Return $AvailabilityGroupAll
    }
}