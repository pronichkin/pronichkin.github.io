<#
    This is object type-specific wrapper for “Start-scJobEx.” It prepares the
    parameters which are needed to work with either “Compliance Scan” or
   “Update Remediation” in VMM
#>

Set-StrictMode -Version 'Latest'

Function
Start-scComplianceStatusEx
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateSet(
                'Scan',
                'Remediate'    
            )]
            [System.String]
            $Mode
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]
            $ManagedComputer
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $TaskName = $Mode
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $ThrottleLimit = 5
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $Retry = 3
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.Core.Connection.Connection]
            $OpsMgrConnection
,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.SwitchParameter]
            $Force
    )
     
    Begin
    {  
      # $Current  = 0

        $Message = "  $TaskName"
        Write-Verbose -Message $Message

      # Input collection

        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]]$ComplianceStatus =
            $ManagedComputer.ComplianceStatus | Sort-Object -Property 'Name'

        If
        (
            $ManagedComputer.Count -gt $ComplianceStatus.Count
        )
        {
            $Message = 'The following computers do not have Baselines assigned and will be skipped'
            Write-Warning -Message $Message

            $ManagedComputer | Where-Object -FilterScript {
                -Not $psItem.ComplianceStatus
            } | Sort-Object -Property 'FullyQualifiedDomainName' | ForEach-Object -Process {
                $Message = "  * $( $psItem.FullyQualifiedDomainName )"
                Write-Warning -Message $Message
            }
        }

       #region Prepare variables for the main loop

        Switch
        (
            $Mode
        )
        {
            'Scan'
            {
              # Property value to evaluate status                

                $Process  = @( 'Unknown' ) #, 'NonCompliant' )   # Overall Compliance State    'PendingScan'  # Status
                $Progress = @( 'Scanning'                    )   # Status
                $Complete = @( 'NonCompliant', 'Compliant'   )   # Overall Compliance State

              # Script block syntax is specific to “Start-scJobEx” function.
              # The current object to process is in “$Start” variable. The loop
              # iterates thru “Compliance Status” objects, while actual Scan or
              # Remediation operates “Managed Computer” object (Compliance
              # Status Target.)

                $ScriptBlock = {

                    $ProcedureParam = @{

                      # vmmServer          = $vmmServer
                        vmmManagedComputer = $Start.Target
                        RunAsynchronously  = $True
                    }
                    [System.Void]( Start-scComplianceScan @ProcedureParam )
                }

              # Availability Set

              # Note. Technically, no Availability Set is required for Scan
              # operation. The below was added for testing (to validate filter
              # syntax to be used with Remediate operation.) After testing
              # completes, it should be replaced with a simple “{ $True }”

             <# $FilterParallel = {
        
                    If
                    (
                        $cProgress
                    )
                    {
                        $psItem.Target.Description.Split( "`n" )[0] -notin ( $cProgress.Target.Description | ForEach-Object -Process { $psItem.Split( "`n" )[0] } )
                    }
                    Else
                    {
                        $True
                    }
                }  #>

                $FilterParallel = { $True }
            }

            'Remediate'
            {
              # Property value to evaluate status

                $Process  = @( 'NonCompliant'               )  # Overall Compliance State     'PendingReboot' # Status
                $Progress = @( 'Remediating', 'Scanning'    )  # Status
                $Complete = @( 'Compliant', 'PendingReboot' )  # Overall Compliance State

                $MaintenanceMode = [System.Collections.Generic.List[Microsoft.EnterpriseManagement.Monitoring.MaintenanceWindow]]::new()

              # Script block syntax is specific to “Start-scJobEx” function.
              # The current object to process is in “$Start” variable. The loop
              # iterates thru “Compliance Status” objects, while actual Scan or
              # Remediation operates “Managed Computer” object (Compliance
              # Status Target.)

                $ScriptBlock = {

                    If
                    (
                        $OpsMgrConnection
                    )
                    {
                        $MaintenanceModeParam = @{

                            Name       = $Start.Name
                            Hour       =  4
                            Comment    = 'Installing updates'
                            Connection = $OpsMgrConnection
                        }
                        $MaintenanceMode.AddRange( [System.Collections.Generic.List[Microsoft.EnterpriseManagement.Monitoring.MaintenanceWindow]]( Start-scomMaintenanceModeEx @MaintenanceModeParam ) )
                    }

                    $ProcedureParam = @{

                      # vmmServer          = $vmmServer
                        vmmManagedComputer = $Start.Target
                        RunAsynchronously  = $True
                    }

                    If
                    (
                        $Start.Name -eq ( Resolve-dnsNameEx -Name $env:ComputerName )
                    )
                    {
                        $Message = 'Updating the local computer, however reboot will be suppressed. Please restart manually when possible'
                        Write-Warning -Message $Message

                        $ProcedureParam.Add( "SuspendReboot",     $True  )
                    }
                    Else
                    {
                        $ProcedureParam.Add( "SuspendReboot",     $False )
                    }
                    
                    $ProcedureParam.Add( "EnableMaintenanceMode", $True  )                    

                    [System.Void]( Start-scUpdateRemediation @ProcedureParam )

                  # We cannot stop Maintenance Mode here because the Remediation
                  # is running asynchronously. We will have to stop it at the
                  # very end.

                 <# If
                    (
                        $MaintenanceMode
                    )
                    {
                        $MaintenanceModeParam = @{

                            MaintenanceMode = $MaintenanceMode
                            Comment         = 'Installing updates done'
                            Connection      = $OpsMgrConnection
                        }
                        [System.Void]( Stop-scomMaintenanceModeEx @MaintenanceModeParam )
                    }  #>
                }

              # Availability Set

                $FilterParallel = {
        
                    If
                    (
                        $cProgress
                    )
                    {
                        $psItem.Target.Description.Split( "`n" )[0] -notin ( $cProgress.Target.Description | ForEach-Object -Process { $psItem.Split( "`n" )[0] } )
                    }
                    Else
                    {
                        $True
                    }
                }
            }
        }

      # Filter expression to evaluate status

        $FilterProcess  = { $psItem.OverallComplianceState -in $Process  }
        $FilterProgress = { $psItem.Status                 -in $Progress }
        $FilterComplete = { $psItem.OverallComplianceState -in $Complete }

       #endregion Prepare variables for the main loop
    }

    Process
    {
       #region Main loop

            If
            (
                $ComplianceStatus
            )
            {
                $JobParam = @{
            
                    Object         = $ComplianceStatus
                    TaskName       = $TaskName                
                    ScriptBlock    = $ScriptBlock
                    FilterProcess  = $FilterProcess
                    FilterProgress = $FilterProgress
                    FilterComplete = $FilterComplete
                    FilterParallel = $FilterParallel
                    ThrottleLimit  = $ThrottleLimit
                    Retry          = $Retry
                    Force          = $Force
                }
                [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]]$ComplianceStatus =
                    Start-scJobEx @JobParam

                $PendingReboot = $ComplianceStatus | Where-Object -FilterScript {
                    $psItem.Status -eq 'PendingReboot'
                }

                If
                (
                    $PendingReboot
                )
                {
                    $Message = 'The following computers are pending reboot. Please restart the machine, then scan it *manually*'
                    Write-Warning -Message $Message

                    $PendingReboot | Sort-Object -Property 'Name' | ForEach-Object -Process {
                        $Message = "  * $( $psItem.Name )"
                        Write-Warning -Message $Message
                    }
                }
            }
            Else
            {
                 $Message = '    There are no Baseline(s) attached to the specified Managed Computer(s)'
                 Write-Verbose -Message $Message
            }

       #endregion Main loop
    }

    End
    {
       #region Finalize

          # Remove Maintenance Mode in OpsMgr

            Switch
            (
                $Mode
            )
            {
                'Scan'
                {
                  # Nothing to clean up
                }

                'Remediate'
                {
                    If
                    (
                        $MaintenanceMode
                    )
                    {
                        $MaintenanceModeParam = @{

                            MaintenanceMode = $MaintenanceMode
                            Comment         = 'Installing updates done'
                            Connection      = $OpsMgrConnection
                        }
                        [System.Void]( Stop-scomMaintenanceModeEx @MaintenanceModeParam )
                    }
                }
            }

            $Message = "  $TaskName done"
            Write-Verbose -Message $Message

       #endregion Finalize

        Return $ComplianceStatus
    }
}