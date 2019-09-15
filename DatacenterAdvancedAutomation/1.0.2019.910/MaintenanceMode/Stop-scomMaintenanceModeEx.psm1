Function
Stop-scomMaintenanceModeEx
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[Microsoft.EnterpriseManagement.Monitoring.MaintenanceWindow]]
            $MaintenanceMode
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Comment = 'Test'
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.Core.Connection.Connection]
            $Connection
    )
     
    Process
    {
        [System.Collections.Generic.List[Microsoft.EnterpriseManagement.Monitoring.MonitoringObject]]$MonitoringObject =
            Get-scomClassInstance -Id $MaintenanceMode.MonitoringObjectId

        $MonitoringObject | Sort-Object -Property 'DisplayName' | ForEach-Object -Process {            

            If
            (
                $psItem.InMaintenanceMode
            )
            {
                Write-Debug -Message $psItem.FullName

                $psItem.StopMaintenanceMode(

                    [System.DateTime]::Now.ToUniversalTime(),
                    [Microsoft.EnterpriseManagement.Common.TraversalDepth]::Recursive
                )
            }
        }

     <# $MaintenanceModeParam = @{
        
            MaintenanceModeEntry = $MaintenanceMode
            EndTime              = Get-Date
            Comment              = $Comment
            PassThru             = $True
        }
        $MonitoringObjectCurrent = Set-scomMaintenanceMode @MaintenanceModeParam  #>

        Return $MonitoringObject
    }
}