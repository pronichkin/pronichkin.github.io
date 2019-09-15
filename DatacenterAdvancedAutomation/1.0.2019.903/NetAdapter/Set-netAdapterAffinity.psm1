<#
    intelligently set processor assignment for Virtual Machine Queue (VMQ)
    or Receive Side Scaling (RSS) in NIC Teams
#>

Set-StrictMode -Version 'Latest'

Function
Set-netAdapterAffinity
{

   #region Data

        [cmdletBinding()]

        Param(
            [parameter(
                Mandatory = $True
            )]
            [System.String]
            $ComputerName
        )

   #endregion Data

   #region Code

        Write-Verbose -Message "Entering Set-netAdapterAffinity for $ComputerName"

        $Module = Import-ModuleEx -Name "NetLbfo"
        $Module = Import-ModuleEx -Name "NetAdapter"

        $Session = New-CimSession -ComputerName $ComputerName -Verbose:$False

        $GetCimInstanceProcParam = @{
        
          # ComputerName = $ComputerName
            CimSession   = $Session
            ClassName    = "Win32_Processor"
            Verbose      = $False
        }

      # Note that we need to force the object type since if there's only one
      # instance returned, normally it will not be an array, and thus
      # subsequent operations will fail when they rely on counting the items
      # in the array.

        [System.Array]$Processor = Get-CimInstance @GetCimInstanceProcParam

     <# $CoreTotal       = $Processor.Count * $Processor[0].NumberOfCores
        $HyperThreading  = $Processor[0].NumberOfLogicalProcessors /
                           $Processor[0].NumberOfCores  #>

        $CimInstanceParam = @{

            CimSession = $Session
            Namespace  = 'Root'
            ClassName  = '__Namespace'
            Filter     = "Name = 'Virtualization'"
            Verbose    = $False
        }

        If
        (
            Get-CimInstance @CimInstanceParam
        )
        {
            $Message = 'This is a Hyper-V host server, checking NUMA topology using Hyper-V WMI class'
            Write-Debug -Message $Message

            $GetCimInstanceParam = @{
        
              # ComputerName = $ComputerName
                CimSession   = $Session
                ClassName    = "Msvm_NumaNode"
                Namespace    = "root\virtualization\v2"
                Verbose      = $False
            }
            [System.Array]$NumaTopology = Get-CimInstance @GetCimInstanceParam
        }
        Else
        {
            $Message = 'This is not Hyper-V host server (probably a virtual machine.) Assuming NUMA topology based on Processor WMI class'
            Write-Debug -Message $Message

            [System.Array]$NumaTopology = $Processor
        }

        $NumaNodeTotal = $NumaTopology.Count -1

      # We cannot use NUMA Topology to obtain the number of Processor Cores
      # because it returns incorrect data when Hyper-Threading is not present.

      # $NumaNumberOfLogicalProcessors = $NumaTopology[0].NumberOfLogicalProcessors
        $NumaNumberOfLogicalProcessors = $Processor[0].NumberOfLogicalProcessors
      # $NumaNumberOfProcessorCores    = $NumaTopology[0].NumberOfProcessorCores        
        $NumaNumberOfProcessorCores    = $Processor[0].NumberOfCores
        $HyperThreading                = $NumaNumberOfLogicalProcessors / $NumaNumberOfProcessorCores
        $NumberOfProcessorCores        = $NumaNumberOfProcessorCores    * $NumaTopology.Count
        $NumberOfLogicalProcessors     = $NumaNumberOfLogicalProcessors * $NumaTopology.Count
        $NumaNodesPerProcessorGroup    = $NumberOfLogicalProcessors / 64
        $NumberOfProcessorGroups       = [System.Math]::Ceiling( $NumaNodesPerProcessorGroup )

        Write-Verbose -Message "Server physical configuration:"
        Write-Verbose -Message "  Processor model: $( $Processor[0].Name )"
        Write-Verbose -Message "  Total number of NUMA nodes: $( $NumaNodeTotal +1 )"
        Write-Verbose -Message "  Number of Cores per NUMA node:                              $NumaNumberOfProcessorCores"
        Write-Verbose -Message "  Number of Threads (Logical Processors) per NUMA node:       $NumaNumberOfLogicalProcessors"
        Write-Verbose -Message "  Total number of Cores in the server:                        $NumberOfProcessorCores"
        Write-Verbose -Message "  Total number of Threads (Logical Processors) in the server: $NumberOfLogicalProcessors"
        Write-Verbose -Message "  There are $HyperThreading Threads (Logical Processors) per Core."
        Write-Verbose -Message "  There are $NumberOfProcessorGroups processor group(s)"

        $pNicBoth      = @()
        $pNicvSwitch   = @()
        $pNicNovSwitch = @()

     <# Old logic only included teamed pNICs.
     
      # Get only teamed pNICs. We're not considering pNICs which are not used 
      # for Teams. In theory there might be valid scenarios where we need to 
      # set up RSS for not teamed adapters (SMB Multichannel) or VMQ for not
      # teamed adapters (separate vSwitches when used with SR-IOV) but these
      # are edge cases not covered by this logic.

        $NetAdapterParam = @{

            Name       = $Team.Members
            Physical   = $True
            cimSession = $ComputerName
        }
        $pNicTeam = Get-netAdapter @NetAdapterParam | Sort-Object -Property "macAddress"

      # This is no longer true since we need to accomodate for non-teamed pNICs
      # as well.  #>

        $NetAdapterParam = @{

            Physical     = $True
          # ComputerName = $ComputerName
            CimSession   = $Session
        }
        $pNicAll = Get-netAdapter @NetAdapterParam | Sort-Object -Property "macAddress"

      # We consider only pNICs with speed equal or greater than 10 Gbps. For 
      # lower speed there's no need to enable (and thus tune) RSS or VMQ.

        $pNicBoth = $pNicall | Where-Object -FilterScript {
        
            $psItem.Speed  -ge 10000000000 -and
            $psItem.Status -eq "up"
        }

      # Get pNICs which are connected to Virtual Switch. We will enablle VMQ
      # for these pNICs

        [Microsoft.HyperV.PowerShell.vmSwitch[]]$vSwitch = Get-vmSwitch -CimSession $Session -SwitchType 'External'

        $vSwitch | ForEach-Object -Process {

            $vSwitchCurrent = $psItem

            If
            (
                $vSwitchCurrent.EmbeddedTeamingEnabled
            )
            {
                $Message = "Virtual Switch `“$($vSwitchCurrent.Name)`” has Embedded Teaming enabled"
                Write-Verbose -Message $Message

                $TeamCurrent = Get-vmSwitchTeam -vmSwitch $vSwitchCurrent -cimSession $Session
                $vSwitchUplinkDescription = $TeamCurrent.NetAdapterInterfaceDescription

                If
                (
                    $vSwitchCurrent.Name -eq 'Storage'
                )
                {
                    $Message = '  Excluding Storage pNICs from calculation, as they are reserved for RDMA workloads'
                    Write-Verbose -Message $Message
                    
                    $pNicBoth = $pNicBoth | Where-Object -FilterScript {
                        $psItem.InterfaceDescription -notin $vSwitchUplinkDescription
                    }                 
                }
                Else
                {
                    $pNicvSwitch += $pNicBoth | Where-Object -FilterScript {
                        $psItem.InterfaceDescription -in $vSwitchUplinkDescription
                    }
                }
            }
            Else
            {
                [System.Array]$Team = Get-netLbfoTeam -cimSession $Session
                $vSwitchUplinkDescription = $vSwitchCurrent.NetAdapterInterfaceDescription
                $tNic = Get-netAdapter -cimSession $Session -InterfaceDescription $vSwitchUplinkDescription
                $TeamCurrent = $Team | Where-Object -FilterScript { $tNic.Name -in $psItem.TeamNics }
                $pNicvSwitch = $pNicBoth | Where-Object -FilterScript { $psItem.Name -in $TeamCurrent.Members }
            }
        }

        If
        (
            $pNicvSwitch
        )
        {
            Write-Verbose -Message "  pNICs for VMQ:"

            $pNicvSwitch | Sort-Object -Property 'Name' | ForEach-Object -Process {

                $Message = "    $( $psItem.Name )"
                Write-Verbose -Message $Message
            }
        }
        Else
        {
            Write-Verbose -Message "  There will be no pNICs to set for VMQ."
        }

      # The rest of the pNICs will be enabled for RSS

        $pNicNovSwitch = $pNicBoth | Where-Object -FilterScript { $psItem -notin $pNicvSwitch }

        If
        (
            $pNicNovSwitch
        )
        {
            Write-Verbose -Message "  pNICs for RSS:"

            $pNicNovSwitch | Sort-Object -Property 'Name' | ForEach-Object -Process {
                
                $Message = "    $( $psItem.Name )"
                Write-Verbose -Message $Message 
            }
        }
        Else
        {
            Write-Verbose -Message "  There will be no pNICs to set for RSS."
        }

        $ProcessorGroupCurrent = [int]0

        0..$NumaNodeTotal | ForEach-Object -Process {

            $NumaNodeCurrent = $psItem
            
            Write-Verbose -Message "Processing NUMA Node $NumaNodeCurrent"

            $CoreStartNumaNode   = [int]( $NumaNodeCurrent * $NumaNumberOfProcessorCores )
            $ThreadStartNumaNode = [int]( $NumaNodeCurrent * $NumaNumberOfLogicalProcessors )
            $CoreMaxNumaNode     = $CoreStartNumaNode   + $NumaNumberOfProcessorCores    - 1
            $ThreadMaxNumaNode   = $ThreadStartNumaNode + $NumaNumberOfLogicalProcessors - 1

            if
            (
                $ThreadMaxNumaNode -gt 64
            )
            {
                $ProcessorGroupCurrent++

                $CoreStartNumaNode   = 0
                $ThreadStartNumaNode = 0
                $CoreMaxNumaNode     = $CoreStartNumaNode   + $NumaNumberOfProcessorCores    - 1
                $ThreadMaxNumaNode   = $ThreadStartNumaNode + $NumaNumberOfLogicalProcessors - 1                
            }

         <# We should always keep Core 0 free
            If ( $CoreStartNumaNode -eq 0 ) { $CoreStartNumaNode = 1 }
            If ( $ThreadStartNumaNode -eq 0 ) { $ThreadStartNumaNode = $HyperThreading }  #>

            Write-Verbose -Message "  Cores                        from $CoreStartNumaNode to $CoreMaxNumaNode"
            Write-Verbose -Message "  Threads (Logical Processors) from $ThreadStartNumaNode to $ThreadMaxNumaNode"
            Write-Verbose -Message "  Processor Group: $ProcessorGroupCurrent"

            [System.Array]$pNicNodeCurrent = $pNicBoth | Where-Object -FilterScript {
            
                ( Get-netAdapterHardwareInfo -cimSession $Session -Name $psItem.Name ).NumaNode -eq $NumaNodeCurrent
            }

            If
            (
                $pNicNodeCurrent
            )
            {
                $pNicCount = $pNicNodeCurrent.Count

                Write-Verbose -Message "  pNICs in current NUMA Node (total $pNicCount):"
                
                $pNicNodeCurrent | Sort-Object -Property 'Name' | ForEach-Object -Process {
                
                    $Message = "    $( $psItem.Name )"
                    Write-Verbose -Message $Message
                }

                $CoreIncrement   = $NumaNumberOfProcessorCores / $pNicCount
                $ThreadIncrement = $NumaNumberOfLogicalProcessors / $pNicCount

                Write-Verbose -Message "  Each pNIC will be assigned with $CoreIncrement Cores and $ThreadIncrement Threads (Logical Processors)"

              # The first pNIC will start from the first Core available in this NUMA Node.

                $CoreStartpNic = $CoreStartNumaNode

                $pNicNodeCurrent | ForEach-Object -Process {

                    $pNicCurrent = $psItem                    

                    Write-Verbose -Message "  Processing pNIC `"$( $pNicCurrent.Name )`""

                    Write-Verbose -Message "    Model: $( $pNicCurrent.DriverDescription )"
                    Write-Verbose -Message "    Info:  $( $pNicCurrent.DriverInformation )"

                  # Calculate pNIC affinity

                    If
                    (
                        $CoreStartpNic -eq 0 -and
                        $ProcessorGroupCurrent -eq 0
                    )

                  # We should always keep Core 0 free. Thus we start from the next available Core and Thread (Logical Processor)

                    {
                        Write-Verbose -Message "    This pNIC will have one Core less (and $HyperThreading Threads less) because Core 0 is excluded."
                        Write-Verbose -Message "    (We're reserving Core 0 for Default queues)." 
                
                      # BaseProcessorNumber and MaxProcessorNumber both
                      # count Threads (Logical Processors), not Cores
                        $BaseProcessorNumber = 1 * $HyperThreading

                      # MaxProcessors counts Cores, not Threads (Logical Processors)
                        $MaxProcessors       = $CoreIncrement - 1
                    }
                    Else
                    {

                      # BaseProcessorNumber and MaxProcessorNumber
                      # count Threads (Logical Processors), not Cores
                        $BaseProcessorNumber = $CoreStartpNic * $HyperThreading

                      # MaxProcessors counts Cores, not Threads (Logical Processors)
                        $MaxProcessors       = $CoreIncrement
                    }

                  # BaseProcessorNumber and MaxProcessorNumber
                  # count Threads (Logical Processors), not Cores
                    $MaxProcessorNumber = ( $CoreStartpNic + $CoreIncrement ) * $HyperThreading - 1

                    Write-Verbose -Message "    Starting Thread (Logical Processor): $BaseProcessorNumber"
                    Write-Verbose -Message "    Ending Thread (Logical Processor):   $MaxProcessorNumber"
                    Write-Verbose -Message "    Total Cores: $MaxProcessors (calculated)"

                  # We might need to check whether $MaxProcessors value is appropriate.

                    $GetNetAdapterAdvancedPropertyParam = @{
                    
                        Name                = $pNicCurrent.Name
                        cimSession          = $Session
                      # RegistryKeyword     = "*MaxRssProcessors"
                    }
                    $AdvancedProperty = Get-netAdapterAdvancedProperty @GetNetAdapterAdvancedPropertyParam |
                        Where-Object -FilterScript { $psItem.RegistryKeyword -eq "*MaxRssProcessors" }
                    
                    If
                    (
                        $AdvancedProperty -and
                        $AdvancedProperty.ValidRegistryValues
                    )
                    {
                        While
                        (
                            $MaxProcessors -notin $AdvancedProperty.ValidRegistryValues
                        )
                        {
                            $MaxProcessors++
                        }

                        Write-Verbose -Message "    Total Cores: $MaxProcessors (adjusted to fit in acceptable values)"
                    }

                  # Set pNIC Affinity

                    $SetNetAdapterParam = @{

                      # This won't work because different cmdlets (RSS and VMQ) expect different input object types.
                      # InputObject         = $pNicCurrentConfig

                        Name                = $pNicCurrent.Name
                        cimSession          = $Session
                        BaseProcessorGroup  = $ProcessorGroupCurrent
                        BaseProcessorNumber = $BaseProcessorNumber
                      # MaxProcessorGroup   = $ProcessorGroupCurrent  # only supported for RSS but not for VMQ
                        MaxProcessorNumber  = $MaxProcessorNumber
                        MaxProcessors       = $MaxProcessors
                        NumaNode            = $NumaNodeCurrent
                        Enabled             = $True
                        PassThru            = $True
                    }

                    Write-Verbose -Message "    Configuring pNIC affinity.."

                    $pNicCurrentAffinity = Set-netAdapterVmq @SetNetAdapterParam
                    $pNicCurrentAffinity = Set-netAdapterRss @SetNetAdapterParam
                    
                  # Disable the othher type of offload

                    $DisableNetAdapterParam = @{

                        Name                = $pNicCurrent.Name
                        cimSession          = $Session
                        PassThru            = $True
                    }

                    If
                    (
                        $pNicvSwitch -and $pNicCurrent -in $pNicvSwitch
                    )
                    {
                        Write-Verbose -Message "    Configuring pNIC for VMQ..."

                        $pNicCurrentAffinity = Disable-netAdapterRss @DisableNetAdapterParam                        
                    }
                    Else
                    {
                        Write-Verbose -Message "    Configuring pNIC for RSS..."

                        $pNicCurrentAffinity = Disable-netAdapterVmq @DisableNetAdapterParam                        
                    }

                    Write-Verbose -Message "  Done with pNIC `"$($pNicCurrent.Name)`""

                  # Increment the starting Core number for the next pNIC

                    $CoreStartpNic = $CoreStartpNic + $CoreIncrement
                }
            }
            Else
            {
                Write-Verbose -Message "  There are no pNICs in the current NUMA node!"
            }

            Write-Verbose -Message "Done with NUMA Node $NumaNodeCurrent"
        }

      # Remove-CimSession -CimSession $Session

        Write-Verbose -Message "Exiting  Set-netAdapterAffinity for $ComputerName"

   #endregion Code

}