Set-StrictMode -Version 'Latest'

Enum
SqlServerVersion
{
    SqlServer2014 = 12;
    SqlServer2016 = 13;
    SqlServer2017 = 14;
    SqlServer2019 = 15;
}

Function
Install-SqlServerEx
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory = $True
        )]
        [ValidateSet(
            'PrepareFailoverCluster',
            'CompleteFailoverCluster',
            'AddNode',
            'RemoveNode',
            'Patch',
            'Install'
        )]
        [System.String]
        $Action
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Version'
        )]
        [ValidateNotNullOrEmpty()]
        [SqlServerVersion]
        $Version
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DomainAddress = $env:UserDnsDomain.ToLower()
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Media'
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Media
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Update
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ProductKey
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NetworkName
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Collation = 'Latin1_General_100_CI_AS'
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.Dictionary[        
            System.String,
            System.Collections.Generic.Dictionary[
                System.String,
                System.String
            ]
        ]]
        $Instance
    )

    Begin
    {
       #region Path

            If
            (
                $Media -and
                $Media.Name -like 'SQL Server*'
            )
            {
                $VersionName = $Media.Name.Replace( 'SQL Server ', 'SqlServer' )            
                $Version = [SqlServerVersion]::$VersionName

                $Message = "    Version number `“$Version`” was derived from Meida name"
                Write-Debug -Message $Message
            }
            ElseIf
            (
                $Version
            )
            {
                $VersionName = $Version.ToString().Replace( 'SqlServer', 'SQL Server ' )

                If
                (
                    $Media
                )
                {
                    $MediaPath = Join-Path -Path $Media.FullName -ChildPath $VersionName
                }
                Else
                {
                    $MediaPath = Join-Path -Path '..' -ChildPath $VersionName
                }

                $Media = Get-Item -Path $MediaPath

                $Message = "    Media name `“$( $Media.Name )`” was derived from Version"
                Write-Debug -Message $Message
            }
            Else
            {
                $Message = 'Version was not specified, and Media name does not include a version. Unable to proceed'
                Write-Warning -Message $Message
            }

       #endregion Path

       #region Variable

            [System.Void]( Import-ModuleEx -Name 'ServerManager' )

            $FeatureParam = @{
                Name    = 'Failover-Clustering'
                Verbose = $False
            }
            $WindowsFeature = Get-WindowsFeature @FeatureParam

            If
            (
                $WindowsFeature.InstallState -eq 'Installed'
            )
            {
                [System.Void]( Import-ModuleEx -Name 'FailoverClusters' )

                $FaultDomainParam = @{

                    Name    = $env:ComputerName
                    Verbose = $False
                }

              # The Cluster Fault Domain cmdlets emit verbose messages even when 
              # “-Verbose” switch is set explicitly to “False”

                $VerbosePreferenceCurrent = $VerbosePreference
                $VerbosePreference = 'SilentlyContinue'

                $SiteName = ( Get-ClusterFaultDomain @FaultDomainParam ).ParentName

                $VerbosePreference = $VerbosePreferenceCurrent

              # We will only proceed Instances where the “Site Name” is defined 
              # and matches the current node Fault Domain

                $Message = "Detected Failover Cluster node in site `“$SiteName`”`n`n"

                $Instance = $Instance | Where-Object -FilterScript {
                    $psItem[ 'SiteName' ] -eq $SiteName
                }

                $Cluster         = Get-Cluster -Verbose:$False
                $ClusterAddress  = Resolve-dnsNameEx -Name $Cluster.Name

                $NetworkParam = @{
                    
                    InputObject = $Cluster
                    Verbose     = $False
                }

                If
                (
                    $NetworkName
                )
                {
                    $NetworkParam.Add( 'Name', "$NetworkName — $SiteName" )

                    $Network = Get-ClusterNetwork @NetworkParam
                }
                Else
                {
                    $Network = Get-ClusterNetwork @NetworkParam |
                        Where-Object -FilterScript {
                            $psItem.Name -like "*$SiteName*" -and
                            $psItem.Role -eq 'ClusterAndClient'
                        }
                }

              # The current assumption is that we only configure custom paths
              # for clustered instances. If the server is not a cluster member,
              # all instances will use default paths

                $PathParam = @{

                    Path      = $Cluster.SharedVolumesRoot
                    ChildPath = "$SiteName — $ClusterAddress — CSV01"
                }
                $VolumePath = Join-Path @PathParam

              # The below variables can potentially allow to configure different 
              # disks for different types of files. However, given the single CSV
              # configuration, we currently set them all to the same value

                $EngineDataDir          = $VolumePath
                $EngineUserDbDirRoot    = $VolumePath
                $EngineUserDbLogDirRoot = $VolumePath
                $EngineTempDbDirRoot    = $VolumePath
                $EngineTempDbLogDirRoot = $VolumePath
            }
            Else
            {
              # We will only proceed Instances where the “Site Name” is not defined

                $Message = "Failover Clustering feature is not installed, assuming stand-alone installation`n`n"

                $Instance = $Instance | Where-Object -FilterScript {
                    -Not $psItem[ 'SiteName' ]
                }
            }

            Write-Verbose -Message $Message

          # $Date = Get-Date -Format FileDateTimeUniversal

            If
            (
                $Action -eq 'Patch'
            )
            {
                $Path = $Update

                $Instance = @{ Name = 'bogus' ; AdminGroupName = 'bogus' }
            }
            Else
            {
                $Path = $Media
            }

       #endregion Variable
    }

    Process
    {  
        $Instance | ForEach-Object -Process {

           #region Parameter

                $InstanceParamCurrent = $psItem
                $Install              = $False

                $Feature   = [System.Collections.Generic.List[System.String]]::new()
                $Parameter = [System.Collections.Generic.Dictionary[System.String,System.String]]::new()

                $Name        =  $InstanceParamCurrent.Name.Replace( '-', '_' )
                $NameNetwork =  $InstanceParamCurrent.Name                
                $Address     = "$NameNetwork.$DomainAddress"

         <# $AnswerFileContent  = [System.String]::Empty
    
            $AnswerFileContent += @"

    ; SQL Server $( $Version ) Installation Configuration File

    [OPTIONS]

    ; ==============================================================================
    ; Main Installation Choices
    ; ==============================================================================

    ; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter.
    ACTION="$Action"

    ; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance.
    ; INSTANCEID="Inst-WAP"

    ; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine (SQL), Analysis Services (AS), or Reporting Services (RS).
    ; Note: Instance name cannot contain dash ("-")
    INSTANCENAME="$Name"


    ; ==============================================================================
    ; Output Options
    ; ==============================================================================

    ; Specifies that the detailed Setup log should be piped to the console.
    INDICATEPROGRESS="True"

    ; Setup will not display any user interface.
    ; QUIET="False"

    ; Setup will display progress only without any user interaction.
    QUIETSIMPLE="True"
    ; QS="True"

    ; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block.
    ; UIMODE="Normal"
    ; UIMODE="EnableUIOnServerCore"

    ; Displays the command line parameters usage
    ; HELP="False"

    ; Specifies that the console window is hidden or closed.
    HIDECONSOLE="False"


    ; ==============================================================================
    ; Minor Setup Options
    ; ==============================================================================

    ; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system.
    ; X86="False"

    ; Specifies the path to the installation media folder where setup.exe is located.
    ; MEDIASOURCE="\\heaven.contoso.su\file$\Media\Install\SQL Server\2011.0110.2100.060 ((SQL11_RTM).120210-1846 )"

    ; Use this parameter to install the English version of SQL Server on a localized operating system when the installation media includes language packs for both English and the language corresponding to the operating system.
    ENU="True"

    ; Set to "1" to enable RANU for SQL Server Express.
    ; ENABLERANU="False"

    ; Accept SQL Server license terms
    IAcceptSQLServerLicenseTerms="TRUE"



    ; ==============================================================================
    ; Accounts and Services
    ; ==============================================================================

    ; Account for SQL Server service: Domain\User or system account.
    ; SQLSVCACCOUNT=""

    ; Specifies the password for SQLSVCACCOUNT.
    ; SQLSVCPASSWORD="9eKyfO08SiGlIS4bypdKexz6Q1bnZAaGaEvPIB6N3M0RgNpQC8SodoVhUd0JAT5"

    ; Startup type for the SQL Server service.
    ; SQLSVCSTARTUPTYPE="Automatic"

    ; Agent account name
    ; AGTSVCACCOUNT=""

    ; Specifies the password for SQL Server Agent service account.
    ; AGTSVCPASSWORD="ERYiUH7ZiXGzm5JGcmMB0eF1yPUPXfgXjYTUAdNf1smSl6BMB5Qcq0nAHABJfcG"

    ; Auto-start service after installation. 
    ; AGTSVCSTARTUPTYPE="Automatic"

    ; Startup type for Browser Service.
    ; BROWSERSVCSTARTUPTYPE="Disabled"

    ; Provision current user as a Database Engine system administrator for SQL Server 2012 Express.
    ; ADDCURRENTUSERASSQLADMIN="False"

    ; Windows account(s) to provision as SQL Server system administrators. 
    ; SQLSYSADMINACCOUNTS="" 


    ; ==============================================================================
    ; Paths and Directories: Prepare
    ; ==============================================================================

    ; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed.
    ; INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"

    ; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed.
    ; INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"

    ; Specify the installation directory.
    ; INSTANCEDIR="K:\Microsoft SQL Server"

    ; ==============================================================================
    ; Paths and Directories: Complete
    ; ==============================================================================

    ; Specifies the data directory for SQL Server data files.
    ; The data directory must to specified and on a shared cluster disk.
    ; InstallSQLDataDir="K:\Microsoft SQL Server"

    ; Default directory for the Database Engine user databases.
    ; SQLUSERDBDIR="K:\Microsoft SQL Server\MSSQL\Data"

    ; Default directory for the Database Engine user database logs.
    ; SQLUSERDBLOGDIR="L:\Microsoft SQL Server\MSSQL\Data"

    ; Directory for Database Engine TempDB files.
    ; SQLTEMPDBDIR="K:\Microsoft SQL Server\MSSQL\Data"

    ; Directory for the Database Engine TempDB log files.
    ; SQLTEMPDBLOGDIR="L:\Microsoft SQL Server\MSSQL\Data"

    ; Specifies the directory for backup files.
    ; SQLBACKUPDIR="L:\Microsoft SQL Server\MSSQL\Backup"


    ; ==============================================================================
    ; Network Protocols
    ; ==============================================================================

    ; Specify 0 to disable or 1 to enable the TCP/IP protocol.
    ; TCPENABLED="1"

    ; Specify 0 to disable or 1 to enable the Named Pipes protocol.
    ; NPENABLED="0"

    ; CM brick TCP communication port
    ; COMMFABRICPORT="0"

    ; How matrix will use private networks
    ; COMMFABRICNETWORKLEVEL="0"

    ; How inter brick communication will be protected
    ; COMMFABRICENCRYPTION="0"

    ; TCP port used by the CM brick
    ; MATRIXCMBRICKCOMMPORT="0"

    "@  #>

                $Parameter.Add( 'Action'                       ,  $Action         )
                $Parameter.Add( 'InstanceName'                 ,  $Name           )
                $Parameter.Add( 'IndicateProgress'             ,  $True           )
                $Parameter.Add( 'QuietSimple'                  ,  $True           )
                $Parameter.Add( 'HideConsole'                  ,  $False          )
                $Parameter.Add( 'ENU'                          ,  $True           )
                $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  $True           )

                Switch
                (
                    $Action
                )
                {
                  # Stand-alone (non-clustered) parameter

                    'Install'
                    {
                        $Parameter.Add( 'AgtSvcStartupType'     ,  'Automatic'  )
                        $Parameter.Add( 'BrowserSvcStartupType' ,  'Disabled'   )
                    }

                  # Binary placing and service account parameter

                    {
                        $psItem -in @( 'Install', 'AddNode', 'PrepareFailoverCluster' )
                    }
                    {
                       #region Feature-specific options

                            If
                            (
                                $InstanceParamCurrent[ 'EngineAccountName'      ] -or
                                $InstanceParamCurrent[ 'AnalysisAccountName'    ]
                            )
                            {
                                $AgentAccount  = "$DomainAddress\$($InstanceParamCurrent.AgentAccountName )"

                                $Parameter.Add( 'AgtSvcAccount'                ,  $AgentAccount     )                                

                                If
                                (
                                    $InstanceParamCurrent[ 'AgentAccountPassword' ]
                                )
                                {
                                    $Parameter.Add( 'AgtSvcPassword'           ,  $InstanceParamCurrent.AgentAccountPassword  )
                                }
                            }

                            If
                            (
                                $InstanceParamCurrent[ 'EngineAccountName'      ]
                            )
                            {
                                $SqlServerParam = @{

                                    Name    = "SQL Server ($Name)"
                                    Version = $Version.value__
                                }

                                If
                                (
                                    Test-SqlServerEx @SqlServerParam
                                )
                                {
                                    $Message = "SQL Server Database Engine `“$Name`” is already installed. Skipping"
                                }
                                Else
                                {
                                    $Message = "Installing SQL Server Database Engine `“$Name`”"

                                    $Feature.Add( 'SqlEngine' )
            
                                    $EngineAccount = "$DomainAddress\$($InstanceParamCurrent.EngineAccountName)"

                                     <# $AnswerFileContent += @"
                    
        ; Level to enable FILESTREAM feature at (0, 1, 2 or 3).
        ; 0 =Disable FILESTREAM support for this instance. (Default value)
        ; The setting 'FILESTREAMLEVEL' is not allowed when the value of setting 'ACTION' is 'AddNode'.
        ; FILESTREAMLEVEL="0"

        ; Account for SQL Server service: Domain\User or system account.
        SqlSvcAccount="$EngineAccount"

        ; Agent account name
        AgtSvcAccount="$AgentAccount"

        "@  #>

                                  # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'          )
                                    $Parameter.Add( 'SqlSvcAccount'                ,  $EngineAccount  )

                                    If
                                    (
                                        $InstanceParamCurrent[ 'EngineAccountPassword' ]
                                    )
                                    {
                                        $Parameter.Add( 'SqlSvcPassword'           ,  $InstanceParamCurrent.EngineAccountPassword  )
                                    }
                                }

                                Write-Verbose -Message $Message
                            }

                            If
                            (
                                $InstanceParamCurrent[ 'AnalysisAccountName'    ] 
                            )
                            {
                                $SqlServerParam = @{

                                    Name    = "SQL Server Analysis Services ($Name)"
                                    Version = $Version.value__
                                }

                                If
                                (
                                    Test-SqlServerEx @SqlServerParam
                                )
                                {
                                    $Message = "SQL Server Analysis Services `“$Name`” is already installed. Skipping"
                                }
                                Else
                                {
                                    $Message = "Installing SQL Server Analysis Service (SSAS) `“$Name`”"

                                    $Feature.Add( 'As' )

                                    $AnalysisAccount = "$DomainAddress\$($InstanceParamCurrent.AnalysisAccountName)"

                                 <# $AnswerFileContent += @"
                    
        ; Specifies the account for the Analysis Services service.
        AsSvcAccount="$AnalysisAccount"

        ; Agent account name
        AgtSvcAccount="$AgentAccount"

        "@  #>

                                  # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'             )
                                    $Parameter.Add( 'AsSvcAccount'                 ,  $AnalysisAccount   )

                                    If
                                    (
                                        $InstanceParamCurrent[ 'AnalysisAccountPassword' ]
                                    )
                                    {
                                        $Parameter.Add( 'AsSvcPassword'            ,  $InstanceParamCurrent.AnalysisAccountPassword   )
                                    }
                                }

                                Write-Verbose -Message $Message
                            }
        
                            If
                            (
                                $InstanceParamCurrent[ 'IntegrationAccountName' ]
                            )
                            {
                                $SqlServerParam = @{

                                    Name    = 'SQL Server Integration Services%'
                                    Version = $Version.value__
                                }

                                If
                                (
                                    Test-SqlServerEx @SqlServerParam
                                )
                                {
                                    $Message = "SQL Server Integration Services `“$Name`” is already installed. Skipping"
                                }
                                Else
                                {
                                    $Message = "Installing SQL Server Integration Service (SSIS) `“$Name`”"
            
                                    $Feature.Add( 'Is' )
            
                                    $IntegrationAccount = "$DomainAddress\$($InstanceParamCurrent.IntegrationAccountName)"

                                 <# $AnswerFileContent += @"
                    
        ; Account for SQL Server service: Domain\User or system account.
        IsSvcAccount="$IntegrationAccount"

        "@  #>

                                  # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'                )
                                    $Parameter.Add( 'IsSvcAccount'                 ,  $IntegrationAccount   )

                                    If
                                    (
                                        $InstanceParamCurrent[ 'IntegrationAccountPassword' ]
                                    )
                                    {
                                        $Parameter.Add( 'IsSvcPassword'            ,  $InstanceParamCurrent.IntegrationAccountPassword   )
                                    }
                                }

                                Write-Verbose -Message $Message
                            }

                            If
                            (
                                $InstanceParamCurrent[ 'ReportingAccountName'   ]
                            )
                            {
                                Switch
                                (
                                    $Name
                                )
                                {
                                    'PBIRS'
                                    {
                                        $ProductName = 'Microsoft Power BI Report Server'
                                    }

                                    Default
                                    {
                                        $ProductName = "%SQL Server% Reporting Services"
                                    }
                                }

                                If
                                (
                                    ( Test-Product -Name $ProductName ) -eq 'Installed'
                                )
                                {
                                    $Message = "SQL Server Reporting Services `“$Name`” is already installed. Skipping"
                                }
                                Else
                                {
                                    $Message = "Installing SQL Server Reporting Services `“$Name`”"

                                  # All of the below parameters are obsolete 
                                  # because Reporting Services are no longer
                                  # installed by SQL Server setup engine

                                    $Feature.Add( 'Rs' )
            
                                    $ReportingAccount  = "$DomainAddress\$($InstanceParamCurrent.ReportingAccountName)"                                    

                                 <# $AnswerFileContent += @"
                    
        ; Specifies the account for the Analysis Services service.
        AsSvcAccount="$AnalysisAccount"

        ; Agent account name
        AgtSvcAccount="$AgentAccount"

        "@  #>

                                  # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'          )
                                    $Parameter.Add( 'RsSvcAccount'                 ,  $ReportingAccount   )

                                    If
                                    (
                                        $InstanceParamCurrent[ 'ReportingAccountPassword' ]
                                    )
                                    {
                                        $Parameter.Add( 'RsSvcPassword'            ,  $InstanceParamCurrent.ReportingAccountPassword   )
                                    }                                    
                                }

                                Write-Verbose -Message $Message
                            }

                       #endregion Feature-specific options

                       #region Generic options

                         <# $AnswerFileContent += @"

            ; Specifies the product key for the edition of SQL Server. If this parameter is not specified, Evaluation is used.
            PID="$ProductKey"

            "@  #>

                            $Parameter.Add( 'PID'                          ,  $ProductKey       )
                            
                            If
                            (
                                $Update
                            )
                            {
                             <# $AnswerFileContent += @"

            ; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found.
            UpdateEnabled="True"
           
            ; Specify the location where SQL Server Setup will obtain product updates. The valid values are `"MU`" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services."
            UpdateSource="$UpdateSource"

            "@  #>

                                $Parameter.Add( 'UpdateEnabled'            ,  $True             )
                                $Parameter.Add( 'UpdateSource'             ,  $Update.FullName  )
                            }

                       #endregion Generic options
                    }

                  # Data placing parameter

                    {
                        $psItem -in @( 'Install', 'CompleteFailoverCluster' )
                    }
                    {
                       #region Feature-specific options

                            If
                            (
                                $InstanceParamCurrent[ 'EngineAccountName'      ] -or
                                $InstanceParamCurrent[ 'AnalysisAccountName'    ]
                            )
                            {
                                $AdminGroup    = "$DomainAddress\$($InstanceParamCurrent.AdminGroupName   )"
                            }

                            If
                            (
                                $InstanceParamCurrent[ 'EngineAccountName'      ]
                            )
                            {
                                $GroupParam = @{
                            
                                    Name    = "*$Address*"
                                    Verbose = $False
                                }

                                If
                                (
                                    (
                                        ( $WindowsFeature.InstallState -eq 'Installed' ) -and
                                        ( Get-ClusterGroup @GroupParam )
                                    ) -or
                                    ( $WindowsFeature.InstallState -eq 'NotInstalled' )
                                )
                                {
                                    $Message = "Cluster Group for Instance `“$Name`” is already configured. Skipping"
                                    Write-Verbose -Message $Message
                                }
                                Else
                                {
                                    $Message = "Configuring SQL Server Database Engine `“$Name`”"
                                    Write-Verbose -Message $Message

                                  # $Feature.Add( 'SqlEngine' )

                                    If
                                    (
                                        $WindowsFeature.InstallState -eq 'Installed'
                                    )
                                    {
                                        $EngineUserDbDir    =    "$EngineUserDbDirRoot\MSSQL$( $Version.value__ ).$Name\MSSQL\DATA"
                                        $EngineUserDbLogDir = "$EngineUserDbLogDirRoot\MSSQL$( $Version.value__ ).$Name\MSSQL\DATA"
                                        $EngineTempDbDir    =    "$EngineTempDbDirRoot\MSSQL$( $Version.value__ ).$Name\MSSQL\DATA"
                                        $EngineTempDbLogDir = "$EngineTempDbLogDirRoot\MSSQL$( $Version.value__ ).$Name\MSSQL\DATA"
           
                                     <# $AnswerFileContent += @"
            
            ; ==============================================================================
            ; Paths and Directories: Complete
            ; ==============================================================================

            ; Specifies the data directory for SQL Server data files.
            ; The data directory must to specified and on a shared cluster disk.
            InstallSQLDataDir="$EngineDataDir"

            ; Default directory for the Database Engine user databases.
            SQLUSERDBDIR="$EngineUserDbDir"

            ; Default directory for the Database Engine user database logs.
            SQLUSERDBLOGDIR="$EngineUserDbLogDir"

            ; Directory for Database Engine TempDB files.
            SQLTEMPDBDIR="$EngineTempDbDir"

            ; Directory for the Database Engine TempDB log files.
            SQLTEMPDBLOGDIR="$EngineTempDbLogDir"

            ; Specifies the directory for backup files.
            ; SQLBACKUPDIR="E:\Microsoft SQL Server\MSSQL\Backup"


            ; ==============================================================================
            ; Accounts and Services
            ; ==============================================================================

            ; Windows account(s) to provision as SQL Server system administrators. 
            SQLSYSADMINACCOUNTS="$AdminGroup"


            ; ==============================================================================
            ; Engine-Specific Values
            ; ==============================================================================

            ; Specifies a Windows collation or an SQL collation to use for the Database Engine.
            SQLCOLLATION="$Collation"

            "@  #>

                                      # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'               )
                                        $Parameter.Add( 'InstallSQLDataDir'            ,  $EngineDataDir       )
                                        $Parameter.Add( 'SqlUserDbDir'                 ,  $EngineUserDbDir     )
                                        $Parameter.Add( 'SqlUserDbLogDir'              ,  $EngineUserDbLogDir  )
                                        $Parameter.Add( 'SqlTempDbDir'                 ,  $EngineTempDbDir     )
                                        $Parameter.Add( 'SqlTempDbLogDir'              ,  $EngineTempDbLogDir  )

                                    }
                                    Else
                                    {
                                        $Message = 'The server is not clustered, so Database Engine will use default paths'
                                        Write-Verbose -Message $Message
                                    }                                    

                                    $Parameter.Add( 'SqlSysAdminAccounts'              ,  $AdminGroup          )
                                    $Parameter.Add( 'SqlCollation'                     ,  $Collation           )

                                    If
                                    (
                                        $InstanceParamCurrent[ 'saPassword' ]
                                    )
                                    {
                                     <# $AnswerFileContent += @"

            SECURITYMODE = "SQL"
            SAPWD = "$($InstanceParamCurrent.saPassword)"

            "@  #>

                                        $Parameter.Add( 'SecurityMode'                 ,  'SQL'                             )
                                        $Parameter.Add( 'SaPwd'                        ,  $InstanceParamCurrent.saPassword  )
                                    }
                                }                                
                            }

                            If
                            (
                                $InstanceParamCurrent[ 'AnalysisAccountName'    ]
                            )
                            {
                                $GroupParam = @{
                            
                                  # Name    = "*$Address*"
                                    Name    = "*$Name*"
                                    Verbose = $False
                                }
                            
                                If
                                (
                                    (
                                        ( $WindowsFeature.InstallState -eq 'Installed' ) -and
                                        ( Get-ClusterGroup @GroupParam )
                                    ) -or
                                    ( $WindowsFeature.InstallState -eq 'NotInstalled' )
                                )
                                {
                                    $Message = "Cluster Group for Instance `"$Name`" is already configured. Skipping"
                                    Write-Verbose -Message $Message
                                }
                                Else
                                {
                                    $Message = "Configuring SQL Server Analysis Service (SSAS) `“$Name`”"
                                    Write-Verbose -Message $Message

                                  # $Feature.Add( 'As' )

                                    If
                                    (
                                        $WindowsFeature.InstallState -eq 'Installed'
                                    )
                                    {
                                      # Analysis Services can be clustered but they do 
                                      # not support Cluster Shared Volumes, so we have
                                      # to use regular cluster disk with a drive letter.
                                      # Because it's probably the only service on the 
                                      # cluster which does not support CSV, we can 
                                      # assume it uses the first cluster disk, i.e. D:.

                                        $AsConfigDir     = "D:\MSAS$( $Version.value__ ).$Name\OLAP\Config" 
                                        $AsTempDir       = "D:\MSAS$( $Version.value__ ).$Name\OLAP\Temp"
                                        $AsDataDir       = "D:\MSAS$( $Version.value__ ).$Name\OLAP\Data"
                                        $AsLogDir        = "D:\MSAS$( $Version.value__ ).$Name\OLAP\Log"
                                        $AsBackupDir     = "D:\MSAS$( $Version.value__ ).$Name\OLAP\Backup"

                                     <# $AnswerFileContent += @"
                    
            ; ==============================================================================
            ; Paths and Directories: Complete
            ; ==============================================================================

            ; Specifies the directory for Analysis Services configuration files.
            ASCONFIGDIR="$AsConfigDir"

            ; Specifies the directory for Analysis Services data files.
            ASDATADIR="$AsDataDir"

            ; Specifies the directory for Analysis Services log files.
            ASLOGDIR="$AsLogDir"

            ; Specifies the directory for Analysis Services temporary files.
            ASTEMPDIR="$AsTempDir"

            ; Specifies the directory for Analysis Services backup files.
            ASBACKUPDIR="$AsBackupDir"


            ; ==============================================================================
            ; Accounts and Services
            ; ==============================================================================

            ; Specifies the administrator credentials for Analysis Services.
            ASSYSADMINACCOUNTS="$AdminGroup"


            ; ==============================================================================
            ; SSAS-Specific Values
            ; ==============================================================================

            ; Specifies the collation setting for Analysis Services.
            ASCOLLATION="$Collation"

            ; Specifies the server mode of the Analysis Services instance. Valid values in a cluster scenario are MULTIDIMENSIONAL or TABULAR.
            ; ASSERVERMODE is case-sensitive. All values must be expressed in upper case. For more information about the valid values, see Install Analysis Services in Tabular Mode.
            ASSERVERMODE="MULTIDIMENSIONAL"

            ; Specifies whether the MSOLAP provider can run in-process.
            ; The setting 'ASPROVIDERMSOLAP' is not allowed when the value of setting 'ACTION' is 'CompleteFailoverCluster'.
            ; ASPROVIDERMSOLAP=1

            "@  #>

                                      # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'               )
                                        $Parameter.Add( 'AsConfigDir'                  ,  $AsConfigDir         )
                                        $Parameter.Add( 'AsDataDir'                    ,  $AsDataDir           )
                                        $Parameter.Add( 'AsLogDir'                     ,  $AsLogDir            )
                                        $Parameter.Add( 'AsTempDir'                    ,  $AsTempDir           )
                                        $Parameter.Add( 'AsBackupDir'                  ,  $AsBackupDir         )
                                    }
                                    Else
                                    {
                                        $Message = 'The server is not clustered, so Analysis Services will use default paths'
                                        Write-Verbose -Message $Message
                                    }

                                    $Parameter.Add( 'AsSysAdminAccounts'               ,  $AdminGroup          )
                                    $Parameter.Add( 'AsCollation'                      ,  $Collation           )

                                  # This parameter is case-sensitive
                                    $Parameter.Add( 'AsServerMode'                     ,  'MULTIDIMENSIONAL'   )
                                }
                            }
        
                            If
                            (
                                $InstanceParamCurrent[ 'IntegrationAccountName' ]
                            )
                            {
                                $Message = 'SQL Server Integration Service (SSIS) does not require any configuration'

                                Write-Verbose -Message $Message
                            }

                            If
                            (
                                $InstanceParamCurrent[ 'ReportingAccountName'   ]
                            )
                            {
                                $Message = 'SQL Server Reporting Service (SSRS) should be configured separately from a remote machine'

                                Write-Verbose -Message $Message
                            }

                       #endregion Feature-specific options

                      <#region Generic options

                            If
                            (
                                $Feature
                            )
                            {
                                $Message = 'Starting Configuration'

                                $Install = $True
                            }
                            Else
                            {
                                $Message = 'There are no Features to Configure'

                              # $AnswerFileContent  = [System.String]::Empty
                            }
               
                       #endregion Generic options  #>
                    }

                  # Cluster-specific per-node parameter

                    {
                        $psItem -in @( 'AddNode', 'CompleteFailoverCluster'  )
                    }
                    {
                     <# $AnswerFileContent += @"

        ; Specifies an encoded IP address.
        FailoverClusterIpAddresses="IPv4;$($InstanceParamCurrent.ipAddress);$NetworkNameSite;$SubnetMask"

        ; Indicates the consent to set the IP address resource dependency to OR for multi-subnet failover clusters. 
        ConfirmIpDependencyChange="True"
        "@  #>

                        [System.Collections.Generic.List[System.String]]$FailoverClusterIpAddresses =
                        @(
                            'IPv4'
                            $($InstanceParamCurrent.ipAddress)
                            $Network.Name
                            $Network.AddressMask
                        )

                        $Parameter.Add(
                            'FailoverClusterIpAddresses',
                            $FailoverClusterIpAddresses -join ';'
                        )

                        $Parameter.Add(
                            'ConfirmIpDependencyChange',
                            $True
                        )
                    }

                  # Cluster-specific per-cluster parameter

                    'CompleteFailoverCluster'
                    {
                         <# $AnswerFileContent += @"

        ; ==============================================================================
        ; Cluster Completion
        ; ==============================================================================

        FAILOVERCLUSTERNETWORKNAME="$NameNetwork"
        FAILOVERCLUSTERGROUP="$Address"
        ; FAILOVERCLUSTERDISKS=""

        "@  #>

                      # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'        )
                        $Parameter.Add( 'FailoverClusterNetworkName'   ,  $NameNetwork  )
                        $Parameter.Add( 'FailoverClusterGroup'         ,  $Address      )
                      # $Parameter.Add( 'FailoverClusterdisks'         ,  $null         )

                        Remove-Variable -Name 'Feature'
                        $Feature = $True
                    }

                  # Feature selection parameter
                  # (does not apply to Complete)

                    {
                        $psItem -in @( 'Install', 'PrepareFailoverCluster' )
                    }
                    {
                        If
                        (
                            $Feature
                        )
                        {
                             <# $AnswerFileContent += @"

        ; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, RS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install Management Tools, Books online components, SQL Server Data Tools, and other shared components.
        ; FEATURES=SQLENGINE,CONN,SSMS,ADV_SSMS
        FEATURES="$Features"

        ; Has no effect in SQL Server 2016 (13.x) . 
        ; Specify if errors can be reported to Microsoft to improve future SQL Server releases. Specify 1 or True to enable and 0 or False to disable this feature.
        ERRORREPORTING="True"

        ; Has no effect in SQL Server 2016 (13.x) . 
        ; Specify that SQL Server feature usage data can be collected and sent to Microsoft. Specify 1 or True to enable and 0 or False to disable this feature.
        SQMREPORTING="True"

        "@  #>

                            $Parameter.Add( 'Features'       ,  $Feature -join ','  )
                            $Parameter.Add( 'ErrorReporting' ,  $True               )
                            $Parameter.Add( 'SqmReporting'   ,  $True               )
                        }
                        Else
                        {
                            $Message = 'There are no Features to install'
                            Write-Verbose -Message $Message

                          # $AnswerFileContent  = [System.String]::Empty
                        }
                    }
                    
                  # Action-specific parameter

                    'RemoveNode'
                    {
                        $Message = "Removing this Cluster Node from Instance `“$Name`”"

                        Remove-Variable -Name 'Feature'
                        $Feature = $True
                    }

                    'AddNode'
                    {
                        $Message = "Adding this Cluster Node to Instance `“$Name`”"

                        Remove-Variable -Name 'Feature'
                        $Feature = $True
                    }

                    'Patch'
                    {
                        $Message = 'Updating all Instances'

                     <# $AnswerFileContent += @"
        ; Applies the SQL Server update to all instances of SQL Server and to all SQL Server shared, instance-unaware components.
        AllInstances="True"

        "@  #>

                        $ParameterGeneric.Add( 'IAcceptSQLServerLicenseTerms', $True )
                        $ParameterGeneric.Add( 'AllInstances',                 $True )

                        Remove-Variable -Name 'Feature'
                        $Feature = $True
                    }

                    Default
                    {
                        $Message = "Unexpected action `“$psItem`”"
                        Write-Warning -Message $Message
                    }
                }

              # Write-Verbose -Message $Message

           #endregion Parameter

           #region Run installation

             <# If
                (
                    [System.String]::IsNullOrEmpty( $AnswerFileContent )
                )
                {
                    Write-Verbose -Message "There are no SQL Server actions to perform on this pass.`n`n"
                }
                Else
                {
                    $OutFileParam = @{
        
                        InputObject = $AnswerFileContent
                        FilePath    = $ConfigurationFilePath
                        Encoding    = "Unicode"        
                    }
                    $File = Out-File @OutFileParam

                    $StartProcessParam = @{

                        FilePath     = $SetupPath
                        ArgumentList = $SetupArgument
                        NoNewWindow  = $True
                        Wait         = $True
                        PassThru     = $True
                    }
                    $Process = Start-Process @StartProcessParam

                    If
                    (
                        $Process.ExitCode -eq 0
                    )
                    {
                        Write-Verbose -Message "`nSetup completed successfully`n`n"
                    }
                    Else
                    {
                        Write-Error -Message "`nSetup failed with exit code $($Process.ExitCode)`n`n"

                        Return $Process.ExitCode
                    }                
                }  #>

                If
                (
                    $Feature
                )
                {
                    Switch
                    (
                        $Name
                    )
                    {
                       #region Stand-alone SSRS/PBIRS installer

                            'SSRS'
                            {
                                $Setup      = 'SQLServerReportingServices.exe'
                            }

                            'PBIRS'
                            {
                                $Setup      = 'PowerBIReportServer.exe'
                                $ProductKey = $InstanceParamCurrent.ProductKey
                            }

                            {
                                $psItem -in @( 'SSRS', 'PBIRS' )
                            }
                            {
                                $PathParam = @{

                                    Path      = $Media.FullName
                                    ChildPath = $Setup
                                }
                                $Path = Join-Path @PathParam

                                $Argument = [System.Collections.Generic.List[System.String]]::new()

                              # $Argument.Add( [System.String]::Empty  )
                                $Argument.Add( '/Passive'              )
                                $Argument.Add( '/noRestart'            )
                                $Argument.Add( '/iAcceptLicenseTerms'  )
                                $Argument.Add( "/PID=$ProductKey"      )

                                $ProcessParam = @{

                                    FilePath     = $Path
                                    ArgumentList = $Argument
                                    NoNewWindow  = $True
                                    Wait         = $True
                                    PassThru     = $True
                                }
                                $Process = Start-Process @ProcessParam

                                If
                                (
                                    $Process.ExitCode -eq 0
                                )
                                {
                                    $Message = 'Setup completed successfully'
                                    Write-Verbose -Message $Message
                                }
                                Else
                                {
                                    $Message = "Setup failed with exit code $($Process.ExitCode)"
                                    Write-Verbose -Message $Message

                                  # Return $Process.ExitCode
                                }
                            }

                       #endregion Stand-alone SSRS/PBIRS installer

                       #region Classic multi-feature SQL Server installer

                            Default
                            {
                                Start-SqlServerSetupEx -Path $Path -Parameter $Parameter
                            }

                       #endregion Classic multi-feature SQL Server installer
                    }                    
                }
                Else
                {
                    $Message = "There are no SQL Server actions to perform on this pass.`n`n"
                    Write-Verbose -Message $Message
                }

           #endregion Run installation
        }
    }

    End
    {
<# #region Update

  # Install Update
  # This step won't be required once the issue with KB2931693 fixed.
  # We will just need to change $UpdateSource value from "MU"
  # to the network location with update files.

    $SetupPath = Join-Path -Path $InstallationMediaUpdate -ChildPath "Setup.exe"
    $SetupArgument = "/ConfigurationFile=$ConfigurationFilePath /IAcceptSQLServerLicenseTerms"

    $AnswerFileContent = @"

; SQL Server 2014 Installation Configuration File

[OPTIONS]

; ==============================================================================
; Main Installation Choices
; ==============================================================================

; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter.
ACTION="Patch"

; Applies the SQL Server update to all instances of SQL Server and to all SQL Server shared, instance-unaware components.
AllInstances="True"


; ==============================================================================
; Output Options
; ==============================================================================

; Specifies that the detailed Setup log should be piped to the console.
INDICATEPROGRESS="True"

; Setup will not display any user interface.
; QUIET="False"

; Setup will display progress only without any user interaction.
QUIETSIMPLE="True"
; QS="True"

; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block.
; UIMODE="Normal"
; UIMODE="EnableUIOnServerCore"

; Displays the command line parameters usage
; HELP="False"

; Specifies that the console window is hidden or closed.
HIDECONSOLE="False"


; ==============================================================================
; Minor Setup Options
; ==============================================================================

; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system.
; X86="False"

; Specifies the path to the installation media folder where setup.exe is located.
; MEDIASOURCE="\\heaven.contoso.su\file$\Media\Install\SQL Server\2011.0110.2100.060 ((SQL11_RTM).120210-1846 )"

; Use this parameter to install the English version of SQL Server on a localized operating system when the installation media includes language packs for both English and the language corresponding to the operating system.
ENU="True"

; Specify if errors can be reported to Microsoft to improve future SQL Server releases. Specify 1 or True to enable and 0 or False to disable this feature.
ERRORREPORTING="True"

; Specify that SQL Server feature usage data can be collected and sent to Microsoft. Specify 1 or True to enable and 0 or False to disable this feature.
SQMREPORTING="True"

; Accept SQL Server license terms
IAcceptSQLServerLicenseTerms="TRUE"

; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found.
UpdateEnabled="True"

; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services.
; UpdateSource="MU"
UpdateSource=$UpdateSource

"@

    $OutFileParam = @{
        
        InputObject = $AnswerFileContent
        FilePath    = $ConfigurationFilePath
        Encoding    = "Unicode"        
    }
    Out-File @OutFileParam

    $StartProcessParam = @{

        FilePath     = $SetupPath
        ArgumentList = $SetupArgument
        NoNewWindow  = $True
        Wait         = $True
    }
    Start-Process @StartProcessParam

  #endregion Update  #>

       #region Cleanup

            If
            (
                $Action -eq 'RemoveNode'
            )
            {
                $Message = 'Uninstalling leftover shared component(s)'
                Write-Verbose -Message $Message

                $InstanceParam = @{
                
                    ClassName = 'win32_Product'
                    Filter    = 'Name like "%SQL Server%"'
                    Verbose   = $False
                }
                Get-CimInstance @InstanceParam |
                    Sort-Object -Property @( 'Vendor', 'Name' ) |
                        ForEach-Object -Process {

                    $Message = "$( $psItem.Vendor ) `“$( $psItem.Name )`” $( $psItem.Version )"
                    Write-Verbose -Message $Message

                    $MethodParam = @{

                        InputObject = $psItem
                        MethodName  = 'Uninstall'
                        Verbose     = $False
                    }
                    [System.Void]( Invoke-CimMethod @MethodParam )
                }
            }

       #endregion Cleanup

       #region Service SID

          # Service SID for OpsMgr agent service to facilitate SQL Server monitoring

            $ServiceName = 'HealthService'

            $SidType = sc.exe qSidType $ServiceName

            If
            (
                $SidType[3] -eq 'SERVICE_SID_TYPE:  NONE'
            )
            {
                [System.Void]( sc.exe SidType $ServiceName Unrestricted )
                Restart-Service -Name $ServiceName
            }

       #endregion Service SID
    }
}