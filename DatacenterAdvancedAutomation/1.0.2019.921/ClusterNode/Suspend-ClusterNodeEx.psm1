Set-StrictMode -Version 'Latest'

Function
Suspend-ClusterNodeEx
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ComputerName = $env:ComputerName
    )
    
    Process
    {
        $Time = ( Get-Date -DisplayHint Time )        
        Write-Verbose -Message "$( $Time.DateTime )  0  Pre-CAU script starting on $ComputerName"
    
        $Session = New-CimSession -ComputerName $ComputerName -Verbose:$False

        $FaultDomain = Get-StorageFaultDomain -Type StorageScaleUnit -Verbose:$False -CimSession $Session | Where-Object -FilterScript { $ComputerName -like "$($psItem.FriendlyName)" }
        $SubSystem = $FaultDomain | ForEach-Object -Process { Get-StorageSubSystem -StorageFaultDomain $PSItem -CimSession $Session } | Sort-Object -Unique
        $Node = Get-StorageNode -StorageSubSystem $SubSystem | Where-Object -FilterScript { $psItem.Name -like "$ComputerName.*" }
        $Disk = Get-PhysicalDisk -StorageNode $Node -PhysicallyConnected -Verbose:$False -CimSession $Session

        If
        (
            $Disk
        )
        {
            $Time = ( Get-Date -DisplayHint Time )        
            Write-Verbose -Message "$( $Time.DateTime )     This node has some Physical Disks connected"        

            If
            (
                $Disk.OperationalStatus -contains 'In Maintenance Mode'
            )
            {
                $Time = ( Get-Date -DisplayHint Time )        
                Write-Verbose -Message "$( $Time.DateTime )  1  Storage is already in maintenance mode"
            }
            Else
            {
                #region Ensure storage is healthy

                    $Time = ( Get-Date -DisplayHint Time )
                    Write-Verbose -Message "$( $Time.DateTime )  1  Validating storage health"

                    While
                    (
                        Get-StorageJob -CimSession $Session -UniqueId * | Where-Object -FilterScript { $psItem.Name -eq 'Repair' -and $psItem.jobState -ne 'Completed' }
                    )
                    {
                        $Time = ( Get-Date -DisplayHint Time )
                        Write-Verbose -Message "$( $Time.DateTime )   ...Jobs are still running"

                        Start-Sleep -Seconds 20
                    }

                    While
                    (
                        Get-VirtualDisk -CimSession $Session | Where-Object -FilterScript { $psItem.OperationalStatus -ne 'ok' }
                    )
                    {
                        $Time = ( Get-Date -DisplayHint Time )
                        Write-Verbose -Message "$( $Time.DateTime )   ...Disks are not ok yet"

                        Start-Sleep -Seconds 20
                    }

                    $Time = ( Get-Date -DisplayHint Time )
                    Write-Verbose -Message "$( $Time.DateTime )     Storage is healthy now"

                #endregion Ensure storage is healthy

                #region Drain node

                    $Time = ( Get-Date -DisplayHint Time )
                    Write-Verbose -Message "$( $Time.DateTime )  2  Draining cluster node"

                    $Node = Get-CimInstance -ClassName 'msCluster_node' -Namespace 'root\msCluster' -Verbose:$False -CimSession $Session | Where-Object -FilterScript { $ComputerName -like "$($psItem.Name)*" }
                    $Argument = @{ DrainType = 1 }  # Drain
                    [void]( Invoke-CimMethod -CimInstance $Node -MethodName 'Pause' -Arguments $Argument -Verbose:$False )

                    $Node = Get-CimInstance -ClassName 'msCluster_node' -Namespace 'root\msCluster' -Verbose:$False -CimSession $Session | Where-Object -FilterScript { $ComputerName -like "$($psItem.Name)*" }

                    While
                    (    
                        $Node.NodeDrainStatus -notin @( 0, 2 )
                    )
                    {    
                        Start-Sleep -Seconds 10
                        $Node = Get-CimInstance -ClassName 'msCluster_node' -Namespace 'root\msCluster' -Verbose:$False -CimSession $Session | Where-Object -FilterScript { $ComputerName -like "$($psItem.Name)*" }

                        Switch
                        (
                            $Node.NodeDrainStatus
                        )
                        {
                            0
                            {
                                $Time = ( Get-Date -DisplayHint Time )
                                Write-Verbose -Message "$( $Time.DateTime )   Drain was not required"
                            }

                            1
                            {
                                $Time = ( Get-Date -DisplayHint Time )
                                Write-Verbose -Message "$( $Time.DateTime )   ...Still draining"
                            }

                            2
                            {
                                $Time = ( Get-Date -DisplayHint Time )
                                Write-Verbose -Message "$( $Time.DateTime )     Drain succeeded"
                            }

                            3
                            {
                                $Time = ( Get-Date -DisplayHint Time )
                                Write-Verbose -Message "$( $Time.DateTime )   Drain failed. Retrying"

                                [void]( Invoke-CimMethod -CimInstance $Node -MethodName 'Pause' -Arguments $Argument -Verbose:$False )
                            }

                            Default
                            {
                                $Time = ( Get-Date -DisplayHint Time )
                                Write-Warning -Message "$( $Time.DateTime )   Unknown node drain status $( $Node.NodeDrainStatus )"
                            }
                        }
                    }

                #endregion Drain node

                #region Enter storage maintenance mode

                    $Time = ( Get-Date -DisplayHint Time )
                    Write-Verbose -Message "$( $Time.DateTime )  3  Entering storage maintenance mode"

                    Enable-StorageMaintenanceMode -InputObject $FaultDomain -CimSession $Session -ValidateVirtualDisksHealthy $True -Verbose:$False

                    $Time = ( Get-Date -DisplayHint Time )
                    Write-Verbose -Message "$( $Time.DateTime )     Completed"

                #endregion Enter storage maintenance mode
            }
        }
        Else
        {
            $Time = ( Get-Date -DisplayHint Time )
            Write-Verbose -Message "$( $Time.DateTime )     This node does not have Physical Disks connected, nothing to put into Maintenance mode"
        }
    }
}