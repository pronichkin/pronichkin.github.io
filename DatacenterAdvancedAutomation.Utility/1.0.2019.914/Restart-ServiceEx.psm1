Set-StrictMode -Version 'Latest'

Function
Restart-ServiceEx
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Service'
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Service
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Name'
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory        = $False,
            ParameterSetName = 'Name'
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession]
        $cimSession
    )

    Process
    {
        If
        (
            $Service
        )
        {            
            $Filter  = "Name = '$($Service.Name)'"
        }
        ElseIf
        (
            $Name
        )
        {
            $Filter  = "Name = '$Name'"
        }

        $ServiceParam = @{
                
            ClassName  = 'win32_Service'
            Filter     = $Filter
          # cimSession = $cimSession                          
            Verbose    = $False
       }

        If
        (
            $cimSession                          
        )
        {
            $ServiceParam.Add( 'cimSession', $cimSession )
        }
        ElseIf
        (
            $Service -And
            $Service.CimSystemProperties.ServerName -ne $env:ComputerName
        )
        {
            $cimSession = New-cimSessionEx -Name $Service.CimSystemProperties.ServerName
            $ServiceParam.Add( 'cimSession', $cimSession )
        }

        $Service = Get-cimInstance @ServiceParam

        $MethodParam = @{
        
            InputObject = $Service
            MethodName  = 'StopService'
            Verbose     = $False
        }
        [System.Void]( Invoke-cimMethod @MethodParam )

        While
        (
            $Service.State -ne 'Stopped'
        )
        {
            Start-Sleep -Seconds 10

            $Service = Get-cimInstance @ServiceParam
        }

        $MethodParam.MethodName = 'StartService'
    
        [System.Void]( Invoke-cimMethod @MethodParam )
        
        While
        (
            $Service.State -ne 'Running'
        )
        {
            Start-Sleep -Seconds 10

            $Service = Get-cimInstance @ServiceParam
        }

        Return $Service
    }
}