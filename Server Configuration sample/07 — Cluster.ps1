$Name = 'HCI001'

Import-Module -Name 'FailoverClusters' -Verbose:$False

$Cluster = New-Cluster -Name $Name -Node $Address

While
(
    -Not ( Test-NetConnection -ComputerName $Name -Verbose:$False -Debug:$False ).PingSucceeded
)
{
    Write-Verbose -Message 'Waiting for DNS'
    Start-Sleep -Seconds 15
    Clear-DnsClientCache
}