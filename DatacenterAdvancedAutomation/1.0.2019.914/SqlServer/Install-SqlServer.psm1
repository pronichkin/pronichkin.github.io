Set-StrictMode -Version 'Latest'

Enum
SqlServerVersion
{
    SqlServer2014 = 12;
    SqlServer2016 = 13;
    SqlServer2017 = 14;
}

Function
Install-SqlServer
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
            'Patch'
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
        [System.Collections.Generic.List[System.Collections.Generic.Dictionary[System.String, System.String]]]
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

            [System.Void]( Import-ModuleEx -Name 'FailoverClusters' )

            $FaultDomainParam = @{

                Name     = $env:ComputerName
                Verbose = $False
            }

          # The Cluster Fault Domain cmdlets emit verbose messages even when 
          # “-Verbose” switch is set explicitly to “False”

            $VerbosePreferenceCurrent = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'

            $SiteName = ( Get-ClusterFaultDomain @FaultDomainParam ).ParentName

            $VerbosePreference = $VerbosePreferenceCurrent

            $NetworkNameSite = "$NetworkName — $SiteName"
            $Cluster         = Get-Cluster -Verbose:$False
            $ClusterAddress  = Resolve-dnsNameEx -Name $Cluster.Name

            $PathParam = @{

                Path      = $Cluster.SharedVolumesRoot
                ChildPath = "$SiteName — $ClusterAddress — CSV01"
            }
            $VolumePath = Join-Path @PathParam

            $InstallSqlDataDir   = $VolumePath
            $SqlUserDbDirRoot    = $VolumePath
            $SqlUserDbLogDirRoot = $VolumePath
            $SqlTempDbDirRoot    = $VolumePath
            $SqlTempDbLogDirRoot = $VolumePath

          # $Date = Get-Date -Format FileDateTimeUniversal

            If
            (
                $Action -eq 'Patch'
            )
            {
                $Path = $Update

                $Instance = @{ InstanceName = 'bogus' ; AdminGroupName = 'bogus' }
            }
            Else
            {
                $Path = $Media
            }

       #endregion Variable
    }

    Process
    {  
        $Instance | Where-Object -FilterScript {
            $psItem.SiteName -eq $SiteName
        } | ForEach-Object -Process {

           #region Variable

                $InstanceParamCurrent = $psItem
                $Install              = $False

                $Feature   = [System.Collections.Generic.List[System.String]]::new()
                $Parameter = [System.Collections.Generic.Dictionary[System.String,System.String]]::new()

                $InstanceName       = $InstanceParamCurrent.InstanceName.Replace( '-', '_' )
                $InstanceAddress    = "$($InstanceParamCurrent.InstanceName).$DomainAddress"
                $SqlSysAdminAccount = "$DomainAddress\$($InstanceParamCurrent.AdminGroupName)"

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
    INSTANCENAME="$InstanceName"


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
                $Parameter.Add( 'InstanceName'                 ,  $InstanceName   )
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
                {
                    $psItem -in @( 'PrepareFailoverCluster', 'AddNode' )
                }
                {
                   #region Feature-specific options

                            If
                            (
                                $InstanceParamCurrent[ 'AccountNameEngine' ]
                            )
                            {
                                $SqlServerParam = @{

                                    Name    = "SQL Server ($InstanceName)"
                                    Version = $Version.value__
                                }

                                If
                                (
                                    Test-SqlServer @SqlServerParam
                                )
                                {
                                    $Message = "SQL Server Database Engine `“$InstanceName`” is already installed. Skipping"                                    
                                }
                                Else
                                {
                                    $Message = "Installing SQL Server Database Engine `“$InstanceName`”"

                                    $Feature.Add( 'SqlEngine' )
            
                                    $SqlSvcAccount = "$DomainAddress\$($InstanceParamCurrent.AccountNameEngine)"
                                    $AgtSvcAccount = "$DomainAddress\$($InstanceParamCurrent.AccountNameAgent)"

                                 <# $AnswerFileContent += @"
                    
    ; Level to enable FILESTREAM feature at (0, 1, 2 or 3).
    ; 0 =Disable FILESTREAM support for this instance. (Default value)
    ; The setting 'FILESTREAMLEVEL' is not allowed when the value of setting 'ACTION' is 'AddNode'.
    ; FILESTREAMLEVEL="0"

    ; Account for SQL Server service: Domain\User or system account.
    SqlSvcAccount="$SqlSvcAccount"

    ; Agent account name
    AgtSvcAccount="$AgtSvcAccount"

    "@  #>

                                  # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'          )
                                    $Parameter.Add( 'SqlSvcAccount'                ,  $SqlSvcAccount  )
                                    $Parameter.Add( 'AgtSvcAccount'                ,  $AgtSvcAccount  )
                                }

                                Write-Verbose -Message $Message
                            }

                            If
                            (
                                $InstanceParamCurrent[ 'AccountNameAnalys' ]
                            )
                            {
                                $SqlServerParam = @{

                                    Name    = "SQL Server Analysis Services ($InstanceName)"
                                    Version = $Version.value__
                                }

                                If
                                (
                                    Test-SqlServer @SqlServerParam
                                )
                                {
                                    $Message = "SQL Server Analysis Services `“$InstanceName`” is already installed. Skipping"
                                }
                                Else
                                {
                                    $Message = "Installing SQL Server Analysis Service (SSAS) `“$InstanceName`”"

                                    $Feature.Add( 'As' )
            
                                    $AsSvcAccount  = "$DomainAddress\$($InstanceParamCurrent.AccountNameAnalys)"
                                    $AgtSvcAccount = "$DomainAddress\$($InstanceParamCurrent.AccountNameAgent)"

                                 <# $AnswerFileContent += @"
                    
    ; Specifies the account for the Analysis Services service.
    AsSvcAccount="$AsSvcAccount"

    ; Agent account name
    AgtSvcAccount="$AgtSvcAccount"

    "@  #>

                                  # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'          )
                                    $Parameter.Add( 'AsSvcAccount'                 ,  $AsSvcAccount   )
                                    $Parameter.Add( 'AgtSvcAccount'                ,  $AgtSvcAccount  )
                                }

                                Write-Verbose -Message $Message
                            }
        
                            If
                            (
                                $InstanceParamCurrent[ 'AccountNameIntegr' ]
                            )
                            {
                                $SqlServerParam = @{

                                    Name    = 'SQL Server Integration Services%'
                                    Version = $Version.value__
                                }

                                If
                                (
                                    Test-SqlServer @SqlServerParam
                                )
                                {
                                    $Message = "SQL Server Integration Services `“$InstanceName`” is already installed. Skipping"
                                }
                                Else
                                {
                                    $Message = "Installing SQL Server Integration Service (SSIS) `“$InstanceName`”"
            
                                    $Feature.Add( 'Is' )
            
                                    $IsSvcAccount = "$DomainAddress\$($InstanceParamCurrent.AccountNameIntegr)"

                                 <# $AnswerFileContent += @"
                    
    ; Account for SQL Server service: Domain\User or system account.
    IsSvcAccount="$IsSvcAccount"

    "@  #>

                                  # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'          )
                                    $Parameter.Add( 'IsSvcAccount'                 ,  $IsSvcAccount   )
                                  # $Parameter.Add( 'AgtSvcAccount'                ,  $AgtSvcAccount  )
                                }

                                Write-Verbose -Message $Message
                            }

                   #endregion Feature-specific options

                   #region Generic options

                     <# $AnswerFileContent += @"

        ; Specifies the product key for the edition of SQL Server. If this parameter is not specified, Evaluation is used.
        PID="$ProductKey"

        "@  #>

                      # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'          )
                        $Parameter.Add( 'PID'                          ,  $ProductKey     )
                      # $Parameter.Add( 'AgtSvcAccount'                ,  $AgtSvcAccount  )

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

                          # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'            )
                            $Parameter.Add( 'UpdateEnabled'                ,  $True             )
                            $Parameter.Add( 'UpdateSource'                 ,  $Update.FullName  )

                        }

                   #endregion Generic options
                }

                {
                    $psItem -in @( 'CompleteFailoverCluster', 'AddNode' )
                }
                {
                 <# $AnswerFileContent += @"

    ; Specifies an encoded IP address.
    FailoverClusterIpAddresses="IPv4;$($InstanceParamCurrent.ipAddress);$NetworkNameSite;$SubnetMask"

    ; Indicates the consent to set the IP address resource dependency to OR for multi-subnet failover clusters. 
    ConfirmIpDependencyChange="True"
    "@  #>

                    $NetworkParam = @{
                    
                        Name    = $NetworkNameSite
                        Verbose = $False
                    }        
                    $Network = Get-ClusterNetwork @NetworkParam

                    [System.Collections.Generic.List[System.String]]$FailoverClusterIpAddresses =
                    @(
                        'IPv4'
                        $($InstanceParamCurrent.ipAddress)
                        $NetworkNameSite
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

                'PrepareFailoverCluster'
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

                            $Install = $True
                        }
                        Else
                        {
                            $Message = 'There are no Features to install'

                          # $AnswerFileContent  = [System.String]::Empty
                        }
                }

                'CompleteFailoverCluster'
                {
                   #region Feature-specific options

                        If
                        (
                            $InstanceParamCurrent[ 'AccountNameEngine' ]
                        )
                        {
                            $GroupParam = @{
                            
                                Name    = "*$InstanceAddress*"
                                Verbose = $False
                            }

                            If
                            (
                                Get-ClusterGroup @GroupParam
                            )
                            {
                                $Message = "Cluster Group for Instance `“$InstanceName`” is already configured. Skipping"
                            }
                            Else
                            {
                                $Message = "Configuring SQL Server Database Engine `“$InstanceName`” on Cluster"

                                $Feature.Add( 'SqlEngine' )

                                $SqlUserDbDir    =    "$SqlUserDbDirRoot\MSSQL$( $Version.value__ ).$InstanceName\MSSQL\DATA"
                                $SqlUserDbLogDir = "$SqlUserDbLogDirRoot\MSSQL$( $Version.value__ ).$InstanceName\MSSQL\DATA"
                                $SqlTempDbDir    =    "$SqlTempDbDirRoot\MSSQL$( $Version.value__ ).$InstanceName\MSSQL\DATA"
                                $SqlTempDbLogDir = "$SqlTempDbLogDirRoot\MSSQL$( $Version.value__ ).$InstanceName\MSSQL\DATA"
           
                             <# $AnswerFileContent += @"
            
    ; ==============================================================================
    ; Paths and Directories: Complete
    ; ==============================================================================

    ; Specifies the data directory for SQL Server data files.
    ; The data directory must to specified and on a shared cluster disk.
    InstallSQLDataDir="$InstallSqlDataDir"

    ; Default directory for the Database Engine user databases.
    SQLUSERDBDIR="$SqlUserDbDir"

    ; Default directory for the Database Engine user database logs.
    SQLUSERDBLOGDIR="$SqlUserDbLogDir"

    ; Directory for Database Engine TempDB files.
    SQLTEMPDBDIR="$SqlTempDbDir"

    ; Directory for the Database Engine TempDB log files.
    SQLTEMPDBLOGDIR="$SqlTempDbLogDir"

    ; Specifies the directory for backup files.
    ; SQLBACKUPDIR="E:\Microsoft SQL Server\MSSQL\Backup"


    ; ==============================================================================
    ; Accounts and Services
    ; ==============================================================================

    ; Windows account(s) to provision as SQL Server system administrators. 
    SQLSYSADMINACCOUNTS="$SqlSysAdminAccount"


    ; ==============================================================================
    ; Engine-Specific Values
    ; ==============================================================================

    ; Specifies a Windows collation or an SQL collation to use for the Database Engine.
    SQLCOLLATION="$Collation"

    "@  #>

                              # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'               )
                                $Parameter.Add( 'InstallSQLDataDir'            ,  $InstallSqlDataDir   )
                                $Parameter.Add( 'SqlUserDbDir'                 ,  $SqlUserDbDir        )
                                $Parameter.Add( 'SqlUserDbLogDir'              ,  $SqlUserDbLogDir     )
                                $Parameter.Add( 'SqlTempDbDir'                 ,  $SqlTempDbDir        )
                                $Parameter.Add( 'SqlTempDbLogDir'              ,  $SqlTempDbLogDir     )
                                $Parameter.Add( 'SqlSysAdminAccounts'          ,  $SqlSysAdminAccount  )
                                $Parameter.Add( 'SqlCollation'                 ,  $Collation           )

                                If
                                (
                                    $InstanceParamCurrent[ 'saPassword' ]
                                )
                                {
                                 <# $AnswerFileContent += @"

        SECURITYMODE = "SQL"
        SAPWD = "$($InstanceParamCurrent.saPassword)"

        "@  #>

                                    $Parameter.Add( 'SecurityMode' ,  'SQL'                             )
                                    $Parameter.Add( 'SaPwd'        ,  $InstanceParamCurrent.saPassword  )
                                }
                            }

                            Write-Verbose -Message $Message
                        }

                        If
                        (
                            $InstanceParamCurrent[ 'AccountNameAnalys' ]
                        )
                        {
                            $GroupParam = @{
                            
                              # Name    = "*$InstanceAddress*"
                                Name    = "*$InstanceName*"
                                Verbose = $False
                            }
                            
                            If
                            (
                                Get-ClusterGroup @GroupParam
                            )
                            {
                                $Message = "Cluster Group for Instance `"$InstanceName`" is already configured. Skipping"
                            }
                            Else
                            {
                                $Message = "Configuring SQL Server Analysis Service (SSAS) `“$InstanceName`” on Cluster"

                                $Feature.Add( 'As' )

                              # Analysis Services can be clustered but they do 
                              # not support Cluster Shared Volumes, so we have
                              # to use regular cluster disk with a drive letter.
                              # Because it's probably the only service on the 
                              # cluster which does not support CSV, we can 
                              # assume it uses the first cluster disk, i.e. D:.

                                $AsConfigDir     = "D:\MSAS$( $Version.value__ ).$InstanceName\OLAP\Config" 
                                $AsTempDir       = "D:\MSAS$( $Version.value__ ).$InstanceName\OLAP\Temp"
                                $AsDataDir       = "D:\MSAS$( $Version.value__ ).$InstanceName\OLAP\Data"
                                $AsLogDir        = "D:\MSAS$( $Version.value__ ).$InstanceName\OLAP\Log"
                                $AsBackupDir     = "D:\MSAS$( $Version.value__ ).$InstanceName\OLAP\Backup"

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
    ASSYSADMINACCOUNTS="$SqlSysAdminAccount"


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
                                $Parameter.Add( 'AsSysAdminAccounts'           ,  $SqlSysAdminAccount  )
                                $Parameter.Add( 'AsCollation'                  ,  $Collation           )
                                $Parameter.Add( 'AsServerMode'                 ,  $MultiDimensional    )
                            }

                            Write-Verbose -Message $Message
                        }
        
                        If
                        (
                            $InstanceParamCurrent[ 'AccountNameIntegr' ]
                        )
                        {
                            $Message = 'SQL Server Integration Service (SSIS) does not require any Cluster configuration'

                            Write-Verbose -Message $Message
                        }

                   #endregion Feature-specific options

                   #region Generic options

                     <# $AnswerFileContent += @"

    ; ==============================================================================
    ; Cluster Completion
    ; ==============================================================================

    FAILOVERCLUSTERNETWORKNAME="$InstanceNameNetwork"
    FAILOVERCLUSTERGROUP="$InstanceAddress"
    ; FAILOVERCLUSTERDISKS=""

    "@  #>

                      # $Parameter.Add( 'iAcceptSqlServerLicenseTerms' ,  'True'                )
                        $Parameter.Add( 'FailoverClusterNetworkName'   ,  $InstanceNameNetwork  )
                        $Parameter.Add( 'FailoverClusterGroup'         ,  $SqlUserDbDir         )
                      # $Parameter.Add( 'FailoverClusterdisks'         ,  $null                 )

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
               
                   #endregion Generic options
                }

                'RemoveNode'
                {
                    $Message = "Removing this Cluster Node from Instance `“$InstanceName`”"

                    $Install = $True
                }

                'AddNode'
                {
                    $Message = "Adding this Cluster Node to Instance `“$InstanceName`”"

                    $Install = $True
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

                    $Install = $True
                }

                Default
                {
                    $Message = "Unexpected action `“$psItem`”"
                    Write-Warning -Message $Message
                }
            }

                Write-Verbose -Message $Message

           #endregion Variable

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
                    $Install
                )
                {
                    Start-SqlServerSetup -Path $Path -Parameter $Parameter
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