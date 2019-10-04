Set-StrictMode -Version 'Latest'

Function
Resume-ClusterNodeEx
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
        Write-Verbose -Message "$( $Time.DateTime )  0  Post-CAU script starting on $ComputerName"

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

            #region Exit storage maintenance mode

                If
                (
                    $Disk.OperationalStatus -contains 'In Maintenance Mode'
                )
                {
                    $Time = ( Get-Date -DisplayHint Time )        
                    Write-Verbose -Message "$( $Time.DateTime )  1  Exiting storage maintenance mode"
                    Disable-StorageMaintenanceMode -InputObject $FaultDomain -Verbose:$False -CimSession $Session
                }
                Else
                {
                    $Time = ( Get-Date -DisplayHint Time )        
                    Write-Verbose -Message "$( $Time.DateTime )  1  Storage is already not in maintenance mode"
                }

            #endregion Exit storage maintenance mode

            #region Resume node

                $Node = Get-CimInstance -ClassName 'msCluster_node' -Namespace 'root\msCluster' -Verbose:$False -CimSession $Session | Where-Object -FilterScript { $ComputerName -like "$($psItem.Name)*" }

                If
                (
                    $Node.State -eq 2
                )
                {
                    $Time = ( Get-Date -DisplayHint Time )
                    Write-Verbose -Message "$( $Time.DateTime )  2  Resuming cluster node"

                    $Argument = @{ FailbackType = 0 }  # Do not fail back
                    [void]( Invoke-CimMethod -CimInstance $Node -MethodName 'Resume' -Arguments $Argument -Verbose:$False )
                }
                Else
                {
                    $Time = ( Get-Date -DisplayHint Time )
                    Write-Verbose -Message "$( $Time.DateTime )  2  Cluster node is not paused"
                }

            #endregion Resume node

            #region Ensure storage is healthy

                $Time = ( Get-Date -DisplayHint Time )
                Write-Verbose -Message "$( $Time.DateTime )  3  Validating storage health"

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
        }
        Else
        {
            $Time = ( Get-Date -DisplayHint Time )
            Write-Verbose -Message "$( $Time.DateTime )     This node does not have Physical Disks connected, nothing to put out Maintenance mode"
        }
    }    
}