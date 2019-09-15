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

            $PhysicalComputer = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

            $vmmServer = $Configuration[0].ServerConnection

       #endregion Initialize

       #region Filter parameters for the Unified Loop (“Start-scJobEx”)

            $FilterProcess  = {

                -Not ( Get-scvmHost -ComputerName $psItem.Name -vmmServer $vmmServer )
            }

            $FilterProgress = {

              # Cannot use “PowerOff” here because we will not advance thru the
              # loop until VMs are powered on—and they won't until we advance

                $Status = @( 'UnderCreation' )  #, 'PowerOff' ) ???
                Get-scvmHost -ComputerName $psItem.Name -vmmServer $vmmServer |
                    Where-Object -FilterScript { $psItem.ComputerState -in $Status }
            }

            $FilterComplete = {

                $Status = @( 'Responding' )
                Get-scvmHost -ComputerName $psItem.Name -vmmServer $vmmServer |
                    Where-Object -FilterScript { $psItem.ComputerState -in $Status }
            }

       #endregion Filter parameters for the Unified Loop (“Start-scJobEx”)

       #region Script Block parameter (main routine) for the Unified Loop (“Start-scJobEx”)

            $ScriptBlock = {

                $PhysicalComputer.Add(
                    $( New-scvmHost -vmHostConfig $Start -RunAsynchronously )
                )
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
              # FilterParallel = $FilterParallel
                ThrottleLimit  = $ThrottleLimit
                Retry          = 1
            }
            $Configuration = Start-scJobEx @JobParam
            
          # Write-Debug -Message 'Start-scJobEx returned'
          # Write-Debug -Message $VirtualMachineProperty1.gettype().fullname
            
          # Write-Debug -Message 'Expected'
          # Write-Debug -Message $Configuration.gettype().fullname

          # $VirtualMachineProperty2 = [System.Collections.Generic.List[System.Collections.Generic.Dictionary[System.String, System.String]]]$VirtualMachineProperty1

          # $Configuration = $VirtualMachineProperty2

       #endregion Unified Loop (“Start-scJobEx”)
            
        Write-Debug -Message 'Exiting  New-scVirtualMachineExJob'

        Return $PhysicalComputer

   #endregion Code
}