$Name = [System.Collections.Generic.List[System.String]]::new()

$Name.Add( 'ArtemP-RS5CL-01' )
$Name.Add( 'ArtemP-RS5CL-02' )

$Group = [System.Collections.Generic.List[
    Microsoft.FailoverClusters.PowerShell.ClusterGroup
]]::new()

$Vm = [System.Collections.Generic.List[
    Microsoft.HyperV.PowerShell.VirtualMachine
]]::new()

$Disk = [System.Collections.Generic.List[
    Microsoft.Vhd.PowerShell.VirtualHardDisk
]]::new()

$Cluster = Get-Cluster -Name $Address[0]

$Name | ForEach-Object -Process {

    $GroupCurrent = Get-ClusterGroup -InputObject $Cluster -Name "$psItem*"

    $Group.Add( $GroupCurrent )

    $Vm.Add( ( Get-Vm -ClusterObject $GroupCurrent ) )
}

$Group | ForEach-Object -Process {
    Remove-ClusterGroup -InputObject $psItem -RemoveResources -Force
}

$Vm | ForEach-Object -Process {
    Get-vmScsiController -VM $psItem | ForEach-Object -Process {
        Get-vmHardDiskDrive -vmDriveController $psItem | ForEach-Object -Process {
            $Disk.Add( ( Get-VHD -CimSession $cimSession[0] -Path $psItem.Path ) )
        }
    }
}

Remove-Vm -VM $vm -Force

Invoke-Command -Session $psSession[0] -ScriptBlock {

    Remove-Item -Path $using:Disk.Path
}