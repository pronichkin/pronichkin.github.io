<#
    This is intended to be a generic (type-independent) looping mechanism
    for anything that supports asynchronous job processing, like VMM. Note
    that it does not make use of VMM “Job” object for tracking. Instead,
    it determines object state by watching it properties.
#>

Set-StrictMode -Version 'Latest'

Function
Start-scJobEx
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
          # [System.Collections.Generic.List[System.Object]]
            $Object
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $TaskName = 'Processing'
        ,            
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.ScriptBlock]
            $ScriptBlock
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.ScriptBlock]
            $FilterProcess
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.ScriptBlock]
            $FilterProgress
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.ScriptBlock]
            $FilterComplete
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.ScriptBlock]
            $FilterParallel = { $True }
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
            [System.Management.Automation.SwitchParameter]
            $Force
    )
     
    Begin
    {
          # Write-Debug -Message 'Entering Start-scJobEx'

            $TypeName = $Object.GetType().GenericTypeArguments.FullName

          # Write-Debug -Message $TypeName

          # All objects to process, with a counter to track attempts
            $cProcess  = New-Object -TypeName "System.Collections.Generic.Dictionary[$TypeName, System.Int32]"
            $Object | Where-Object -FilterScript $FilterProcess |
                ForEach-Object -Process {  $cProcess.Add( $psItem, 0 ) }
            
          # Previously completed
            $cComplete = New-Object -TypeName "System.Collections.Generic.List[$TypeName]"

            $Object | Where-Object -FilterScript $FilterComplete | ForEach-Object -Process {

                If
                (
                    $Force
                )
                {
                    $cProcess.Add( $psItem, 0 )
                }
                Else
                {
                    $cComplete.Add( $psItem   )
                }
            }

          # Write-Debug -Message $cComplete.gettype().fullname

            $cProgress = New-Object -TypeName "System.Collections.Generic.List[$TypeName]"

            $Total   = @( $Object ).Count
    }

    Process
    {
       #region Main loop

            While
            (
                $cProcess.GetEnumerator() | Where-Object -FilterScript {                
                    (
                        $psItem.Key   -notIn $cComplete -and
                        $psItem.Value -lt $Retry
                    ) -or $cProgress
                }
            )
            {
             <# [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$ManagedComputerPending  =
                    $ManagedComputerBaseline | Where-Object -FilterScript {
                        $psItem.ComplianceStatus.OverallComplianceState -in $cProcess
                    }

                [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$ManagedComputerProgress =
                    $ManagedComputerBaseline | Where-Object -FilterScript {
                        $psItem.ComplianceStatus.Status                 -in $cProgress
                    }  #>

              # Current progress

                $cProgress = New-Object -TypeName "System.Collections.Generic.List[$TypeName]"

                $cProcess.Keys | Where-Object -FilterScript $FilterProgress |
                    ForEach-Object -Process { $cProgress.Add( $psItem    ) }

                $Message = "    Running $( $cProgress.Count )"
                Write-Debug -Message $Message

              # Update Completed

                $cProcess.Keys | Where-Object -FilterScript $FilterComplete |
                    ForEach-Object -Process { 

                        If
                        (
                            $psItem -notin $cComplete -and
                            (
                                -Not $Force -or
                                $cProcess[ $psItem ] -ge 1
                            )
                        )
                        {
                            $Message = "      $( ( Get-Date -DisplayHint Time ).DateTime )  $( $psItem.Name ) done"
                            Write-Debug -Message $Message  

                          # Cannot modify, otherwise “An error occurred while
                          # enumerating through a collection: Collection was
                          # modified; enumeration operation may not execute”
                          
                          # $cProcess.Remove( $psItem )
                            $cComplete.Add( $psItem )
                        }
                    }

                $ProgressRatio    = $cComplete.Count / $Total
                $ProgressPercent  = $ProgressRatio * 100
                $MessageStatus    = 'Done ' + $cComplete.Count + ' of ' + $Total
                Write-Debug -Message $MessageStatus

              # Pending

                $Global:cPending = New-Object -TypeName "System.Collections.Generic.List[$TypeName]"

                $cProcess.GetEnumerator() | Where-Object -FilterScript {
                
                    $psItem.Key   -notIn $cComplete -and
                    $psItem.Key   -notIn $cProgress -and
                    $psItem.Value -lt $Retry
                } | ForEach-Object -Process { $cPending.Add( $psItem.Key ) }

              # We cannot start multiple items a time because each of them needs
              # to be evaluated against Availability Set (“FilterParallel”)
              # concerning all currently running others. (That would require
              # re-populating “Progress”, hence deferring for the next loop)

                $Global:Start = $cPending |  # Sort-Object -Property 'Name' |
                    Where-Object -FilterScript $FilterParallel |
                    Select-Object -First 1

                If
                (
                    $Start -and
                    $cProgress.Count -lt $ThrottleLimit                    
                )
                {
                    $Message = "      $( ( Get-Date -DisplayHint Time ).DateTime )  Started $( $Start.Name )"
                    Write-Debug -Message $Message

                    Invoke-Command -scriptBlock $ScriptBlock

                  # Sometimes the object in VMM will not transition into “progress”
                  # state immediately. This will cause the same object to be
                  # processed again at the very next loop (and likely to error.)
                  # Hence, we wait for it to either transition into progress state,
                  # or to complete.

                    $Attempt =   0
                    $Limit   = 300

                    While
                    (
                        -Not (
                            ( $Start | Where-Object $FilterProgress ) -Or
                            ( $Start | Where-Object $FilterComplete )
                        ) -Or ( $Attempt -gt $Limit )
                    )
                    {
                        $MessageAttempt = '        Waiting for the job to start...'
                        Write-Debug -Message $MessageAttempt
                        Start-Sleep -Seconds 1

                        $Attempt++
                    }

                    If
                    (
                        $Attempt -eq $Limit
                    )
                    {
                        $MessageAttempt = "        Job did not start in $Limit seconds. Continuing anyway"
                        Write-Warning -Message $MessageAttempt
                    }
                    Else
                    {
                        $MessageAttempt = "        Job started after $Attempt seconds"
                        Write-Debug -Message $MessageAttempt
                    }

                    $cProcess[ $Start ]++
                }
                ElseIf
                (
                    $cProgress.Count -ge $ThrottleLimit
                )
                {
                    $Message = 'There''s more to start but maximum concurrent jobs is reached, waiting'
                    Write-Debug -Message $Message
                }
                ElseIf
                (
                    $cPending
                )
                {
                    $Message = 'There''s more to start but in the same Availability Set, waiting'
                    Write-Debug -Message $Message
                }
                Else
                {
                    $Message = 'Nothing more to start, but there are tasks in progress, waiting'
                    Write-Debug -Message $Message
                }

                $ProgressParam = @{

                    Activity         = $TaskName
                    CurrentOperation = $Message
                    PercentComplete  = $ProgressPercent
                    Status           = $MessageStatus
                }
                Write-Progress @ProgressParam

              # $Current.Add( $ManagedComputerCurrent )

              # [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$Current =
              #     $Current | Sort-Object -Unique

                Start-Sleep -Seconds 1
            }

       #endregion Main loop

       #region Finalize

          # Update results

            $cProcess.Keys | Where-Object -FilterScript $FilterComplete |
                ForEach-Object -Process { 

                    If
                    (
                        $psItem -notin $cComplete
                    )
                    {
                        $Message = "      $( ( Get-Date -DisplayHint Time ).DateTime )  $( $psItem.Name ) done"
                        Write-Debug -Message $Message  

                      # $cProcess.Remove( $psItem )  # Cannot modify, otherwise “An error occurred while enumerating through a collection: Collection was modified; enumeration operation may not execute”
                        $cComplete.Add( $psItem )
                    }
                }

          # Submit 100% completion so that progress bar disappears

            $ProgressRatio    = $cComplete.Count / $Total
            $ProgressPercent  = $ProgressRatio * 100
            $MessageStatus    = 'Done ' + $cComplete.Count + ' of ' + $Total
            Write-Debug -Message $MessageStatus

            $Message = "      All done"
            Write-Debug -Message $Message

            $ProgressParam = @{

                Activity         = $TaskName
                CurrentOperation = $Message
                PercentComplete  = $ProgressPercent
                Status           = $MessageStatus
            }
            Write-Progress @ProgressParam

          # Remove-Variable -Name 'Current'

       #endregion Finalize
    }

    End
    {
          # Output failures

            $cProcess.GetEnumerator() | Where-Object -FilterScript {
                $psItem.Key   -notIn $cComplete -and
                $psItem.Value -eq $Retry
            } | ForEach-Object -Process {

                $Message = "$( $psItem.Key.Name ) did not succeed after $Retry attempts"
                Write-Warning -Message $Message
            }

          # Output success

          # Write-Debug -Message 'Returning'
          # Write-Debug -Message $cComplete.gettype().fullname

          # Write-Debug -Message 'Exiting  Start-scJobEx'

          # Comma is necessary to force returning an array—even if there's
          # a single element

            Return ,$cComplete
    }
}