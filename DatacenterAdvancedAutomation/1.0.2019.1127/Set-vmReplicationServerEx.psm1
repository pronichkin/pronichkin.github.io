Function
Set-vmReplicationServerEx
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.FailoverClusters.PowerShell.Cluster]
        $Cluster
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Net.IPAddress]
        $ipAddress
    )

    Process
    {
        [System.Void]( Import-ModuleEx -Name 'NetSecurity' )

        If
        (
            [System.String]::IsNullOrWhiteSpace( $Name )
        )
        {
            $Name = $Cluster.Name + '-Broker'
        }
    
        $Group = Get-ClusterGroup -InputObject $Cluster |
            Where-Object -FilterScript { $psItem.Name -eq $Name }

        If
        (
            $Group
        )
        {
            $Message = "Cluster group `“$Name`” already exists on cluster `“$( $Cluster.Name )`”"
            Write-Verbose -Message $Message
        }
        Else
        {
            $Message = "Enabling Hyper-V Replica on cluster `“$( $Cluster.Name )`”"
            Write-Verbose -Message $Message

          # Group

            $GroupParam = @{

                GroupType   = 'vmReplicaBroker'
                Name        = $Name
                InputObject = $Cluster
            }
            $Group = Add-ClusterGroup @GroupParam

          # IP Address Resource

            $ResourceParam = @{

                Name         = "IP Address"
                Group        = $Group
                ResourceType = 'IP Address'
                InputObject  = $Cluster
            }
            $ResourceAddress = Add-ClusterResource @ResourceParam
 
            If
            (
                $ipAddress
            )
            {
                $Network = Get-ClusterNetwork -InputObject $Cluster |
                    Where-Object -FilterScript { $psItem.Role -eq 'ClusterAndClient' }

                $Parameter = @{

                    Address    = $ipAddress.ToString()
                    SubnetMask = $Network.AddressMask
                }
                Set-ClusterParameter -InputObject $ResourceAddress -Multiple $Parameter
            }
            Else
            {
                Set-ClusterParameter -InputObject $ResourceAddress -Name 'EnableDhcp' -Value 1
            }

          # Virtual Computer Ojbect (VCO) resource

            $ResourceParam = @{

                Name         = $Name
                Group        = $Group
                ResourceType = 'Network Name'
                InputObject  = $Cluster
            }
            $ResourceName = Add-ClusterResource @ResourceParam

            Set-ClusterParameter -InputObject $ResourceName -Name 'Name' -Value $Name

            $ResourceDependencyParam = @{

                InputObject = $ResourceName
                Provider    = $ResourceAddress.Name
                Verbose     = $False
            }
            $ResourceName = Add-ClusterResourceDependency @ResourceDependencyParam

          # Hyper-V Replica Broker Resource

            $ResourceParam = @{

                Name         = "Hyper-V Replica Broker $Name"
                Group        = $Group
                ResourceType = 'Virtual Machine Replication Broker'
                InputObject  = $Cluster
            }
            $ResourceBroker = Add-ClusterResource @ResourceParam

            $ResourceDependencyParam = @{

                InputObject = $ResourceBroker
                Provider    = $ResourceName.Name
                Verbose     = $False
            }
            $ResourceBroker = Add-ClusterResourceDependency @ResourceDependencyParam

          # Replication Settings

            $SharedVolume       = Get-ClusterSharedVolume -InputObject $Cluster |
                Sort-Object -Property 'Name' | Select-Object -First 1

            $PathParam = @{ 

                Path      = $SharedVolume.sharedVolumeInfo.FriendlyVolumeName
                ChildPath = 'Replica'
            }
            $Path = Join-Path @PathParam

          # This is kinda weird format, but that's how Cluster stores Replica settings

            $AuthorizationValue = "* $Path\ DEFAULT"

            Set-ClusterParameter -InputObject $ResourceBroker -Name 'RecoveryServerEnabled' -Value 1
            Set-ClusterParameter -InputObject $ResourceBroker -Name 'AuthenticationType'    -Value 1
            Set-ClusterParameter -InputObject $ResourceBroker -Name 'Authorization'         -Value $AuthorizationValue

          # Enable Firewall rules

            $Node = Get-ClusterNode -InputObject $Cluster

            $Session = New-CimSession -ComputerName $Node.Name -Verbose:$False

            $FirewallRule = Get-netFirewallRule -CimSession $Session -DisplayName 'Hyper-V Replica HTTP Listener (TCP-In)'

            Enable-netFirewallRule -InputObject $FirewallRule

          # Remove-CimSession -CimSession $Session

            $Group = Start-ClusterGroup -InputObject $Group -Verbose:$False
        }

      # Takes time to start the cluster group for the first time, probably
      # due to AD replication

        While
        (
            $Group.State -ne 'Online'
        )
        {
            [System.Void]( Start-ClusterGroup -InputObject $Group )

            $Message = 'Waiting for the Hyper-V Replica Broker cluster group to start'
            Write-Debug -Message $Message

            Start-Sleep -Seconds 60
        }
    }
}