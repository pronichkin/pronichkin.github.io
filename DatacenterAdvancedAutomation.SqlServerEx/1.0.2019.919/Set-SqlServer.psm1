Set-StrictMode -Version 'Latest'

Function
Set-SqlServer
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
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServiceAddress = $ServerAddress
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.Collections.Generic.Dictionary[System.String, System.String]]]
        $Instance
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
        $Instance | ForEach-Object -Process {

            $InstanceParamCurrent = $psItem

            If
            (
                $InstanceParamCurrent[ 'EngineAccountName'   ] -or
                $InstanceParamCurrent[ 'AnalysisAccountName' ]
                
            )
            {
                $FirewallRuleParam = @{
                    
                    Role = 'SQL Server'
                }

                $AddressParam = @{
                
                    Name = $InstanceParamCurrent.InstanceName
                    Wait = $False
                }
                $InstanceAddress = Resolve-dnsNameEx @AddressParam                

                If
                (
                    $InstanceAddress
                )
                {
                    $FirewallRuleParam.Add( 'Name', $InstanceAddress )
                }
                Else
                {
                    $FirewallRuleParam.Add( 'Name', $ServerAddress   )
                }

                [System.Void]( New-NetFirewallRuleEx @FirewallRuleParam )
            }

            If
            (
                $InstanceParamCurrent[ 'ReportingAccountName' ]
            )
            {
                $ReportingServiceParam = @{
                
                    ServerAddress         = $ServerAddress
                    ServiceAddress        = $ServiceAddress
                    CultureInfo           = $CultureInfo

                    InstanceName          = $InstanceParamCurrent.InstanceName
                    DatabaseName          = $InstanceParamCurrent.DatabaseName
                    DatabaseServerAddress = ( Resolve-dnsNameEx -Name $InstanceParamCurrent.DatabaseServerName )
                    ServiceAccountName    = $InstanceParamCurrent.ReportingAccountName
                    BackupPassword        = $InstanceParamCurrent.BackupPassword
                }

                If
                (
                    $InstanceParamCurrent[ 'DatabaseInstanceName' ]
                )
                {
                    $ReportingServiceParam.Add(
                        'DatabaseInstanceName',
                        $InstanceParamCurrent.DatabaseInstanceName
                    )
                }

                If
                (
                    $InstanceParamCurrent[ 'ReportingAccountPassword' ]
                )
                {
                    $ReportingServiceParam.Add(
                        'ServiceAccountPassword',
                        $InstanceParamCurrent.ReportingAccountPassword
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
    }
}