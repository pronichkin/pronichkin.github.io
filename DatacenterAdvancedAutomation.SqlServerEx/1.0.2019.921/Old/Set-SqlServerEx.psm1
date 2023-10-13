Set-StrictMode -Version 'Latest'

Function
Set-SqlServerEx
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
                System.String
            ]
        ]]
        $Instance
    ,
        [Parameter(
            Mandatory = $False
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
        [System.Globalization.CultureInfo]
        $CultureInfo = [System.Globalization.CultureInfo]::GetCultureInfo( 'En-US' )
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.String]]
        $AllowedResourceExtensionsForUpload
    )

    Process
    {
       #region Firewall and port binding

            $Address = [System.Collections.Generic.List[System.String]]::new()

            $Instance | Where-Object -FilterScript { 

                $psItem[ 'EngineAccountName'   ] -or
                $psItem[ 'AnalysisAccountName' ]

            } | ForEach-Object -Process {

                If
                (
                    Test-ClusterNode -Name $psItem.Name
                )
                {
                    $Name = ( Get-Cluster -Name $psItem.Name ).Name
                }
                ElseIf
                (
                    $psItem[ 'ServerAddress' ]
                )
                {
                    $Name = $psItem.ServerAddress
                }
                Else
                {
                    $Name = $psItem.Name
                }

                $Address.Add( ( Resolve-DnsNameEx -Name $Name ) )
            }

            $FirewallRuleParam = @{
                    
                Role = 'SQL Server'
                Name = $Address | Sort-Object -Unique
            }
            [System.Void]( New-NetFirewallRuleEx @FirewallRuleParam )
    
       #endregion Firewall and port binding

       #region Role-specific configuration

            $Instance | ForEach-Object -Process {

                If
                (
                    $psItem[ 'ReportingAccountName' ]
                )
                {
                    $ReportingServiceParam = @{
                
                        ServerAddress         = $psItem.ServerAddress
                        ServiceAddress        = $psItem.ServiceAddress                    
                        InstanceName          = $psItem.Name
                        DatabaseName          = $psItem.DatabaseName
                        DatabaseServerAddress = ( Resolve-dnsNameEx -Name $psItem.DatabaseServerName )
                        ServiceAccountName    = $psItem.ReportingAccountName
                        BackupPassword        = $psItem.BackupPassword
                        CultureInfo           = $CultureInfo
                    }

                    If
                    (
                        $psItem[ 'DatabaseInstanceName' ]
                    )
                    {
                        $ReportingServiceParam.Add(
                            'DatabaseInstanceName',
                            $psItem.DatabaseInstanceName
                        )
                    }

                    If
                    (
                        $psItem[ 'ReportingAccountPassword' ]
                    )
                    {
                        $ReportingServiceParam.Add(
                            'ServiceAccountPassword',
                            $psItem.ReportingAccountPassword
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

                    [System.Void]( Set-SqlServerReportingService @ReportingServiceParam )
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