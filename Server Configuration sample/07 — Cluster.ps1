Import-Module -Name 'FailoverClusters' -Verbose:$False

$Cluster = New-Cluster -Name 'HCI001' -Node $Address

While
(
    -Not ( Test-NetConnection -ComputerName 'HCI001' ).PingSucceeded
)
{
    Write-Verbose -Message 'Waiting for DNS'
    Start-Sleep -Seconds 15
}

$ClusterNetwork = Get-ClusterNetwork -InputObject $Cluster | Where-Object -FilterScript { $PSItem.Role -eq [Microsoft.FailoverClusters.PowerShell.ClusterNetworkRole]::ClusterAndClient }

$ClusterNetwork.Name = $Cluster.Domain