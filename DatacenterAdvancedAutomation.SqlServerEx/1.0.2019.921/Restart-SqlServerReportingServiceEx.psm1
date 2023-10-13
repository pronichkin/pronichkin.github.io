Set-StrictMode -Version 'Latest'

Function
Restart-SqlServerReportingServiceEx
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory        = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Configuration
    )

    Process
    {
       #region Disable SSRS

            $setServiceStateParam = @{

                EnableWindowsService = $False
                EnableWebService     = $False
                EnableReportManager  = $False
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'setServiceState'
                Arguments   = $setServiceStateParam
                Verbose     = $False
            }
            $setServiceState = Invoke-cimMethod @MethodParam

       #endregion Disable SSRS

      <#region Restart Service

            $ServiceParm = @{

                Name       = $Configuration.ServiceName            
            }

            If
            (
                $Configuration.CimSystemProperties.ServerName -ne $env:ComputerName
            )
            {
                $cimSession = New-cimSessionEx -Name $Configuration.CimSystemProperties.ServerName

                $ServiceParm.Add( 'cimSession', $cimSession )
            }

            [System.Void]( Restart-ServiceEx @ServiceParm )

          # $InstanceParam = @{

          #     Namespace    = $Configuration.CimSystemProperties.Namespace
          #     ClassName    = 'msReportServer_ConfigurationSetting'
          #     Filter       = "InstanceName='$($Configuration.InstanceName)'"
          #     CimSession   = $cimSession
          #     Verbose      = $False
          # }
          # $Configuration = Get-cimInstance @InstanceParam

       #endregion Restart Service  #>

       #region Enable SSRS

            $setServiceStateParam = @{

                EnableWindowsService = $True
                EnableWebService     = $True
                EnableReportManager  = $True
            }

            $MethodParam = @{

                CimInstance = $Configuration
                MethodName  = 'setServiceState'
                Arguments   = $setServiceStateParam
                Verbose     = $False
            }
            $setServiceState = Invoke-cimMethod @MethodParam

       #endregion Enable SSRS

       #region Restart Service

            $ServiceParm = @{

                Name       = $Configuration.ServiceName            
            }

            If
            (
                $Configuration.CimSystemProperties.ServerName -ne $env:ComputerName
            )
            {
                $cimSession = New-cimSessionEx -Name $Configuration.CimSystemProperties.ServerName

                $ServiceParm.Add( 'cimSession', $cimSession )
            }

            [System.Void]( Restart-ServiceEx @ServiceParm )

          # $InstanceParam = @{

          #     Namespace    = $Configuration.CimSystemProperties.Namespace
          #     ClassName    = 'msReportServer_ConfigurationSetting'
          #     Filter       = "InstanceName='$($Configuration.InstanceName)'"
          #     CimSession   = $cimSession
          #     Verbose      = $False
          # }
          # $Configuration = Get-cimInstance @InstanceParam

       #endregion Restart Service

        Return $Configuration
    }
}