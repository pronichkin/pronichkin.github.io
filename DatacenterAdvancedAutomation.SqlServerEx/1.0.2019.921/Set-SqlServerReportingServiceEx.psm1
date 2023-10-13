Set-StrictMode -Version 'Latest'

Function
Set-SqlServerReportingServiceEx
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerAddress
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServiceAddress = $ServerAddress
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DatabaseName
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DatabaseServerAddress
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DatabaseInstanceName
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServiceAccountName  # Can be “Virtual”, “System” or custom domain user name
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServiceAccountPassword
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.String]]
        $AllowedResourceExtensionsForUpload
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Globalization.CultureInfo]
        $CultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo( 'En-US' )
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $BackupPassword
    )

    Begin
    {
       #region Variable

            [System.Void]( Import-ModuleEx -Name 'SqlServer' )

            If
            (
                $DatabaseInstanceName
            )
            {                
                $DatabaseInstanceAddress = $DatabaseServerAddress + '\' + $DatabaseInstanceName
            }
            Else
            {
                $DatabaseInstanceAddress = $DatabaseServerAddress
            }

            $DatabaseInstancePath = "SqlServer:\SQL\$DatabaseInstanceAddress"
                        
            $Application = @{

                ReportServerWebService = 'ReportServer'

              # The application name has changed in 2017
              # ReportManager          = 'Reports'
                ReportServerWebApp     = 'Reports'

              # Two new applications below are specific to
              # Power BI Server features
                PowerBIWebApp          = [System.String]::Empty
                OfficeWebApp           = [System.String]::Empty  # Web Application Open Platform Interface (WOPI) protocol
            }

            $Url = @(
                   
              # 'http://+:80'
              # 'https://+:443'
              # "http://$($ServerAddress):80"     # This is for SSAS integration. It will use hardcoded server address
                "http://$($ServiceAddress):80"    # SSAS connection feature in VMM is hardcoded to use HTTP
                "https://$($ServiceAddress):443"  # This is the proper URL we're going to use
            )

       #endregion Variable
    }
    
    Process
    {
       #region 1/12  Obtain Report Server Instance Configuration WMI Object

            Write-Verbose -Message '***'
            $Message = 'Step 1 of 12.  Obtaining objects'
            Write-Verbose -Message $Message

            $Message = "  1.1.  Configuration"
            Write-Verbose -Message $Message

            $Session = New-cimSessionEx -Name $ServerAddress
    
          # We need the last version of WMI Namespace

            $Path = 'root/Microsoft/SqlServer/ReportServer/rs_' + $InstanceName

            $NameSpaceParam = @{
            
                Path       = $Path
                Name       = 'v%'
                cimSession = $Session
            }
            $NameSpace = Get-cimNameSpaceEx @NameSpaceParam |
                Sort-Object -Property 'Name' |
                    Select-Object -Last 1

            $Path = $Namespace.CimSystemProperties.Namespace + '/' + $Namespace.Name + '/Admin'

            $InstanceParam = @{

                Namespace    = $Path
                ClassName    = 'msReportServer_ConfigurationSetting'
                Filter       = "InstanceName='$InstanceName'"
                CimSession   = $Session
                Verbose      = $False
            }
            $Configuration = Get-cimInstance @InstanceParam

         <# $Message = "  1.2.  Service"
            Write-Verbose -Message $Message

            $ServiceParam = @{

                ComputerName = $ServerAddress
                Name         = $Configuration.ServiceName
            }
            $Service = Get-Service @ServiceParam

          # $Service = Get-Service -ComputerName $ServerAddress | Where-Object -FilterScript { $psItem.Name -eq $Configuration.ServiceName }

            $ServiceParam = @{
                
                ClassName  = 'win32_Service'
                Filter     = "Name = '$( $Configuration.ServiceName )'"
                cimSession = $Session
                Verbose    = $False
            }
            $Service = Get-cimInstance @ServiceParam  #>

            $Message = "  1.3.  Database"
            Write-Verbose -Message $Message

            $DatabaseInstance = Get-Item -Path $DatabaseInstancePath

            $Message = "  1.4.  Certificate"
            Write-Verbose -Message $Message

            $FriendlyName = "SQL Server Reporting Services — $ServiceAddress"
            $SubjectName  = "CN=$ServiceAddress"

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'ListSslCertificates'
                Verbose     = $False
            }
            $ListSslCertificate = Invoke-cimMethod @MethodParam

            $Match = $ListSslCertificate.CertName | Where-Object -FilterScript { $psItem -eq $FriendlyName }

            If
            (
                $Match
            )
            {
                $Index            = $ListSslCertificate.CertName.IndexOf( $Match )
                $CertificateHash  = $ListSslCertificate.CertificateHash[ $Index ]
            }
            Else
            {
                $Message = 'Certificate not found'
                Write-Warning -Message $Message
            }

       #endregion 1/7  Obtain Report Server Instance Configuration WMI Object

       #region 2/12  Create Firewall rule

            Write-Verbose -Message '***'
            $Message = 'Step 2 of 12.  Firewall rules'
            Write-Verbose -Message $Message

            $FirewallRuleParam = @{

                Direction  = 'Inbound'
                Enabled    = 'True'
                Profile    = 'Domain'
                Action     = 'Allow'
                Protocol   = 'TCP'
                Group      = $InstanceName
                CimSession = $Session
            }

            $FirewallRuleProperty = @{

                'Reporting Service' = @{

                    LocalPort = @( 80, 443 )
                    Program   = 'System'
                }

             <# 'Analysis Service'  = @{
                
                    LocalPort = 2383
                    Program   = "$env:ProgramFiles\Microsoft Power BI Report Server\$InstanceName\ASEngine\msmdsrv.exe"
                }  #>
            }

            $FirewallRuleProperty.GetEnumerator() | ForEach-Object -Process {

                $Name = $psItem.Key

                If
                (
                    Get-NetFirewallRule -cimSession $Session | Where-Object -FilterScript { $psItem.DisplayName -eq $Name }
                )
                {
                    $Message = "  Firewall rule `“$Name`” already exists"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $FirewallRuleCurrentParam = $FirewallRuleParam.Clone()

                    $FirewallRuleCurrentParam.Add( 'DisplayName', $Name )
                    $FirewallRuleCurrentParam.Add( 'LocalPort', $psItem.Value.LocalPort )
                    $FirewallRuleCurrentParam.Add( 'Program',   $psItem.Value.Program )

                    [System.Void]( New-NetFirewallRule @FirewallRuleCurrentParam )
                }
            }            

       #endregion 2/7  Create Firewall rule

       #region 3/12  Edit configuration

            Write-Verbose -Message '***'
            $Message = 'Step 3 of 12.  Configuration files'
            Write-Verbose -Message $Message

            If
            (
                $Configuration.IsInitialized
            )
            {
                $Message = 'Already initialized, skipping'
                Write-Verbose -Message $Message
            }
            Else
            {

             <# We cannot use the Analysis Services from Power BI installation
                because it always run in “SharePoint” mode (1), and VMM
                needs it to be in “Multidimensional” mode (0).

                Hence, no need to change the port.
                  
                $Message = '  3.1.  Static port for Analysis Services (Config.json)'
                Write-Verbose -Message $Message

                $Path = "\\$ServerAddress\c$\Program Files\Microsoft Power BI Report Server\$InstanceName\RSHostingService\config.json"
                $Content = Get-Content -Path $Path

              # Apparently it's not valid JSON according to PowerShell
              # So we cannot edit it as such. Will edit as plain text.
              # $Content | ConvertFrom-Json

                $Search = $Content | Where-Object -FilterScript { $psItem -like '*"ASPort"*' }
                $Content[ $Content.IndexOf( $Search ) ] = '        "ASPort": "2383",'  #>

             <# Power BI management component uses non-standard port 8083
                for internal communication. Let's keep it like this.
         
                $Content = $Content -replace 'http://localhost:8083', "https://$ServerAddress:443"

              # $Content = $Content -replace ':8083',     [System.String]::Empty
              # $Content = $Content -replace 'http://',   'https://'
              # $Content = $Content -replace 'localhost', $ServerAddress
              # $Content = $Content -replace '\+',        $ServerAddress            

                Set-Content -Value $Content -Path $Path  #>
            
                $Message = '  3.1.  Kerberos authentication (rsReportServer.config)'
                Write-Verbose -Message $Message

              # $Path = "\\$ServerAddress\c$\Program Files\Microsoft Power BI Report Server\$InstanceName\ReportServer\rsreportserver.config"
                $Path = $Configuration.PathName.Replace( 'C:', "\\$ServerAddress\c$" )

                $Content = [System.Xml.XmlDocument]( Get-Content -Path $Path )

                If
                (
                    -Not $Content.Configuration.Authentication.AuthenticationTypes[ 'RSWindowsKerberos' ]
                )
                {
                    $Kerberos = $Content.CreateElement( 'RSWindowsKerberos' )

                    [System.Void]( $Content.Configuration.Authentication.AuthenticationTypes.AppendChild( $Kerberos ) )
                }

                If
                (
                    $Content.Configuration.Authentication.AuthenticationTypes[ 'RSWindowsNTLM' ]
                )
                {
                    $Ntlm = $Content.Configuration.Authentication.AuthenticationTypes[ 'RSWindowsNTLM' ]

                    [System.Void]( $Content.Configuration.Authentication.AuthenticationTypes.RemoveChild( $Ntlm ) )
                }

                $Content.Save( $Path )

             <# As explained above, we're not using the Analysis services from Power BI
         
                $Message = '  3.3.  Allow remote connections to Analysis Services (msmdsrv.ini — root)'
                Write-Verbose -Message $Message

                $Path = "\\$ServerAddress\c$\Program Files\Microsoft Power BI Report Server\$InstanceName\ASEngine\msmdsrv.ini"
                $Content = [System.Xml.XmlDocument]( Get-Content -Path $Path )
                $Content.ConfigurationSettings.Network.ListenOnlyOnLocalConnections = '0'
                $Content.Save( $Path )  #>

             <# $Message = '  3.4.  Allow remote connections to Analysis Services (msmdsrv.ini — child)'
                Write-Verbose -Message $Message

                $Path = "\\$ServerAddress\c$\Program Files\Microsoft Power BI Report Server\$InstanceName\ASEngine\workspaces\msmdsrv.ini"
                $Content = [System.Xml.XmlDocument]( Get-Content -Path $Path )
                $Content.ConfigurationSettings.Network.ListenOnlyOnLocalConnections = '0'
              # $Content.ConfigurationSettings.Port = '2383'
                $Content.Save( $Path )  #>

             <# $Message = '  3.5.  msmdsrv.port.txt'
                Write-Verbose -Message $Message

                $Path = "\\$ServerAddress\c$\Program Files\Microsoft Power BI Report Server\$InstanceName\ASEngine\workspaces\msmdsrv.port.txt"
                Set-Content -Path $Path -Value '2383' -Encoding Unicode  #>
            }

       #endregion 3/8  Edit configuration

       #region 4/12  Configure the report server service account

            Write-Verbose -Message '***'
            $Message = 'Step 4 of 12.  Security'
            Write-Verbose -Message $Message

            $Message = '  4.1.  Service account'
            Write-Verbose -Message $Message

            Switch
            (
                $ServiceAccountName
            )
            {
                'Virtual'
                {
                    $setWindowsServiceIdentityParam = @{
                
                        'UseBuiltInAccount' = $True
                        'Account'           = 'NT Service\sqlServerReportingServices'
                        'Password'          = [System.String]::Empty
                    }
                }

                'System'
                {
                    $setWindowsServiceIdentityParam = @{
            
                        'UseBuiltInAccount' = $True
                        'Account'           = 'NT Authority\LocalSystem'
                        'Password'          = [System.String]::Empty
                    }
                }

                Default
                {
                 <# Cannot use FQDN here because OpsMgr setup will complain 
                    about account mismatch against the Management Group 
                    configuration  #>

                  # $ServiceAccount = "$( $env:UserDnsDomain )\$ServiceAccountName"
                    $ServiceAccount = "$( $env:UserDomain    )\$ServiceAccountName"

                    $setWindowsServiceIdentityParam = @{
                
                        'UseBuiltInAccount' = $False
                        'Account'           = $ServiceAccount
                    }

                    If
                    (
                        $ServiceAccountPassword
                    )
                    {
                        $setWindowsServiceIdentityParam.Add( 

                            'Password', $ServiceAccountPassword
                        )
                    }
                    Else
                    {
                        $setWindowsServiceIdentityParam.Add( 

                            'Password', [System.String]::Empty
                        )
                    }
                }
            }

            If
            (
                $Configuration.IsInitialized
            )
            {
                $Message = 'Already initialized, skipping'
                Write-Verbose -Message $Message
            }
            Else
            {
              # “Set Windows Service Identity” Method
              # (WMI MSReportServer_SetWindowsServiceIdentity)

                $MethodParam = @{

                    CimInstance = $Configuration
                    MethodName  = 'setWindowsServiceIdentity'
                    Arguments   = $setWindowsServiceIdentityParam
                    Verbose     = $False
                }
                $setWindowsServiceIdentity = Invoke-cimMethod @MethodParam
            }

            $Message = '  4.2.  Extended Protection'
            Write-Verbose -Message $Message

            $setExtendedProtectionSettingParam = @{

              # ExtendedProtectionLevel    = 'Off'
                ExtendedProtectionLevel    = 'Require'
              # ExtendedProtectionScenario = 'Proxy'
                ExtendedProtectionScenario = 'Any'
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'setExtendedProtectionSettings'
                Arguments   = $setExtendedProtectionSettingParam
                Verbose     = $False
            }
            $setExtendedProtectionSetting = Invoke-cimMethod @MethodParam

         <# SSAS integration in VMM uses hardcoded HTTP address
            and hence cannot work when SSL is enfor
         
            $Message = '  4.3.  Enforce SSL'
            Write-Verbose -Message $Message

          # VMM SSAS integration process does not work in case SSL is enforced

            $setSecureConnectionLevelParam = @{

                Level = 0  # SSL is not required
              # Level = 1  # SSL is required
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'setSecureConnectionLevel'
                Arguments   = $setSecureConnectionLevelParam
                Verbose     = $False
            }
            $setSecureConnectionLevel = Invoke-cimMethod @MethodParam   #>
            
            $Message = "  4.3.  Restart $( $Configuration.ServiceName )"
            Write-Verbose -Message $Message

            [System.Void]( Restart-SqlServerReportingServiceEx -Configuration $Configuration )

       #endregion Configure the report server service account

       #region 5/12  Configure the Report Server Web service and Report Manager URLs

            Write-Verbose -Message '***'
            $Message = 'Step 5 of 12.  Paths and URLs'
            Write-Verbose -Message $Message

            $Count = 1

            $Application.GetEnumerator() | ForEach-Object -Process {

                $ApplicationName      = $psItem.Key                
                                
                $Message = "  5.$Count.  Processing Application `“$ApplicationName`”"
                Write-Verbose -Message $Message
                
                If
                (
                    $psItem.Value
                )
                {
                    $ApplicationDirectory = $psItem.Value

                    $Message = "    5.$Count.1.  Set Virtual Directory to `“$ApplicationDirectory`”"
                    Write-Verbose -Message $Message

                  # “Set Virtual Directory” Method
                  # (WMI MSReportServer_ConfigurationSetting)
                  # http://msdn.microsoft.com/library/bb630594

                    $setVirtualDirectoryParam = @{

                        Application      = $ApplicationName
                        VirtualDirectory = $ApplicationDirectory
                        Lcid             = $CultureInfo.LCID
                    }

                    $MethodParam = @{

                        CimInstance = $Configuration
                        MethodName  = 'setVirtualDirectory'
                        Arguments   = $setVirtualDirectoryParam
                        Verbose     = $False
                    }
                    $setVirtualDirectory = Invoke-cimMethod @MethodParam
                }
                Else
                {
                    $Message = "    5.$Count.1.  There's no Virtual Directory, skipping"
                    Write-Verbose -Message $Message
                }

              # Process Bindings (Host Headers with Ports)

                $Message = "    5.$Count.2.  Reserving URLs"
                Write-Verbose -Message $Message

                $Count2 = 1

                $Url | ForEach-Object -Process {

                    $UrlCurrent = $psItem
                    
                    $Message = "      5.$Count.2.$Count2  `“$UrlCurrent`”"
                    Write-Verbose -Message $Message

                  # Same arguments for “Remove URL” and “Reserve URL”

                    $UrlParam = @{

                        Application = $ApplicationName
                        UrlString   = $UrlCurrent
                        Lcid        = $CultureInfo.LCID
                    }

                    $Message = "        5.$Count.2.$Count2.1  Remove URL"
                    Write-Verbose -Message $Message

                  # “Remove URL” Method
                  # (WMI MSReportServer_ConfigurationSetting)
                  # http://msdn.microsoft.com/library/bb630596

                    $MethodParam = @{

                        CimInstance = $Configuration
                        MethodName  = 'RemoveUrl'
                        Arguments   = $UrlParam
                        Verbose     = $False
                    }
                    $RemoveUrl = Invoke-cimMethod @MethodParam

                    $Message = "        5.$Count.2.$Count2.2  Add URL"
                    Write-Verbose -Message $Message
                                  
                  # “Reserve URL” Method
                  # (WMI MSReportServer_ConfigurationSetting)
                  # http://msdn.microsoft.com/library/bb630612

                    $MethodParam = @{

                        CimInstance = $Configuration
                        MethodName  = 'ReserveUrl'
                        Arguments   = $UrlParam
                        Verbose     = $False
                    }
                    $ReserveUrl = Invoke-cimMethod @MethodParam

                    $Count2++
                }

              # Same arguments for “Remove SSL Certificate Bindings”
              # and “Create SSL Certificate Binding”

                Write-Verbose -Message "    5.$Count.3.  SSL Binding"

                $SslCertificateBindingsParam = @{

                    Application     = $ApplicationName
                    CertificateHash = $CertificateHash
                    IpAddress       = "0.0.0.0"
                    Port            =  443        
                    Lcid            = $CultureInfo.LCID
                }

                Write-Verbose -Message "      5.$Count.3.2.  Remove binding"

              # “Remove SSL Certificate Bindings” Method
              # (WMI MSReportServer_ConfigurationSetting)
              # http://msdn.microsoft.com/library/bb630610

                $MethodParam = @{

                    CimInstance = $Configuration
                    MethodName  = "RemoveSSLCertificateBindings"
                    Arguments   = $SslCertificateBindingsParam
                    Verbose     = $False
                }
                $RemoveSSLCertificateBindings = Invoke-cimMethod @MethodParam
                                  
                Write-Verbose -Message "      5.$Count.3.3.  Add binding"

              # “Create SSL Certificate Binding” Method
              # (WMI MSReportServer_ConfigurationSetting)
              # http://msdn.microsoft.com/library/bb630612

                $MethodParam = @{

                    CimInstance = $Configuration
                    MethodName  = "CreateSSLCertificateBinding"
                    Arguments   = $SslCertificateBindingsParam
                    Verbose     = $False
                }
                $CreateSSLCertificateBinding = Invoke-cimMethod @MethodParam

                $Count++
            }

       #endregion Configure the Report Server Web service and Report Manager URLs

       #region 6/12  Create Database (Generate Database Creation Script)

            Write-Verbose -Message '***'
            $Message = 'Step 6 of 12.  Creating Database'
            Write-Verbose -Message $Message

            $Message = '  6.1.  Generate script'
            Write-Verbose -Message $Message

          # http://msdn.microsoft.com/library/ms152823

            $GenerateDatabaseCreationScriptParam = @{

                DatabaseName     = $DatabaseName
                Lcid             = $CultureInfo.LCID
                IsSharePointMode = $False
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'GenerateDatabaseCreationScript'
                Arguments   = $GenerateDatabaseCreationScriptParam
                Verbose     = $False
            }
            $GenerateDatabaseCreationScript = Invoke-cimMethod @MethodParam

            $Message = '  6.2.  Run script'
            Write-Verbose -Message $Message

            If
            (
                $Configuration.IsInitialized
            )
            {
                $Message = 'Already initialized, skipping'
                Write-Verbose -Message $Message
            }
            Else
            {
                $sqlCmdParam = @{

                    ServerInstance       = $DatabaseInstance.MachineName
                  # Database             = $DatabaseName
                    Query                = $GenerateDatabaseCreationScript.Script
                  # InputFile            = $SQLScriptCurrentPath
                    AbortOnError         = $True
                  # IncludeSqlUserErrors = $True
                    OutputSqlErrors      = $True
                    Verbose              = $False
                }
                $Output = Invoke-sqlCmd @sqlCmdParam
            }

       #endregion Create Database (Generate Database Creation Script)

       #region 7/12  Grant permissions to Database (Generate Database Rights Script)

            Write-Verbose -Message '***'
            $Message = 'Step 7 of 12.  Granting permissions to Database'
            Write-Verbose -Message $Message

            $Message = '  7.1.  Generate script'
            Write-Verbose -Message $Message

          # http://msdn.microsoft.com/library/ms155370

            $GenerateDatabaseRightsScriptParam = @{
                
                DatabaseName     = $DatabaseName
                IsRemote         = $True
                IsWindowsUser    = $True
            }

            Switch
            (
                $ServiceAccountName
            )
            {
                {
                    $psItem -in @( 'Virtual', 'System' )
                }
                {
                    $GenerateDatabaseRightsScriptParam.Add(

                        'UserName', $Configuration.MachineAccountIdentity
                    )
                }
            
                Default
                {
                    $GenerateDatabaseRightsScriptParam.Add(

                        'UserName', $ServiceAccount
                    )
                }
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'GenerateDatabaseRightsScript'
                Arguments   = $GenerateDatabaseRightsScriptParam
                Verbose     = $False
            }
            $GenerateDatabaseRightsScript = Invoke-cimMethod @MethodParam

            $Message = '  7.2.  Run script'
            Write-Verbose -Message $Message

            If
            (
                $Configuration.IsInitialized
            )
            {
                $Message = 'Already initialized, skipping'
                Write-Verbose -Message $Message
            }
            Else
            {
                $sqlCmdParam = @{

                    ServerInstance       = $DatabaseInstance.MachineName
                  # Database             = $DatabaseName
                    Query                = $GenerateDatabaseRightsScript.Script
                  # InputFile            = $SQLScriptCurrentPath
                    AbortOnError         = $True
                  # IncludeSqlUserErrors = $True
                    OutputSqlErrors      = $True
                    Verbose              = $False
                }
                $Output = Invoke-sqlCmd @sqlCmdParam
            }

       #endregion Grant permissions to Database (Generate Database Rights Script)

       #region 8/12  Configure the report server database connection

            Write-Verbose -Message '***'
            $Message = 'Step 8 of 12.  Set Database connection'
            Write-Verbose -Message $Message

          # “Set Database Connection” Method
          # (WMI MSReportServer_ConfigurationSetting)
          # http://msdn.microsoft.com/library/ms155102

            $setDatabaseConnectionParam = @{

                Server          = $DatabaseInstance.MachineName
                DatabaseName    = $DatabaseName
                Password        = [System.String]::Empty
            }

            If
            (
              # Apparently this scenario won't work.
              # You cannot set a gMSA as Database Logon
              # Account. Hence, we should always use
              # the Service (which in case of a Virtual
              # account translates to Computer identity)

                $False
              
              # $InstanceParamCurrent.ReportingAccountVirtual
            )
            {
                $setDatabaseConnectionParam.Add(

                    'CredentialsType', 0 # Windows
                )

                $setDatabaseConnectionParam.Add(

                    'UserName', $ServiceAccount
                )
            }
            Else
            {
                $setDatabaseConnectionParam.Add(

                    'CredentialsType', 2 # Service
                )

                $setDatabaseConnectionParam.Add(

                    'UserName', [System.String]::Empty
                )
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'setDatabaseConnection'
                Arguments   = $setDatabaseConnectionParam
                Verbose     = $False
            }
            $setDatabaseConnection = Invoke-cimMethod @MethodParam

       #endregion Configure the report server database connection

       #region 9/12  Initialize Report Server

            Write-Verbose -Message '***'
            $Message = 'Step 9 of 12.  Initialize Report Server'
            Write-Verbose -Message $Message

            $Message = "  9.1.  Restart $( $Configuration.ServiceName )"
            Write-Verbose -Message $Message

            [System.Void]( Restart-SqlServerReportingServiceEx -Configuration $Configuration )

           # This is not needed as a separate step
           # but we run it as validation jsut in case

            $Message = "  9.2.  Validate initalization"
            Write-Verbose -Message $Message

            $InitializeReportServerParam = @{

                InstallationID = $Configuration.InstallationID
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'InitializeReportServer'
                Arguments   = $InitializeReportServerParam
                Verbose     = $False
            }
            $InitializeReportServer = Invoke-cimMethod @MethodParam

       #endregion Initialize Report Server

       #region 10/12  Test

            Write-Verbose -Message '***'
            $Message = 'Step 10 of 12.  Testing the server'
            Write-Verbose -Message $Message

            $ErrorAction = 'SilentlyContinue'

            $RequestParam = @{

                Uri                   = "https://$ServiceAddress/ReportServer"
                UseDefaultCredentials = $True
                UseBasicParsing       = $True
                Verbose               = $False
                ErrorAction           = $ErrorAction
                ErrorVariable         = 'RequestError'
                Method                = 'Head'
            }

            $Message = '  10.1.  Checking that the server is online'
            Write-Verbose -Message $Message

            $Attempt = 0

          # Write-Verbose -Message $ErrorActionPreference
          # Write-Verbose -Message $Global:ErrorActionPreference
          # $Local:ErrorActionPreference
          # Write-Verbose -Message $Script:ErrorActionPreference

            $ErrorActionPreferenceCurrent       = $ErrorActionPreference
            $ErrorActionPreference              = $ErrorAction

          # $ErrorActionPreferenceCurrentGlobal = $Global:ErrorActionPreference
          # $Global:ErrorActionPreference       = $ErrorAction

          # Write-Verbose -Message $ErrorActionPreference
          # Write-Verbose -Message $Global:ErrorActionPreference
          # $Local:ErrorActionPreference
          # Write-Verbose -Message $Script:ErrorActionPreference

          # $RequestParam.GetEnumerator() | ForEach-Object -Process {

          #     Write-Debug -Message "    Key:    $( $psItem.Key   )"
          #     Write-Debug -Message "    Value:  $( $psItem.Value )"
          # }

            $Request = Invoke-WebRequest @RequestParam
            
            While
            (
                $RequestError
            )
            {
                $Message = "Attempt $Attempt"
                Write-Debug -Message $Message
                
                Write-Warning -Message $RequestError[0].Message

                $Message = 'Waiting'
                Write-Debug -Message $Message
                
                Start-Sleep -Seconds 10

              # Remove-Variable -Name 'RequestError'

              # $RequestError = $Null

                $Message = 'Retrying'
                Write-Debug -Message $Message

              # $RequestParam.GetEnumerator() | ForEach-Object -Process {

              #     Write-Debug -Message "    Key:    $( $psItem.Key   )"
              #     Write-Debug -Message "    Value:  $( $psItem.Value )"
              # }

                $Request = Invoke-WebRequest @RequestParam

                $Message = 'Requested'
                Write-Debug -Message $Message

                $Attempt++

                If
                (
                    $Attempt -ge 10
                )
                {
                    $Message = 'Service failed to respond after 10 retries, restarting'
                    Write-Warning -Message $Message
                    [System.Void]( Restart-SqlServerReportingServiceEx -Configuration $Configuration )
                    $Attempt = 0
                }
            }            

          # Write-Verbose -Message $ErrorActionPreference
          # Write-Verbose -Message $Global:ErrorActionPreference

            $ErrorActionPreference        = $ErrorActionPreferenceCurrent
          # $Global:ErrorActionPreference = $ErrorActionPreferenceCurrentGlobal

          # Write-Verbose -Message $ErrorActionPreference
          # Write-Verbose -Message $Global:ErrorActionPreference

            $Message = '  10.2.  Checking the response'
            Write-Verbose -Message $Message

            $RequestParam.Method = 'Get'

          # $RequestParam.GetEnumerator() | ForEach-Object -Process {

          #     Write-Debug -Message "    Key:    $( $psItem.Key   )"
          #     Write-Debug -Message "    Value:  $( $psItem.Value )"
          # }

            $Request = Invoke-WebRequest @RequestParam

            $Attempt = 0

            While
            (
                $Request.StatusCode -ne 200
            )
            {
                $Message = "Attempt $Attempt"
                Write-Debug -Message $Message
                
                Write-Warning -Message $RequestError[0].Message

                $Message = 'Waiting'
                Write-Debug -Message $Message
                
                Start-Sleep -Seconds 10

              # Remove-Variable -Name 'RequestError'

              # $RequestError = $Null

                $Message = 'Retrying'
                Write-Debug -Message $Message

              # $RequestParam.GetEnumerator() | ForEach-Object -Process {

              #     Write-Debug -Message "    Key:    $( $psItem.Key   )"
              #     Write-Debug -Message "    Value:  $( $psItem.Value )"
              # }

                $Request = Invoke-WebRequest @RequestParam

                $Message = 'Requested'
                Write-Debug -Message $Message

                $Attempt++

                If
                (
                    $Attempt -ge 10
                )
                {
                    $Message = 'Service failed to respond after 10 retries, restarting'
                    Write-Warning -Message $Message
                    [System.Void]( Restart-SqlServerReportingServiceEx -Configuration $Configuration )
                    $Attempt = 0
                }
            }

            Write-Verbose -Message ( $Request.Content -split "`n" )[-4]            

       #endregion Validate
       
       #region 11/12  Backup encryption key

            Write-Verbose -Message '***'
            $Message = 'Step 11 of 12.  Backup encryption key'
            Write-Verbose -Message $Message

            $TimeStamp = Get-Date -Format FileDateTimeUniversal
            $FileName  = "SSRS Encryption Key $( $Configuration.InstanceName ) $( $Configuration.InstallationID ) $TimeStamp.snk"
            $Parent    = ( Resolve-Path -Path '..' ).ProviderPath
            $FilePath  = Join-Path -Path $Parent -ChildPath $FileName

            $BackupEncryptionKeyParam = @{

                Password = $BackupPassword
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'BackupEncryptionKey'
                Arguments   = $BackupEncryptionKeyParam
                Verbose     = $False
            }
            $BackupEncryptionKey = Invoke-cimMethod @MethodParam

            $Stream = [System.io.File]::Create( $FilePath, $BackupEncryptionKey.KeyFile.Length )
            $Stream.Write( $BackupEncryptionKey.KeyFile, 0, $BackupEncryptionKey.KeyFile.Length )
            $Stream.Close()

       #endregion Backup encryption key

       #region 12/12  Set Allowed Resource Extensions for Upload

            Write-Verbose -Message '***'
            $Message = 'Step 12 of 12.  Allowed Resource Extensions for Upload'
            Write-Verbose -Message $Message
            
            $Uri = [System.Uri]"https://$ServiceAddress/ReportServer/ReportService2010.asmx"

            $Proxy = New-WebServiceProxy -Uri $Uri -UseDefaultCredential

            $Type = $Proxy.GetType().Namespace + '.Property'

            $Property = New-Object -TypeName $Type
            $Property.Name = 'AllowedResourceExtensionsForUpload'

            $Current = $Proxy.GetSystemProperties( $Property )

            $ValueCurrent = $Current.Value -split ','

            $ValueAdd = $AllowedResourceExtensionsForUpload | ForEach-Object -Process {

                "*.$psItem"
            }

            $ValueSet = $ValueCurrent + $ValueAdd | Sort-Object -Unique

            $Property.Value = $ValueSet -join ','

            $Proxy.SetSystemProperties( $Property )

          # Write-Verbose -Message '***'

       #endregion
    }

    End
    {
        Return $Configuration
    }
}