$CapabilityName = [System.Collections.Generic.List[System.String]]::new()
$CapabilityName.Add( 'Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0' )
$CapabilityName.Add( 'Rsat.FileServices.Tools~~~~0.0.1.0' )
$CapabilityName.Add( 'Rsat.ServerManager.Tools~~~~0.0.1.0' )
$CapabilityName.Add( 'Rsat.Shielded.VM.Tools~~~~0.0.1.0' )
$CapabilityName.Add( 'Rsat.StorageReplica.Tools~~~~0.0.1.0' )
$CapabilityName.Add( 'Rsat.SystemInsights.Management.Tools~~~~0.0.1.0' )

[System.Void]( $CapabilityName | ForEach-Object -Process {
    Add-WindowsCapability -Online -Name $psItem
})