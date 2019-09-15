Function
Test-clusterEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({

            $psItem.GetType().FullName -in @(

                'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'
                'Microsoft.FailoverClusters.PowerShell.Cluster'
            )
        })]
        $Cluster
    )

    $Message = 'Refreshing and validating the cluster'
    Write-Verbose -Message $Message

    Switch
    (
        $Cluster.GetType().FullName
    )
    {
        'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'
        {
            $Cluster = Read-scvmHostCluster -vmHostCluster $Cluster

            $ClusterValidationResult = Test-scvmHostCluster -vmHostCluster $Cluster

            Switch
            (
                $ClusterValidationResult.ValidationResult
            )
            {
                'SuccessWithWarning'
                {
                    $Message = 'Cluster validation passed with Warning status. Please examine the validation report'
                    Write-Verbose -Message $Message
               
                    & "\\$($Cluster.Nodes[0].Name)\c$\Windows\Cluster\Reports\$($ClusterValidationResult.ResultFileLocation)"
                }

                Default
                {
                    $Message = "Unknown cluster validation result `“$( $ClusterValidationResult.ValidationResult )`”"
                    Write-Warning -Message $Message
                }
            }  
        }

        'Microsoft.FailoverClusters.PowerShell.Cluster'
        {
            Test-Cluster -InputObject $Cluster
        }
    }
}