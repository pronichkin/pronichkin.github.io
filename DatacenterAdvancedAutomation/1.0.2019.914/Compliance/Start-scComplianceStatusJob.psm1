Set-StrictMode -Version 'Latest'

Function
Start-scComplianceStatusJob
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
            $vmmServer
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.Core.Connection.Connection]
            $OpsMgrConnection
        , 
            [Parameter(
                Mandatory = $True
            )]
            [ValidateSet(
                'Scan',
                'Remediate'
            )]
            [System.String]
            $Mode
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[System.String]]
            $RoleName
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.HostGroup]]
            $HostGroup
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $ThrottleLimit = 10
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $Retry = 3
    )

  # Prepare groups

    Begin
    {
        Write-Verbose -Message "Running in $Mode mode"
  
      # $ManagedComputer                          = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]::new()
      # $ManagedComputerInfrastructure            = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]::new()

        $ManagedComputerInfrastructureStandAlone  = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]::new()
        $ManagedComputerStandAlone                = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]::new()
        $ManagedComputerAll                       = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]::new()
        
      # $vmHost                         = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::new()
      # $vmHostStandAlone               = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::new()
      # $vmHostClusterNode              = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::new()        

        $Cluster                        = [System.Collections.Generic.List[Microsoft.FailoverClusters.PowerShell.Cluster]]::new()
        $ClusterInfrastructure          = [System.Collections.Generic.List[Microsoft.FailoverClusters.PowerShell.Cluster]]::new()

      # $ClusterHost                    = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.HostCluster]]::new()

      # Collection to store results

        $ComplianceStatus               = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]]::new()

        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$ManagedComputer =
            Get-scvmmManagedComputer -vmmServer $vmmServer | Where-Object -FilterScript { $psItem.Role -ne 'NotAssociated' }

        $Message = "Total number of Managed Computer(s) in VMM: $( $ManagedComputer.Count )"
        Write-Verbose -Message $Message

        If
        (
            $RoleName
        )
        {
          # Only Infrastructure Servers in specified Roles        
                
            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$ManagedComputerInfrastructure =
                $ManagedComputer | Where-Object -FilterScript {
                    $psItem.Role -in $RoleName
                }

            $Message = "Total number of Infrastructure Server(s) in specified Role(s): $( $ManagedComputerInfrastructure.Count )"
            Write-Verbose -Message $Message

            $ManagedComputerAll.AddRange(
                $ManagedComputerInfrastructure
            )

          # Separate cluster members from stand-alone (non-clustered) computers
            
            $ManagedComputerInfrastructure | ForEach-Object -Process {

             <# $ComputerParam = @{

                    Identity   = $psItem.ComputerName
                    Properties = 'servicePrincipalName'
                }
                $Computer = Get-adComputer @ComputerParam  #>

                $ClusterCurrent = Test-ClusterNodeEx -Name $psItem.ComputerName

                If
                (
                 <# $Computer.servicePrincipalName | Where-Object -FilterScript {
                        $psItem -like 'msServerClusterMgmtApi/*'
                    }  #>

                    $ClusterCurrent
                )
                {
                    Write-Debug -Message $psItem.FullyQualifiedDomainName

                 <# $ClusterParam = @{

                        Name          = $psItem.FullyQualifiedDomainName
                        Verbose       = $False
                      # ErrorAction   = "Ignore"
                      # WarningAction = "SilentlyContinue"
                    }
                    $ClusterCurrent = Get-Cluster @ClusterParam  #>

                  # $ClusterAddress = Resolve-DnsNameEx -Name $ClusterCurrent.Name

                    $ClusterInfrastructure.Add( $ClusterCurrent )
                }
                Else
                {
                    $ManagedComputerInfrastructureStandAlone.Add( $psItem )
                }
            }

          # Stand-Alone collection Infrastructure server(s)

            If
            (
                $ManagedComputerInfrastructureStandAlone
            )
            {
                $Count = $ManagedComputerInfrastructureStandAlone.Count
                $Message = "Found " + $Count + " Stand-Alone Infrastructure Server(s) in scope"

                $ManagedComputerStandAlone.AddRange(
                    $ManagedComputerInfrastructureStandAlone
                )
            }
            Else
            {
                $Message = 'There are no Stand-alone Infrastructure Server(s) found in specified Role(s)'
                Write-Verbose -Message $Message
            }

          # Clusters of Infrastructure servers

            If
            (
                $ClusterInfrastructure
            )
            {
                [System.Collections.Generic.List[Microsoft.FailoverClusters.PowerShell.Cluster]]$ClusterInfrastructureUnique =
                    $ClusterInfrastructure | Sort-Object -Unique

                $Count = $ClusterInfrastructureUnique.Count
                $Message = "Found " + $Count + " Infrastructure Cluster(s) in scope"

                $Cluster.AddRange( $ClusterInfrastructureUnique )
            }
            Else
            {
                $Message = "There are no Infrastructure Cluster(s) found in specified Role(s)"
            }
            Write-Verbose -Message $Message
        }
        Else
        {
            $Message = 'No Roles were specified for Infrastructure Server(s)'
            Write-Verbose -Message $Message
        }

        If
        (
            $HostGroup
        )
        {
            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]$vmHost =
                Get-scvmHostEx -vmHostGroup $HostGroup -Recurse

            $ManagedComputerAll.AddRange(
                [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$vmHost.ManagedComputer
            )

          # Only Stand-Alone (non-Clustered) VM Hosts in specified Host Groups        

            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]$vmHostStandAlone =
                $vmHost | Where-Object -FilterScript {        
                    -Not $psItem.HostCluster
                }

          # Managed Computer objects for Stand-Alone VM Hosts in specified Host Groups
  
            If
            (
                $vmHostStandAlone
            )
            {
                $Count = @($vmHostStandAlone).Count
                $Message = "Found " + $Count + " Stand-Alone VM Host(s)"

                $ManagedComputerStandAlone.AddRange(
                    [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$vmHostStandAlone.ManagedComputer
                )
            }
            Else
            {
                $Message = "There are no Stand-Alone VM Host(s) in specified Host Group(s)"
            }
            Write-Verbose -Message $Message

          # Only Clustered VM Hosts in specified Host Groups

            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]$vmHostClusterNode =
                $vmHost | Where-Object -FilterScript {
                    $psItem.HostCluster
                }

            If
            (
                $vmHostClusterNode
            )
            {
                $Count = $vmHostClusterNode.Count
                $Message = "Found " + $Count + " VM Host Cluster Node(s)"
                Write-Verbose -Message $Message

              # VM Host Cluster object for all of the Cluster Nodes we found.
              # Obtain the VM Host Cluster object for each of the VM Host objects.

              # There might be multiple Nodes within given Cluster.
              # While we obtain the Cluster object for every given Cluster Node,
              # We probably have counted some of the Cluster objects more than once.
              # However, we need each of the Cluster objects only once.

                [System.Collections.Generic.List[Microsoft.FailoverClusters.PowerShell.Cluster]]$ClusterHost =                    
                    $vmHostClusterNode.HostCluster.Name | ForEach-Object -Process {                                        
                        Get-Cluster -Name $psItem
                    } | Sort-Object -Unique

                $Count = $ClusterHost.Count
                $Message = "Will be processing " + $Count + " VM Host Cluster(s)"

                $Cluster.AddRange( $ClusterHost )
            }
            Else
            {
                $Message = 'There are no VM Host Cluster Node(s) in specified Host Group(s)'
            }
            Write-Verbose -Message $Message
        }
        Else
        {
            $Message = 'No Host Groups were specified'
            Write-Verbose -Message $Message
        }

      # Total number of Stand-alone computers, both Infrastructure and VM Host

        If
        (
            $ManagedComputerStandAlone
        )
        {  
            $Count = $ManagedComputerStandAlone.Count
            $Message = "Will be processing " + $Count + " Stand-alone server(s)"
        }
        Else
        {
            $Message = "There are no Stand-alone server(s)"
        }
        Write-Verbose -Message $Message

      # Total number Managed Computers (Infrastrucutre, Hyper-V hosts,
      # Stand-alone and clustered) in scope

        If
        (
            $ManagedComputerAll
        )
        {  
            $Count = $ManagedComputerAll.Count
            $Message = "Will be processing totally " + $Count + " server(s)"
        }
        Else
        {
            $Message = "There are no server(s) to proceed"
        }
        Write-Verbose -Message $Message
    }

  # Scan or Remediate

    Process
    {
        $ComplianceStatusParam = @{

            Mode             = $Mode
            TaskName         = "$Mode Servers"
            ThrottleLimit    = $ThrottleLimit
            Retry            = $Retry
        }

        If
        (
           $OpsMgrConnection
        )
        {
            $ComplianceStatusParam.Add(
                'OpsMgrConnection', $OpsMgrConnection
            )
        }

        Switch
        (
            $Mode
        )
        {
            'Scan'
            {
              # This is a non-disruptive operation, so process all managed
              # computers—both clustered and non-clustered
                $ComplianceStatusParam.Add(
                    'ManagedComputer', $ManagedComputerAll
                )
            }

            'Remediate'
            {
            # Update Remediation for Stand-Alone Managed Computers. This includes
            # Non-Clustered Hyper-V Hosts as well as Infrastructure Servers

                $ComplianceStatusParam.Add(
                    'ManagedComputer', $ManagedComputerStandAlone
                )
            }
        }

        $ComplianceStatus.AddRange(
            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]](
                Start-scComplianceStatusEx @ComplianceStatusParam
            )
        )

        If
        (
            $Mode -eq 'Remediate'
        )
        {
            $ComplianceStatusParam = @{

                Mode      = $Mode
                Cluster   = $Cluster
                vmmServer = $vmmServer
            }

            If
            (
                $OpsMgrConnection
            )
            {
                $ComplianceStatusParam.Add(
                    'OpsMgrConnection', $OpsMgrConnection
                )
            }

            $ComplianceStatus.AddRange(
                [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]](
                    Start-scComplianceStatusCluster @ComplianceStatusParam
                )
            )
        }
    }

    End
    {
        Return $ComplianceStatus
    }
}