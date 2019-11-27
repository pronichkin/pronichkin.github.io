<#
    Configure Virtual Machine properties which are not available during VM 
    provisioning with VMM.

    Not all properties are supported by VMM as of today, hence we have to set 
    them directly on Hyper-V host using Hyper-V native cmdlets. This requires
    administrative permissions on the host—even if all you want to do is check
    the current value. Hence, these operations are not performed by default,
    unless “-Admin” switch is provided.
#>

Set-StrictMode -Version 'Latest'

Function
Set-scVirtualMachineEx
{
        [cmdletBinding()]

        Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.VM]
            $VirtualMachine
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.SwitchParameter]
            $Admin
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Boolean]
            $SimultaneousMultithreading
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Boolean]
            $AutomaticRecovery
        )

    Process
    {
        $Message = "Entering Set-scVirtualMachineEx for $( $VirtualMachine.Name )"
      # Write-Debug -Message $Message

        If
        (
            $VirtualMachine.MostRecentTask[ -1 ].ErrorInfo.DetailedCode
        )
        {
            $Message = 'Most recent task did not complete successfully. Skipping'
            Write-Verbose -Message $Message
        }
        Else
        {
           #region Display some nice statistics

                $JobParent = $VirtualMachine.MostRecentTask[ -1 ].Steps |
                    Where-Object -FilterScript {
                        $psItem.Name -eq 'Create virtual machine in cloud'
                    }

                If
                (
                    $JobParent
                )
                {
                    $JobCreate    = $JobParent.Children | Where-Object -FilterScript { $psItem.Name -eq 'Create virtual machine' }
                    $JobCopy      = $JobCreate.Children | Where-Object -FilterScript { $psItem.Name -eq 'Deploy file (using Fast File Copy)' }
                    $JobCustomize = $JobCreate.Children | Where-Object -FilterScript { $psItem.Name -like 'Customize*virtual machine' }

                  # Decimal percentage (e.g. “1.75 minutes”) looks strange
                  # $Overall   = [System.Math]::Round(    $JobCreate.EndTime.Subtract(    $JobCreate.StartTime ).TotalMinutes, 2 )
                  # $Copy      = [System.Math]::Round(      $JobCopy.EndTime.Subtract(      $JobCopy.StartTime ).TotalMinutes, 2 )
                  # $Customize = [System.Math]::Round( $JobCustomize.EndTime.Subtract( $JobCustomize.StartTime ).TotalMinutes, 2 )

                    $OverallSpan   =    $JobCreate.EndTime.Subtract(    $JobCreate.StartTime )
                    $CopySpan      =      $JobCopy.EndTime.Subtract(      $JobCopy.StartTime )
                    $CustomizeSpan = $JobCustomize.EndTime.Subtract( $JobCustomize.StartTime )                  

                    $Overall       =   "$($OverallSpan.Minutes):$(  $OverallSpan.Seconds.ToString().PadLeft( 2, '0' ) )"
                    $Copy          =      "$($CopySpan.Minutes):$(     $CopySpan.Seconds.ToString().PadLeft( 2, '0' ) )"
                    $Customize     = "$($CustomizeSpan.Minutes):$($CustomizeSpan.Seconds.ToString().PadLeft( 2, '0' ) )"
                                        
                    $Message = "$( ( Get-Date -DisplayHint Time ).DateTime )  $( $VirtualMachine.Name )  took $Overall minutes, including $Copy to copy and $Customize to customize"                    
                }
                Else
                {
                    $Message = 'The VM is too old to track creation job'
                }

                Write-Verbose -Message $Message

           #endregion Display some nice statistics

           #region Reestablish connectivity to VMM

                $VirtualMachineParam = @{

                    Name = $VirtualMachine.Name
                }

             # To obtain the host name (among other Fabric-level properties),
             # VMM connection *must not* be opened as “For On Behalf Of”

                If
                (
                    $Admin -and
                    $VirtualMachine.ServerConnection.ForOnBehalfOf
                )
                {
                    $vmmServerParam = @{
                
                        ComputerName =
                            $VirtualMachine.ServerConnection.FullyQualifiedDomainName
                    }
                    $vmmServerCurrent = Get-scvmmServer @vmmServerParam

                    $VirtualMachineParam.Add(
                        'vmmServer', $vmmServerCurrent
                    )
                }
                Else
                {
                    $VirtualMachineParam.Add(
                        'vmmServer', $VirtualMachine.ServerConnection
                    )
                }

                $VirtualMachineCurrent = Get-scVirtualMachine @VirtualMachineParam

           #endregion Reestablish connectivity to VMM
            
           #region Workaround for phantom VMs in VMM

                If
                (
                    $VirtualMachineCurrent -is [System.Object[]]
                )
                {
                    $Message = 'Duplicate virtual machine detected. Cleaning up'
                    Write-Warning -Message $Message

                    [System.Void]( $VirtualMachineCurrent |
                      # Where-Object -FilterScript { -Not $psItem.Cloud } |
                        Where-Object -FilterScript { $psItem -ne $VirtualMachine } |
                            Remove-scVirtualMachine -Force
                    )

                    $VirtualMachine = Get-scVirtualMachine @VirtualMachineParam
                }
                Else
                {
                    $VirtualMachine = $VirtualMachineCurrent
                }

           #endregion Workaround for phantom VMs in VMM

           #region Offline configuration

                If
                (
                    $Admin
                )
                {
                  # Set additional processor options on VM. Currently VMM does
                  # not support these settings. They have to be set while the
                  # VM is still offline

                    If
                    (
                        $SimultaneousMultithreading
                    )
                    {
                        $HwThreadCountPerCore = @( 0, 2 )
                    }
                    Else
                    {
                        $HwThreadCountPerCore = @( 1 )
                    }

                    $Session = New-cimSessionEx -Name $VirtualMachine.HostName

                    $vmParam = @{

                      # Name       = $VirtualMachine.Name
                        id         = $VirtualMachine.vmId
                        CimSession = $Session
                    }
                    $vm = Hyper-V\Get-VM @vmParam

                    $Processor = Hyper-V\Get-vmProcessor -VM $vm

                    If
                    (
                        $Processor.HwThreadCountPerCore -in $HwThreadCountPerCore
                    )
                    {
                        $Message = 'Simultaneous Multithreading (SMT/HT) already configured as expected'
                        Write-Debug -Message $Message
                    }
                    ElseIf
                    (
                        $VirtualMachine.Status -ne 'PowerOff'
                    )
                    {
                        $Message = 'Simultaneous Multithreading (SMT/HT) is not configured as expected, but machine is running. Skipping'
                        Write-Warning -Message $Message
                    }
                    Else
                    {
                        $ProcessorParam = @{

                          # vm                           = $vm
                            vmProcessor                  = $Processor
                            HwThreadCountPerCore         = $HwThreadCountPerCore[ -1 ]
                            EnableHostResourceProtection = $True
                          # PassThru                     = $True
                        }
                        Hyper-V\Set-vmProcessor @ProcessorParam
                    }
                }

           #endregion Offline configuration

           #region Start

              # When deployed to Cloud, a VM is not started even if if set to
              # “Always Auto Turn On VM.” The rationale is that we want to avoid
              # charging cloud customers unless they explicitly start a VM.

                If
                (
                    $VirtualMachine.StartAction -eq 'AlwaysAutoTurnOnVM' -and
                    $VirtualMachine.Status -eq 'PowerOff'
                )
                {
                 # Write-Verbose -Message "Starting VM $Name"

                   [System.Void]( Start-scVirtualMachine -vm $VirtualMachine )
                 # [System.Void](  Read-scVirtualMachine -vm $VirtualMachine )
                }

           #endregion Start

           #region Online configuration

              # “Embedded Failure Action” is called “Automatic Recovery” in the
              # UI. By default, if VM stops heartbeating, this mechanism forcibly
              # restarts the VM. It happens too soon to complete memory dump in
              # case of a Stop error (“Blue Screen” or “Bug Check”.) Hence we
              # disable this feature—so that VM finishes collecting the dump and
              # then can restart on its own, if configured to do so. (This is the
              # default setting.) Note that if the Guest OS is not configured to
              # restart in case of a Stop error, it will stay in this state until
              # restarted manually.

                If
                (
                    $Admin -and
                    $VirtualMachine.IsHighlyAvailable
                )
                {
                    $Cluster = Get-Cluster -Name $VirtualMachine.HostName

                    $ResourceParam = @{

                        InputObject = $Cluster
                        vmId        = $VirtualMachine.vmId
                    }
                    $ClusterResource = Get-ClusterResource @ResourceParam

                    If
                    (
                        $AutomaticRecovery
                    )
                    {
                        $EmbeddedFailureAction = 2  # Default
                    }
                    Else
                    {
                        $EmbeddedFailureAction = 1
                    }

                    $ClusterResource.EmbeddedFailureAction = $EmbeddedFailureAction
                }

              # Enable the “Guest Service.” Apparently it is the only Integration
              # Service which is not enabled by default.

                If
                (
                    -Not $VirtualMachine.GuestServiceInterfaceEnabled
                )
                {
                    $VirtualMachineParam = @{
                    
                        VM                           = $VirtualMachine
                        EnableGuestServicesInterface = $True
                    }
                    $VirtualMachine = Set-scVirtualMachine @VirtualMachineParam
                }

           #endregion Online configuration 

           #region Clean up temporary template
                    
                $TemplateParam = @{

                    Name      = $VirtualMachine.CreationSource
                    vmmServer = $VirtualMachine.ServerConnection
                }
                $Template = Get-scvmTemplate @TemplateParam                

                If
                (
                    $Template
                )
                {
                    [System.Void]( Remove-scvmTemplate -vmTemplate $Template )
                }

           #endregion Clean up temporary template

           #region Wait for VM to start heartbeating

                While
                (
                    $VirtualMachine.vmAddition -eq 'Not Detected'
                )
                {
                    Start-Sleep -Seconds 3

                    $VirtualMachine = Read-scVirtualMachine -VM $VirtualMachine
                }

           #endregion Wait for VM to start heartbeating

           #region Check for Computer Name field

                If
                (
                    $VirtualMachine.SecuritySummary -ne 'Shielded' -and
                    $VirtualMachine.ComputerName -ne $VirtualMachine.Name
                )
                {
                    $Message = 'Computer name field does no match the expected value. This probably indicates that VM failed to join domain'
                    Write-Warning -Message $Message
                }
           
           #endregion Check for Computer Name field

           #region Cleanup temporary VMM connection

                If
                (
                    Test-Path -Path 'Variable:\vmmServerCurrent'
                )
                {
                    $vmmServerCurrent.Disconnect()

                    Remove-Variable -Name 'vmmServerCurrent'
                }

           #endregion Cleanup temporary VMM connection
        }

        $Message = "Exiting  Set-scVirtualMachineEx for $( $VirtualMachine.Name )"
      # Write-Debug -Message $Message

        Return $VirtualMachine
    }
}