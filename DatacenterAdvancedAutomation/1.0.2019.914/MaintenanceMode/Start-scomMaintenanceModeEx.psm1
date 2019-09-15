Function
Start-scomMaintenanceModeEx
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[System.String]]
            $Name
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $Hour = 2
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
        $MonitoringObjectCurrent = [System.Collections.Generic.List[Microsoft.EnterpriseManagement.Monitoring.MonitoringObject]]::new()

      # Looking for instanes of “Windows Cluster” class first. This means if
      # the name supplied belongs to a cluster, we're putting the entire cluster
      # into Maintenance mode.

        $ClassName = @(
          
          # 'Cluster Resource Group'
            'Windows Cluster'
          # 'Windows Cluster Service'
          # 'Windows Computer'
        )

        $ClassParam = @{

            DisplayName = $ClassName
            scSession   = $Connection
        }
        $Class = Get-scomClass @ClassParam

        $MonitoringObjectParam = @{
        
            Class     = $Class
            scSession = $Connection
        }
        $MonitoringObject = Get-scomClassInstance @MonitoringObjectParam

        $Name | ForEach-Object -Process {

            $Filter = "*$psItem*"

            $MonitoringObject | Where-Object -FilterScript {
                $psItem.DisplayName -Like $Filter
            } | ForEach-Object -Process {
                $MonitoringObjectCurrent.Add( $psItem )
            }
        }

        If
        (
            $MonitoringObjectCurrent
        )
        {
            $Message = 'Putting cluster to maintenance mode in OpsMgr'
        }
        Else
        {
          # If no cluster was found, this means that the name supplied belongs
          # to an individual computer. Looking for instances of “Windows Computer”
          # class which is generic and normally hosts multiple child instances.

          # Also looking specifically for “Cluster Resource Group” because if
          # the computer is actually a hihgly available virtual machine, the
          # cluster group on the host is a separate entity which maintains no
          # connection with the Guest OS from OpsMgr standpoint. (Even if both
          # host and guest are monitored by the same OpsMgr management group,
          # which is also not always the case.)

            $ClassName = @(
                
                'Cluster Resource Group'              
              # 'Windows Cluster'
              # 'Windows Cluster Service'
                'Windows Computer'
            )

            $ClassParam = @{

                DisplayName = $ClassName
                scSession   = $Connection
            }
            $Class = Get-scomClass @ClassParam

            $MonitoringObjectParam = @{
        
                Class     = $Class
                scSession = $Connection
            }
            $MonitoringObject = Get-scomClassInstance @MonitoringObjectParam

            $Name | ForEach-Object -Process {

                $Filter = "*$psItem*"

                $MonitoringObject | Where-Object -FilterScript {
                    $psItem.DisplayName -Like $Filter
                } | ForEach-Object -Process {
                    $MonitoringObjectCurrent.Add( $psItem )
                }
            }

         <# Finally, if the computer happens to be member of a cluster, there's
          # also an instance of “Windows Cluster Service” class which is hosted
          # under the name of computer—but for some reason, does not inherit
          # the Maintenance mode. So we need to put it separately.

            $ClassName = @(
              
              # 'Cluster Resource Group'                
              # 'Windows Cluster'
                'Windows Cluster Service'
              # 'Windows Computer'
            )

            $ClassParam = @{

                DisplayName = $ClassName
                scSession   = $Connection
            }
            $Class = Get-scomClass @ClassParam

            $MonitoringObjectParam = @{
        
                Class     = $Class
                scSession = $Connection
            }
            $MonitoringObject = Get-scomClassInstance @MonitoringObjectParam

            $Name | ForEach-Object -Process {

                $Filter = "*$psItem*"

              # Looking for Path instead of Display name

                $MonitoringObject | Where-Object -FilterScript {
                    $psItem.Path -Like $Filter
                } | ForEach-Object -Process {
                  # $MonitoringObjectCurrent.Add( $psItem )
                }
            }  #>

            $Message = 'Putting computer to maintenance mode in OpsMgr'
        }

        Write-Verbose -Message $Message

        $MonitoringObjectCurrent | Sort-Object -Property 'DisplayName' | ForEach-Object -Process {

            If
            (
                -Not $psItem.InMaintenanceMode
            )
            {
                Write-Debug -Message $psItem.FullName

                $MaintenanceModeParam = @{

                    Instance = $psItem
                    EndTime  = ( Get-Date ).AddHours( $Hour )
                    Comment  = $Comment
                    PassThru = $True
                }
                [System.Void]( Start-scomMaintenanceMode @MaintenanceModeParam )
            }
        }

        $MaintenanceModeParam = @{
        
            Instance  = $MonitoringObjectCurrent
            scSession = $Connection
        }
        $MaintenanceMode = Get-scomMaintenanceMode @MaintenanceModeParam

        Return $MaintenanceMode
    }
}