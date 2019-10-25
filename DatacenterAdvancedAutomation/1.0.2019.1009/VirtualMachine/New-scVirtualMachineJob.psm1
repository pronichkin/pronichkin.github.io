Set-StrictMode -Version 'Latest'

Function
New-scVirtualMachineJob
{
   #region Data

        [cmdletBinding()]

        Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
            $vmmServer
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $DomainAddress
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[System.Collections.Generic.Dictionary[System.String, System.String]]]
            $VirtualMachineProperty
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

            $VirtualMachine = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

       #endregion Initialize

      <#region Prepare variables

          # $VirtualMachineAll = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

         <# If
            (
                Get-scvmTemplate -Name "Temporary"
            )
            {
                $Message = @(
                    "There's existing Virtual Machine Template named `“Temporary.`”"
                    "This is likely a leftover from a previous script run, ended unexpectedly."
                    "The script will now fail."
                    "You need to investigate the previous failures, then manually clean up the template."
                )

                $Message | ForEach-Object -Process { Write-Warning -Message $psItem }
            }
       
            $VirtualMachine             = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()
          # $VirtualMachineProvisioned  = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

          # Transform the array of hashtables to dictionary of dictionaries
          # so that we can more efficiently loop through it later

            $VirtualMachineName         = [System.Collections.Generic.Dictionary[System.String, System.Collections.Generic.Dictionary[System.String, System.String]]]::new()        

            $VirtualMachineProperty | ForEach-Object -Process {

                $VirtualMachinePropertyCurent = [System.Collections.Generic.Dictionary[System.String, System.String]]::new()

                $psItem.GetEnumerator() | ForEach-Object -Process {

                    $VirtualMachinePropertyCurent.Add( $psItem.Key, $psItem.Value )
                }



                $VirtualMachineName.Add( $Name, $VirtualMachinePropertyCurent )
            }

          # Virtual machines currently provisioning

            $VirtualMachineProvisioning = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

            Get-scVirtualMachine -vmmServer $vmmServer | Where-Object -FilterScript { $psItem.Status -eq 'UnderCreation' } | ForEach-Object -Process {

                $VirtualMachineProvisioning.Add( $psItem )
            }

          # Virtual machines to provision
        
            $VirtualMachineProvision    = [System.Collections.Generic.Dictionary[System.String, System.Collections.Generic.Dictionary[System.String, System.String]]]::new()

            $VirtualMachineName.GetEnumerator() | ForEach-Object -Process {

                $VirtualMachineParam = @{

                    Name      = $psItem.Key
                    vmmServer = $vmmServer
                }
           
                If
                (
                    -Not ( Get-scVirtualMachine @VirtualMachineParam )
                )
                {
                    $VirtualMachineProvision.Add( $psItem.Key, $psItem.Value )
                }
            }

       #endregion Prepare variables  #>

       #region Filter parameters for the Unified Loop (“Start-scJobEx”)

            $FilterProcess  = {

                $Name = Get-scVirtualMachineName -Property $psItem -DomainAddress $DomainAddress
                -Not ( Get-scVirtualMachine -Name $Name -vmmServer $vmmServer )
            }

            $FilterProgress = {

              # Cannot use “PowerOff” here because we will not advance thru the
              # loop until VMs are powered on—and they won't until we advance

                $Status = @( 'UnderCreation' )  #, 'PowerOff' )
                $Name = Get-scVirtualMachineName -Property $psItem -DomainAddress $DomainAddress
                Get-scVirtualMachine -Name $Name -vmmServer $vmmServer |
                    Where-Object -FilterScript { $psItem.Status -in $Status }
            }

            $FilterComplete = {

                $Status = @( 'Running', 'Saved' )
                $Name = Get-scVirtualMachineName -Property $psItem -DomainAddress $DomainAddress
                Get-scVirtualMachine -Name $Name -vmmServer $vmmServer |
                    Where-Object -FilterScript { $psItem.Status -in $Status }
            }

       #endregion Filter parameters for the Unified Loop (“Start-scJobEx”)

       #region Script Block parameter (main routine) for the Unified Loop (“Start-scJobEx”)

            $ScriptBlock = {

               #region Start provisioing one virtual machine

                   #region Mandatory parameters

                        Set-DCAADescription -Define $Start

                      # Basic VM specialization properties

                        $CloudParam = @{

                            Name      = $Start.CloudName
                            vmmServer = $vmmServer
                        }
                        $Cloud = Get-scCloud @CloudParam

                        $Role = Get-scUserRole -vmmServer $vmmServer |
                            Where-Object -FilterScript {
                                $psItem.Name -like "$($Start.Owner)*"
                            }

                        $TemplateParam = @{
        
                            Name      = $Start.TemplateName
                            vmmServer = $vmmServer
                        }
                        $Template = Get-scvmTemplate @TemplateParam

                        $VirtualMachineParam = @{

                            Name        = $Start.Name
                            Description = $Start.Description
                            Template    = $Template
                            Cloud       = $Cloud
                            Owner       = $Start.Owner
                            Role        = $Role
                            StartAction = $Start.StartAction
                            StopAction  = $Start.StopAction
                        }

                   #endregion Mandatory parameters

                   #region Optional parameters

                        If
                        (
                            $Start[ 'DomainAddress' ]
                        )
                        {
                            $VirtualMachineParam.Add(
                                'DomainAddress',
                                $Start.DomainAddress
                            )
                        }
                        ElseIf
                        (
                            $DomainAddress
                        )
                        {
                            $VirtualMachineParam.Add(
                                'DomainAddress',
                                $DomainAddress
                            )
                        }

                        If
                        (
                            $Start[ 'NetworkName' ]
                        )
                        {
                            $NetworkParam = @{

                                Name      = $Start.NetworkName
                                vmmServer = $vmmServer
                            }
                            $Network = Get-scvmNetwork @NetworkParam

                            $VirtualMachineParam.Add( 'Network', $Network )
                        }

                        If
                        (
                            $Start[ "PortClassificationName" ]
                        )
                        {
                            $PortClassificationParam = @{

                                Name      = $Start.PortClassificationName
                                vmmServer = $vmmServer
                            }
                            $PortClassification =
                                Get-scPortClassification @PortClassificationParam

                            $VirtualMachineParam.Add( 
                                'PortClassification',
                                $PortClassification
                            )
                        }

                        If
                        (
                            $Start[ 'GroupName' ]
                        )
                        {
                            $VirtualMachineParam.Add( 
                                'GroupName',
                                $Start.GroupName
                            )
                        }

                        If
                        (
                            $Start[ 'OptionalDisk' ]
                        )
                        {
                            $VirtualMachineParam.Add(
                                'OptionalDisk',
                                $Start.OptionalDisk.Split( [System.String]::Empty )
                            )
                        }

                        If
                        (
                            $Start[ 'AvailabilitySetName' ]
                        )
                        {
                            $VirtualMachineParam.Add(
                                'AvailabilitySetName',
                                $Start.AvailabilitySetName
                            )
                        }

                        If
                        (
                            $Start[ 'IPv4Address' ]
                        )
                        {
                            $VirtualMachineParam.Add(
                                'IPv4Address',
                                $Start.IPv4Address
                            )
                        }

                        If
                        (
                            $Start[ 'ShieldingDataName' ]
                        )
                        {
                            $ShieldingDataParam = @{

                                Name      = $Start.ShieldingDataName
                                vmmServer = $vmmServer
                            }
                            $ShieldingData = Get-scvmShieldingData @ShieldingDataParam

                            $VirtualMachineParam.Add(
                                'ShieldingData',
                                $ShieldingData
                            )
                        }

                   #endregion Optional parameters

                   #region New-scVirtualMachineEx

                        $VirtualMachine.Add(
                            $( New-scVirtualMachineEx @VirtualMachineParam )
                        )

                   #endregion New-scVirtualMachineEx

               #endregion Start provisioing one virtual machine

               #region Catch up on VMs that finished provisioning

                    $Complete = $False

                    While
                    (
                        (
                          # This is the last VM to create, so wait here. 
                          # Otherwise we'll never get back to this loop. Note
                          # that the known limitation of current implementation
                          # is that the progress bar will stop updating (as it's
                          # maintained by “Start-scJobEx”) once we reach the
                          # last bunch of VMs deployed concurrently (defined as
                          # “Throttle Limit”.) This does not affect actual job
                          # completion.

                            $cPending.Count -eq 1 -and (

                                $VirtualMachine | Where-Object -FilterScript {

                                  # This is different from the “Progress Filter”
                                  # because we also need to include the machines
                                  # which are powered off—i.e. provisioned, but
                                  # not configured. (We cannot include them into
                                  # Progress Filter because otherwise they will
                                  # never be started.)

                                    $psItem.Status -in @(
                                        'UnderCreation',
                                        'PowerOff'
                                    )
                                }
                            )
                                                        
                         <# (
                                'UnderCreation' -in $VirtualMachine.Status -or
                                'PowerOff'      -in $VirtualMachine.Status
                            )  #>
                        ) -Or
                        (
                          # Simply run the completion block once

                           -Not $Complete
                        )
                    )
                    {
                        $Complete = $False

                        $VirtualMachine | Where-Object -FilterScript {
                        
                          # $psItem.Status -eq 'PowerOff'

                            $Job = $psItem.MostRecentTask[ -1 ].Steps |
                                Where-Object -FilterScript {
                                    $psItem.Name -eq 'Create virtual machine in cloud'
                                }

                            $Job -and $Job.Status -eq 'Completed'

                        } | ForEach-Object -Process {

                            $VirtualMachineParam = @{

                                VirtualMachine             = $psItem
                                Admin                      = $True
                                AutomaticRecovery          = $False
                                SimultaneousMultithreading = $True
                            }
                            [System.Void]( Set-scVirtualMachineEx @VirtualMachineParam )

                            $Complete = $True
                        }                        

                        If
                        (
                            $cPending.Count -eq 1
                        )
                        {
                          # This is the last machine, so we need to ensure we
                          # still pass thru the completion routine at least once

                            $Message = 'Waiting for the last batch of virtual machine(s) to finish provisionining'
                            Write-Debug -Message $Message

                            Start-Sleep -Seconds 1

                          # $Complete = $False
                        }
                        Else
                        {
                            $Complete = $True
                        }
                    }

               #endregion Catch up on VMs that finished provisioning
            }

       #endregion Script Block parameter (main routine) for the Unified Loop (“Start-scJobEx”)

       #region Unified Loop (“Start-scJobEx”)

          # Write-Debug -Message $VirtualMachineProperty.gettype().fullname

            $JobParam = @{
            
                Object         = $VirtualMachineProperty
                TaskName       = 'Deploying Virtual Machine'
                ScriptBlock    = $ScriptBlock
                FilterProcess  = $FilterProcess
                FilterProgress = $FilterProgress
                FilterComplete = $FilterComplete
              # FilterParallel = $FilterParallel
                ThrottleLimit  = $ThrottleLimit
                Retry          = 1
            }
            $VirtualMachineProperty = Start-scJobEx @JobParam
            
          # Write-Debug -Message 'Start-scJobEx returned'
          # Write-Debug -Message $VirtualMachineProperty1.gettype().fullname
            
          # Write-Debug -Message 'Expected'
          # Write-Debug -Message $VirtualMachineProperty.gettype().fullname

          # $VirtualMachineProperty2 = [System.Collections.Generic.List[System.Collections.Generic.Dictionary[System.String, System.String]]]$VirtualMachineProperty1

          # $VirtualMachineProperty = $VirtualMachineProperty2

       #endregion Unified Loop (“Start-scJobEx”)
            
       #region Re-obtain VM objects instead of custom hashtable

          # We need to rebuild the collection to include both newly deployed VMs
          # and existing ones

            $VirtualMachine = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

            $VirtualMachineProperty | ForEach-Object -Process {

                $Name = Get-scVirtualMachineName -Property $psItem -DomainAddress $DomainAddress

                $VirtualMachine.Add(
                    (
                        Get-scVirtualMachine -Name $Name -vmmServer $vmmServer |
                            Where-Object -FilterScript {
                                $psItem.ReplicationMode -ne 'Recovery'
                            } # |

                          # The below filter is not strictly necessary under
                          # normal circumstances. However, it might be helful
                          # if we failed to clean up the “phantom” virtual
                          # machines whcih are sometime emitted by VMM

                          # Where-Object -FilterScript { $psItem.Cloud }
                    )
                )
            }

       #endregion Re-obtain VM objects instead of custom hashtable

         <# Custom loop to deprecate

            $Current = 0
            $Total   = $VirtualMachineProvision.Count

            $TaskName = 'Provisioning Virtual Machines'
            Write-Verbose -Message $TaskName

            While
            (
                (
                    $VirtualMachineProvision -and
                    $VirtualMachineProvisioning.Count -lt $ThrottleLimit
                ) -or
                (
                    $VirtualMachineProvisioning
                )
            )
            {


               #region Re-populate collections

                  # Virtual machines currently provisioning

                    $VirtualMachineProvisioning = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

                    Get-scVirtualMachine -vmmServer $vmmServer | Where-Object -FilterScript { $psItem.Status -eq 'UnderCreation' } | ForEach-Object -Process {

                        $VirtualMachineProvisioning.Add( $psItem )
                    }

                  # Virtual machines to provision
        
                    $VirtualMachineProvision    = [System.Collections.Generic.Dictionary[System.String, System.Collections.Generic.Dictionary[System.String, System.String]]]::new()

                    $VirtualMachineName.GetEnumerator() | ForEach-Object -Process {

                        $VirtualMachineParam = @{

                            Name      = $psItem.Key
                            vmmServer = $vmmServer
                        }
           
                        If
                        (
                            -Not ( Get-scVirtualMachine @VirtualMachineParam )
                        )
                        {
                            $VirtualMachineProvision.Add( $psItem.Key, $psItem.Value )
                        }
                    }

               #endregion Re-populate collections
            }  #>            

     <# Old pieces to move into the new main loop

        $VirtualMachineProperty | ForEach-Object -Process {

            $VirtualMachineParamCurrent = $psItem







           #region Check for existing virtual machine

                If
                (
                    $VirtualMachineParamCurrent[ "DomainAddress" ]
                )
                {
                    $Name = $VirtualMachineParamCurrent.Name + "." + $VirtualMachineParamCurrent.DomainAddress
                }
                ElseIf
                (
                    $DomainAddress
                )
                {
                    $Name = $VirtualMachineParamCurrent.Name + "." + $DomainAddress
                }
                Else
                {
                    $Name = $VirtualMachineParamCurrent.Name
                }

                



           #endregion Check for existing virtual machine

           #region Provision machine

                If
                (
                    -Not $VirtualMachine
                )
                {

                 <# Dispose the Template, if it was Temporary

                    If
                    (
                        $Template.Name -eq "Temporary"
                    )
                    {
                        $Template = Remove-scvmTemplate -vmTemplate $Template
                    }

                  # Re-obtain Virtual Machine object in case there were
                  # duplicates emitted

                    $VirtualMachine = Get-scVirtualMachine -Name $Name
                }

           #endregion Provision machine

           #region Live virtual machine configuration



   

              # Set Owner and Description

                If
                (
                    $VirtualMachineParamCurrent[ "Owner" ]
                )
                {
                }

           #endregion Live virtual machine configuration

            $VirtualMachineAll += $VirtualMachine

            If
            (
                Test-Path -Path 'Variable:\Template'
            )
            {
                Remove-Variable -Name 'Template'
            }
        }    #>        

        Write-Debug -Message 'Exiting  New-scVirtualMachineExJob'

        Return $VirtualMachine

   #endregion Code
}