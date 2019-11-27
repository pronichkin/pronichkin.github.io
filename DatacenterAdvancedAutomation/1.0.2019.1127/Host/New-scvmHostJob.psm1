Set-StrictMode -Version 'Latest'

Function
New-scvmHostJob
{
   #region Data

        [cmdletBinding()]

        Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig]]
            $Configuration
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $ThrottleLimit = 5
        )

   #endregion Data

   #region Code

       #region Initialize
        
          # Write-Debug -Message 'Entering New-scVirtualMachineExJob'

            $PhysicalComputer = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::new()

            $vmmServer = $Configuration[0].ServerConnection

       #endregion Initialize

       #region Filter parameters for the Unified Loop (“Start-scJobEx”)

            $FilterProcess  = {

                $ComputerName = $psItem.ComputerName

                -Not ( Get-scvmHost -vmmServer $vmmServer |
                    Where-Object -FilterScript {
                        $psItem.ComputerName -eq $ComputerName
                    }
                )
            }

            $FilterProgress = {

              # Cannot use “PowerOff” here because we will not advance thru the
              # loop until VMs are powered on—and they won't until we advance

                $ComputerName = $psItem.ComputerName
                
                $Status       = @(

                    'Adding'
                    'Pending'
                    'Updating'
                    'Restarting'
                    'NeedsAttention'
                  # 'Responding'  # Hosts turn into this state after deployment is done but while they're still updating
                  # 'UnderCreation'
                  # 'PowerOff'
                )

                $Task = @( 'Running' )

                Get-scvmHost -vmmServer $vmmServer |
                    Where-Object -FilterScript {
                    
                        $psItem.ComputerName  -eq $ComputerName -and

                        (
                            $psItem.OverallState -in $Status
                        ) -or
                        (
                            $psItem.OverallState -eq 'Responding'   -and
                            $psItem.MostRecentTask                  -and
                            $psItem.MostRecentTask.Status -in $Task
                        )
                    }
            }

            $FilterComplete = {

                $ComputerName = $psItem.ComputerName
                $Status       = @( 'OK', 'Responding' )  # @( 'Responding' )
                $Task         = @( 'Completed', 'Succeed', 'SucceedWithInfo' )

                $vmHost = Get-scvmHost -vmmServer $vmmServer |
                    Where-Object -FilterScript {
                        $psItem.ComputerName  -eq $ComputerName -and
                      # $psItem.OverallState  -in $Status       -and
                        $psItem.MostRecentTask                  -and
                        $psItem.MostRecentTask.Status -in $Task
                    }

                If
                (
                    $vmHost
                )
                {
                    $vmHost = Read-scvmHost -vmHost $vmHost
                }

                Get-scvmHost -vmmServer $vmmServer |
                     Where-Object -FilterScript {

                        $psItem.ComputerName  -eq $ComputerName -and
                        $psItem.OverallState  -in $Status       -and
                        $psItem.MostRecentTask                  -and
                        $psItem.MostRecentTask.Status -in $Task
                    }
            }

       #endregion Filter parameters for the Unified Loop (“Start-scJobEx”)

       #region Script Block parameter (main routine) for the Unified Loop (“Start-scJobEx”)

            $ScriptBlock = {

             <# $PhysicalComputerCurrent = New-scvmHost -vmHostConfig $Start -RunAsynchronously

                While
                (
                    $PhysicalComputerCurrent.OverallState -ne 'Adding'
                )
                {
                    Start-Sleep -Seconds 1

                    $Message = "Waiting for `“$( $Start.ComputerName )`” to start provisioning"

                    Write-Debug -Message $Message
                }

                $PhysicalComputer.Add( $PhysicalComputerCurrent )  #>

                $PhysicalComputer.Add( ( New-scvmHost -vmHostConfig $Start -RunAsynchronously ) )
            }

       #endregion Script Block parameter (main routine) for the Unified Loop (“Start-scJobEx”)

       #region Unified Loop (“Start-scJobEx”)

          # Write-Debug -Message $Configuration.gettype().fullname

            $JobParam = @{
            
                Object         = $Configuration
                TaskName       = 'Deploying physical computer'
                ScriptBlock    = $ScriptBlock
                FilterProcess  = $FilterProcess
                FilterProgress = $FilterProgress
                FilterComplete = $FilterComplete
              # FilterParallel = { $False }
                ThrottleLimit  = $ThrottleLimit
                Retry          = 1
            }
         <# [System.Collections.Generic.List[
                Microsoft.SystemCenter.VirtualMachineManager.Host
            ]]$PhysicalComputer = Start-scJobEx @JobParam  #>

            [System.Collections.Generic.List[
              # Microsoft.SystemCenter.VirtualMachineManager.Host
                Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig
            ]]$Configuration = Start-scJobEx @JobParam

         <# “Start-scJobEx” will output the same object type as input (“Object” 
            parameter). Hence we need to convert it to the desired target
            object separately, which is in this case “Host”  #>

            $PhysicalComputer = [System.Collections.Generic.List[
                Microsoft.SystemCenter.VirtualMachineManager.Host
            ]]::new()

            $Configuration | ForEach-Object -Process {

                $HostParam = @{
                
                    ComputerName = $psItem.ComputerName
                    vmmServer    = $vmmServer
                }

                $PhysicalComputer.Add( ( Get-scvmHost @HostParam ) )
            }

         <# $PhysicalComputer = [System.Collections.Generic.List[
                Microsoft.SystemCenter.VirtualMachineManager.Host
            ]]( Start-scJobEx @JobParam )  #>
            
          # $PhysicalComputer = Start-scJobEx @JobParam

         <# Write-Debug -Message 'Start-scJobEx returned'
            Write-Debug -Message $PhysicalComputer.GetType().FullName
            
            Write-Debug -Message 'First item'
            Write-Debug -Message $PhysicalComputer[0].GetType().FullName
            Write-Debug -Message $PhysicalComputer[0]

            Write-Debug -Message 'Second item'
            Write-Debug -Message $PhysicalComputer[1].GetType().FullName
            Write-Debug -Message $PhysicalComputer[1]  #>

          # Write-Debug -Message 'Expected'
          # Write-Debug -Message $Configuration.gettype().fullname

          # $VirtualMachineProperty2 = [System.Collections.Generic.List[System.Collections.Generic.Dictionary[System.String, System.String]]]$VirtualMachineProperty1

          # $Configuration = $VirtualMachineProperty2

       #endregion Unified Loop (“Start-scJobEx”)
            
        Write-Debug -Message 'Exiting  New-scVirtualMachineExJob'

        Return $PhysicalComputer

   #endregion Code
}