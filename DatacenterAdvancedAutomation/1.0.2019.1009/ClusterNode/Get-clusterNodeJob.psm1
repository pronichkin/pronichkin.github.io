Set-StrictMode -Version 'Latest'

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
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        $vmmServer
    )

    Begin
    {
        $Message = "  Entering Get-clusterNodeJob for $($Node.Count) nodes"
        Write-Debug -Message $Message

      # At this point “Node Cluster” collection might store objects
      # of different types—already deployed (pre-existing)
      # and not yet deployed

      # $NodeCurrent = [System.Collections.Generic.List[System.Object]]::new()

        $Node | ForEach-Object -Process {

            $NodePerspective = $psItem

          # Write-Debug -Message $NodePerspective.GetType().FullName

                    Switch
                    (
                        $NodePerspective.GetType().FullName
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

                            $ConfigurationVirtual.Add( $NodePerspective )
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

                            $ConfigurationPhysical.Add( $NodePerspective )
                        }

                      # These object types indicate nodes that are already
                      # deployed and hence should be carried over as is

                        {
                            $psItem -in @(
                                
                                'Microsoft.SystemCenter.VirtualMachineManager.Host'
                                'Microsoft.SystemCenter.VirtualMachineManager.VM'
                              # 'System.String'
                                'Microsoft.ActiveDirectory.Management.adComputer'
                            )
                        }
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                            )
                            {
                                $NodeCurrent = New-Object -TypeName "System.Collections.Generic.List[$psItem]"
                            }

                            $NodeCurrent.Add( $NodePerspective )
                        }                        
                        
                     <# 'Microsoft.SystemCenter.VirtualMachineManager.Host'
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                            )
                            {
                                $NodeCurrent = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::New()
                            }

                            $NodeCurrent.Add( $NodePerspective )
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

                            $NodeCurrent.Add( $NodePerspective )
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

                            $NodeCurrent.Add( $NodePerspective )
                        }

                        'Microsoft.ActiveDirectory.Management.adComputer'
                        {
                            If
                            (
                                -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                            )
                            {
                                $NodeCurrent = [System.Collections.Generic.List[Microsoft.ActiveDirectory.Management.adComputer]]::New()
                            }

                            $NodeCurrent.Add( $NodePerspective )
                        }  #>

                        Default
                        {
                            $Message = "Unexpected Node object type: `“$psItem`”"
                            Write-Warning -Message $Message
                        }
                    }
                }
    }

    Process
    {
        If
        (
             Test-Path -Path 'Variable:\ConfigurationVirtual'
        )
        {
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]$vmmServerForOnBehalfOf =
                Get-scvmmServerEx -vmmServer $vmmServer -ForOnBehalfOf

            $VirtualMachine = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::new()

            $VirtualMachineParam = @{

                vmmServer              = $vmmServerForOnBehalfOf
                VirtualMachineProperty = $ConfigurationVirtual
            }
            $VirtualMachine.AddRange(
                [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]](
                    New-scVirtualMachineJob @VirtualMachineParam
                )
            )

            $vmmServerForOnBehalfOf.Disconnect()

            Remove-Variable -Name 'vmmServerForOnBehalfOf'

            If
            (
                $VirtualMachine[0].Name.Substring( $VirtualMachine[0].Name.IndexOf( '.' ) +1 ) -eq $env:UserDnsDomain
            )
            {
                $Message = '    Running in the same domain, returning AD Computer(s)'

                $Computer = [System.Collections.Generic.List[Microsoft.ActiveDirectory.Management.adComputer]]::New()

                $VirtualMachine | ForEach-Object -Process {

                    $Computer.Add( ( Get-adComputer -Identity $psItem.Name.Split( '.' )[0] ) )
                }

                If
                (
                    -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                )
                {
                    $NodeCurrent = [System.Collections.Generic.List[Microsoft.ActiveDirectory.Management.adComputer]]::New()
                }

                $NodeCurrent.AddRange( $Computer )
            }
            Else
            {
                $Message = '    Running in a different domain, returning Virtual Machine(s)'

                If
                (
                    -Not ( Test-Path -Path 'Variable:\NodeCurrent' )
                )
                {
                    $NodeCurrent = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]::New()
                }

                $NodeCurrent.AddRange( $VirtualMachine )
            }

            Write-Debug -Message $Message
        }
        ElseIf
        (
            Test-Path -Path 'Variable:\ConfigurationPhysical'
        )
        {
          # The following steps are specific to Scale Unit Type

            Switch
            (
                $ConfigurationPhysical[0].PhysicalComputerProfile.Role
            ) 
            { 
             <# {
                    $psItem -in @(

                        'Management'
                        'Compute'
                        'Network'
                    )
                }  #>

                'vmHost'
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

                            $NodeCurrent.AddRange( [System.Collections.Generic.List[
                                Microsoft.SystemCenter.VirtualMachineManager.Host
                            ]]( New-scvmHostJob -Configuration $ConfigurationPhysical ) )

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

                 'FileServer'
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
        $Message = "  Exiting  Get-clusterNodeJob with $( $NodeCurrent.Count ) nodes"
        Write-Debug -Message $Message

        Return ,$NodeCurrent
    }
}