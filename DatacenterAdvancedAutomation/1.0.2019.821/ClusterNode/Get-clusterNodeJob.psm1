Function
Get-clusterNodeJob
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.ArrayList]
        $Node
    )

    Begin
    {
      # At this point “Node Cluster” collection might store objects
      # of different types—already deployed (pre-existing)
      # and not yet deployed

        $Node | ForEach-Object -Process {

                    Switch
                    (
                        $psItem.GetType().FullName
                    )
                    {
                        {
                            $psItem -like 'System.Collections.Generic.Dictionary*'
                        }
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\ConfigurationVirtual' )
                            )
                            {
                                $ConfigurationVirtual  = [System.Collections.Generic.List[System.Collections.Generic.Dictionary[System.String, System.String]]]::New()
                            }

                            $ConfigurationVirtual.Add( $psItem )
                        }

                        'Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig'
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\ConfigurationPhysical' )
                            )
                            {
                                $ConfigurationPhysical = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerConfig]]::New()
                            }

                            $ConfigurationPhysical.Add( $psItem )
                        }

                        'Microsoft.SystemCenter.VirtualMachineManager.Host'
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                            )
                            {
                                $NodeCurrent = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::New()
                            }

                            $NodeCurrent.Add( $psItem )
                        }

                        'Microsoft.SystemCenter.VirtualMachineManager.VM'
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                            )
                            {
                                $NodeCurrent = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::New()
                            }

                            $NodeCurrent.Add( $psItem )
                        }

                        'System.String'
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                            )
                            {
                                $NodeCurrent = [System.Collections.Generic.List[System.String]]::New()
                            }

                            $NodeCurrent.Add( $psItem )
                        }

                        Default
                        {
                            $Message = "Unexpected Node object type: `“$( $psItem.GetType().FullName )`”"
                            Write-Warning -Message $Message
                        }
                    }
                }
    }

    Process
    {
        If
        (
             $ConfigurationVirtual
        )
        {
            If
            (
                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
            )
            {
                $NodeCurrent = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::New()
            }

            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]$vmmServerForOnBehalfOf =
                Get-scvmmServerEx -vmmServer $vmmServer -ForOnBehalfOf

            $VirtualMachineParam = @{

                vmmServer              = $vmmServerForOnBehalfOf
                VirtualMachineProperty = $ConfigurationVirtual
            }
            $NodeCurrent.AddRange( $( New-scVirtualMachineExJob @VirtualMachineParam ) )

            $vmmServerForOnBehalfOf.Disconnect()

            Remove-Variable -Name 'vmmServerForOnBehalfOf'
        }
        ElseIf
        (
            $ConfigurationPhysical
        )
        {
          # The following steps are specific to Scale Unit Type

            Switch
            (
                $ScaleUnitType
            ) 
            { 
                {
                    $psItem -in @(

                        'Management'
                        'Compute'
                        'Network'
                    )
                }
                {
                          # Restart-WinRM -vmmServer $vmmServer
                            
                          # Write-Verbose -Message "Starting Bare-Metal Provisioning. This should take a while"

                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                            )
                            {
                                $NodeCurrent = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::New()
                            }

                            $NodeCurrent.AddRange( $( New-scvmHostExJob -Configuration $ConfigurationPhysical ) )                            

                          # Write-Verbose -Message "Bare-Metal Provisioning completed!"

                          # Restart-WinRM -vmmServer $vmmServer

                         <# The following does not work if we don't have CDN 
                            because friendly names won't come back in PCC.
                         
                          # The mapping between the desired pNIC name and MAC address was established during
                          # creation of Physical Computer Configuration. Now we need to use it to rename
                          # the actual pNIC before Physical Computer Configuration is disposed or replaced.

                            $Message = "Obtaining final Physical computer network adapter names from Physical Computer Configuration `“$Configuration`”"
                            Write-Verbose -Message $Message

                            $PhysicalComputerNetworkAdapterConfiguration = $Configuration.PhysicalComputerNetworkAdapterConfigs | Where-Object -FilterScript { $psItem.IsPhysicalNetworkAdapter }

                            $PhysicalComputerNetworkAdapterConfiguration | ForEach-Object -Process {

                                $PhysicalAddressString = $psItem.macAddress.ToUpper().Replace( ":", "-" )
                                $PhysicalAddress = [System.Net.NetworkInformation.PhysicalAddress]::Parse( $PhysicalAddressString )

                                $NetworkAdapter = Get-netAdapterEx -cimSession $Node.Name -Physical -PhysicalAddress $PhysicalAddress

                                $Message = "Renaming physical network adapter `“$( $NetworkAdapter.Name )`” to `“$( $psItem.ConsistentDeviceName )`”"
                                Write-Verbose -Message $Message

                                Rename-netAdapter -InputObject $NetworkAdapter -NewName $psItem.ConsistentDeviceName -cimSession $Node.Name
                            }

                          # Disable disconnected NICs

                            $NetAdapterDisconnect = Get-netAdapterEx -cimSession $Node.Name -Physical | Where-Object -FilterScript { $psItem.Status -eq "Disconnected" }
                            
                            If
                            (
                                $NetAdapterDisconnect
                            )
                            {
                                $Message = "Disabling $( @( $NetAdapterDisconnect ).Count ) disconnected physical network adapters"
                                Write-Verbose -Message $Message

                                Disable-netAdapter -InputObject $NetAdapterDisconnect -cimSession $Node.Name -Confirm:$False
                            }  #>
                }

                 'Storage'
                {

                          # We cannot add an individual (stand-alone) File Server by itself.
                          # (Only create a cluster altogether.
                          # This should be handled by Get-ClusterEx).

                          # Thus, here we return prepared Physical Computer Template
                          # which will be consumed later by Get-ClusterEx
                          # to deploy Scale-Out File Server.

                    $NodeCurrent = $ConfigurationPhysical
                }
            }
        }
        Else
        {
            $Message = 'There''s no new nodes to deploy'
            Write-Verbose -Message $Message
        }
    }

    End
    {
        $Message = "There are $( $NodeCurrent.Count ) nodes total"
        Write-Verbose -Message $Message

        Return ,$NodeCurrent
    }
}