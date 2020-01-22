$ClusterStorageSpacesDirect = Enable-ClusterStorageSpacesDirect -CimSession $cimSession[0] -Confirm:$False

$StoragePool = Get-StoragePool -CimSession $cimSession[0] | Where-Object -FilterScript { -not $psItem.isPrimordial -and $psItem.isClustered }

$MAP    = New-Volume -StoragePool $StoragePool -FriendlyName 'Mirror-accelerated parity' -FileSystem CSVFS_ReFS -StorageTierFriendlyNames @( 'MirrorOnHDD', 'Capacity' ) -StorageTierSizes @( 200gb, 800gb ) -CimSession $cimSession[0] 
$Mirror = New-Volume -StoragePool $StoragePool -FriendlyName 'Mirror'  -FileSystem CSVFS_ReFS -ResiliencySettingName 'Mirror' -NumberOfDataCopies 3 -ProvisioningType Fixed -Size 1tb -CimSession $cimSession[0]