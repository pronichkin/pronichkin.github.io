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
Set-SqlServerEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateSet(
            'Prepare Failover Cluster',
            'Complete Failover Cluster',
            'AddNode',
            'RemoveNode',
            'Patch',
            'Install',
            'Configure'
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
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $AvailabilityGroup
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $StandAlone
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Collation = 'Latin1_General_100_CI_AS'    
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
        [System.Collections.Generic.List[System.String]]
        $AllowedResourceExtensionsForUpload
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateTemplateName
    )

    Begin
    {
      # Convert input values into strongly typed structures

        $Instance = [System.Collections.Generic.Dictionary[        
            System.String,
            System.Collections.Generic.Dictionary[
                System.String,
                System.String
            ]
        ]]::new()

        If
        (
            $AvailabilityGroup
        )
        {
            $AvailabilityGroup.GetEnumerator() | ForEach-Object -Process {

                $psItem.Value.Instance.GetEnumerator() | ForEach-Object -Process {

                    $InstanceCurrentName = $psItem.Key

                    $InstanceCurrentProperty = [System.Collections.Generic.Dictionary[System.String, System.String]]::new()

                    $psItem.Value.GetEnumerator() | ForEach-Object -Process {

                        $InstanceCurrentProperty.Add(

                            [System.String]$psItem.Key,
                            [System.String]$psItem.Value
                        )
                    }

                    $Instance.Add(

                        $InstanceCurrentName,
                        $InstanceCurrentProperty
                    )
                }
            }
        }

        If
        (
            $StandAlone
        )
        {
            $StandAlone.GetEnumerator() | ForEach-Object -Process {

                $ServerName = $PSItem.Key

                $psItem.Value.GetEnumerator() | ForEach-Object -Process {

                    $InstanceCurrentName = $psItem.Key

                    $InstanceCurrentProperty = [System.Collections.Generic.Dictionary[System.String, System.String]]::new()

                    $psItem.Value.GetEnumerator() | ForEach-Object -Process {

                        $InstanceCurrentProperty.Add(

                            [System.String]$psItem.Key,
                            [System.String]$psItem.Value
                        )
                    }

                    $InstanceCurrentProperty.Add(

                        [System.String]'ServerName',
                        [System.String]$ServerName
                    )

                    $Instance.Add(

                        $InstanceCurrentName,
                        $InstanceCurrentProperty
                    )
                }
            }
        }
    }

    Process
    {
        Switch
        (
            $Action
        )
        {
            {
                $psItem -in @(

                    'Prepare Failover Cluster',
                    'Complete Failover Cluster',
                    'AddNode',
                    'RemoveNode',
                    'Patch',
                    'Install'
                )
            }
            {
                $ActionCurrent = $Action.Replace( ' ', [System.String]::Empty )

                $SqlServerParam = @{
    
                    Action      = $ActionCurrent
                    Version     = $Version
                    ProductKey  = $ProductKey
                    Collation   = $Collation
                    Update      = $Update
                }

                $InstanceLocal = [System.Collections.Generic.Dictionary[        
                    System.String,
                    System.Collections.Generic.Dictionary[
                        System.String,
                        System.String
                    ]
                ]]::new()
                
                $Instance.GetEnumerator() |
                    Where-Object -FilterScript {
                        $psItem.Value[ 'ServerName' ] -eq $env:ComputerName
                    } | ForEach-Object -Process {
                        $InstanceLocal.Add( $psItem.Key, $psItem.Value )
                    }

                If
                (
                    $InstanceLocal.Count
                )
                {
                    $SqlServerParam.Add( 'Instance', $InstanceLocal )
                }
                Else
                {
                    $SqlServerParam.Add( 'Instance', $Instance )
                }

                If
                (
                    Test-Path -Path 'Variable:\CertificateTemplateName'
                )
                {
                    $SqlServerParam.Add( 'CertificateTemplateName', $CertificateTemplateName )
                }

                Install-SqlServerEx @SqlServerParam
            }

            'Configure'
            {
               #region Firewall and port binding

                    [System.Void]( Import-ModuleEx -Name 'FailoverClusters' )

                    $Address = [System.Collections.Generic.List[System.String]]::new()

                    $Instance.GetEnumerator() | Where-Object -FilterScript { 

                        $psItem.Value[ 'EngineAccountName'   ] -or
                        $psItem.Value[ 'AnalysisAccountName' ]

                    } | ForEach-Object -Process {

                        If
                        (
                            $psItem.Value[ 'ServerName' ]
                        )
                        {
                            $Address.Add( ( Resolve-DnsNameEx -Name $psItem.Value.ServerName ) )
                        }
                        Else
                        {
                            $Cluster = Test-clusterNodeEx -Name $psItem.Key

                            If
                            (
                                $Cluster
                            )
                            {
                                $Address.Add( ( Resolve-DnsNameEx -Name $Cluster.Name ) )
                            }
                            Else
                            {
                                $Address.Add( ( Resolve-DnsNameEx -Name $psItem.Key ) )
                            }
                        }
                    }

                    $FirewallRuleParam = @{
                    
                        Name = $Address | Sort-Object -Unique
                        Role = 'SQL Server'                            
                    }
                    [System.Void]( New-NetFirewallRuleEx @FirewallRuleParam )
    
               #endregion Firewall and port binding

               #region Role-specific configuration

                    $Instance.GetEnumerator() | ForEach-Object -Process {

                        If
                        (
                            $psItem.Value[ 'ReportingAccountName' ]
                        )
                        {
                            $ReportingServiceParam = @{
                
                                InstanceName          = $psItem.Key
                                ServerAddress         = ( Resolve-dnsNameEx -Name $psItem.Value.ServerName )
                                ServiceAddress        = ( Resolve-dnsNameEx -Name $psItem.Value.ServiceName )                      
                                DatabaseName          = $psItem.Value.DatabaseName
                                DatabaseServerAddress = ( Resolve-dnsNameEx -Name $psItem.Value.DatabaseServerName )
                                ServiceAccountName    = $psItem.Value.ReportingAccountName
                                BackupPassword        = $psItem.Value.BackupPassword
                                CultureInfo           = $CultureInfo
                            }

                            If
                            (
                                $psItem.Value[ 'DatabaseInstanceName' ]
                            )
                            {
                                $ReportingServiceParam.Add(
                                    'DatabaseInstanceName',
                                    $psItem.Value.DatabaseInstanceName
                                )
                            }

                            If
                            (
                                $psItem.Value[ 'ReportingAccountPassword' ]
                            )
                            {
                                $ReportingServiceParam.Add(
                                    'ServiceAccountPassword',
                                    $psItem.Value.ReportingAccountPassword
                                )
                            }

                            If
                            (
                                $AllowedResourceExtensionsForUpload
                            )
                            {
                                $ReportingServiceParam.Add(
                                    'AllowedResourceExtensionsForUpload',
                                    $AllowedResourceExtensionsForUpload
                                )
                            }

                            [System.Void]( Set-SqlServerReportingServiceEx @ReportingServiceParam )
                        }
                    }

               #endregion Role-specific configuration
            
               #region Availability Group

                    If
                    (
                        $AvailabilityGroup
                    )
                    {
                        [System.Void](            
                            Set-SqlAvailabilityGroupEx -AvailabilityGroup $AvailabilityGroup
                        )
                    }

               #endregion Availability Group            
            }
        }
    }

    End
    {
        $Message = 'All done'
        Write-Verbose -Message $Message
    }
}