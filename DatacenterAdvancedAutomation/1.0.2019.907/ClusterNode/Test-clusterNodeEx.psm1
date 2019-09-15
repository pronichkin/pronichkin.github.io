Set-StrictMode -Version 'Latest'

Function
Test-clusterNodeEx
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )
   
    Process
    {
     <# Try
        {

          # We cannot use “Resolve-DnsNameEx” here because the cluster name
          # might be non-existent.

            $ClusterAddress = [System.Net.Dns]::GetHostByName( $Name ).HostName
            $Cluster        = Get-Cluster -Name $ClusterAddress -ErrorAction Ignore -WarningAction Ignore
        }
        Catch
        {
          
          # There's no such cluster.
          # This means we're dealing with a stand-alone server

        }  #>

        $ComputerParam = @{

            Identity   = $Name
            Properties = 'servicePrincipalName'
        }
        $Computer = Get-adComputer @ComputerParam

        If
        (
            $Computer.servicePrincipalName | Where-Object -FilterScript {
                $psItem -like 'msServerClusterMgmtApi/*'
            }
        )
        {
            $Address = Resolve-DnsNameEx -Name $Name

            $Message = "    `“$Address`” is either a cluster node or a cluster network name (CNO or VCO)"
            Write-Debug -Message $Message

            $ClusterParam = @{

                Name          = $Address
                Verbose       = $False
              # ErrorAction   = "Ignore"
              # WarningAction = "SilentlyContinue"
           }
           $Cluster = Get-Cluster @ClusterParam

         # $ClusterAddress = Resolve-DnsNameEx -Name $ClusterCurrent.Name
        }
        Else
        {
            $Message = "    `“$Name`” is neeither a cluster node nor a cluster network name (CNO or VCO)"
            Write-Debug -Message $Message

            $Cluster = $False
        }

      # Return [System.Boolean]( Test-Path -Path "Variable:\Cluster" )
        Return $Cluster
    }
}