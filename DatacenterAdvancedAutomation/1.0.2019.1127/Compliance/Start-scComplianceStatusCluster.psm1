Set-StrictMode -Version 'Latest'

Function
Start-scComplianceStatusCluster
{
    [cmdletBinding()]

    Param(

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
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[Microsoft.FailoverClusters.PowerShell.Cluster]]
            $Cluster
        ,
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
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int64]
            $ThrottleLimit = 10
    )

    Process
    {
        $Current  = 1

        $TaskName = "$Mode Cluster(s)"
        Write-Verbose -Message $TaskName

        $Total    = $Cluster.Count

        $ComplianceStatus = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]]::new()

        $Cluster | Sort-Object -Property 'Name' | ForEach-Object -Process {

            $ClusterCurrent = $psItem
            $ClusterCurrentAddress = Resolve-dnsNameEx -Name $ClusterCurrent.Name

            $Message = "  $( ( Get-Date -DisplayHint Time ).DateTime )  $ClusterCurrentAddress"
            Write-Debug -Message $Message

            $ProgressRatio    = ( $Current-1 ) / $Total
            $ProgressPercent  = $ProgressRatio * 100
            $MessageStatus    = "Cluster " + $Current + " of " + $Total

            $ProgressParam = @{

                Activity         = $TaskName
                CurrentOperation = $Message
                PercentComplete  = $ProgressPercent
                Status           = $MessageStatus
            }
            Write-Progress @ProgressParam

            Switch
            (
                $Mode
            )
            {
                'Scan'
                {
                    $Message = "  Checking compliance of the $ClusterCurrentAddress with VMM"
                  # Write-Verbose -Message $Message

                    $HostCluster = Get-scvmHostCluster -vmmServer $vmmServer | 
                        Where-Object -FilterScript {
                            $psItem.Name -eq $ClusterCurrentAddress
                        }
                    
                    If
                    (
                        $HostCluster
                    )
                    {
                        If
                        (
                            $HostCluster.Nodes[0].ManagedComputer.ComplianceStatus
                        )
                        {
                            $ProcedureParam = @{

                                vmmServer          = $vmmServer
                                vmHostCluster      = $HostCluster
                            }

                            $ComplianceStatus.AddRange(
                                [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]](
                                  # Start-scComplianceStatusEx @ComplianceStatusParam
                                    ( Start-scComplianceScan @ProcedureParam ).Nodes.ManagedComputer.ComplianceStatus
                                )
                            )

                          # [System.Void]( Start-scComplianceScan @ProcedureParam )
                        }
                        Else
                        {
                             $Message = '    There''s no Baseline(s) attached to the specified Managed Computer(s)'
                             Write-Verbose -Message $Message
                        }
                    }
                    Else
                    {
                        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.vmmManagedComputer]]$ManagedComputer =
                            Resolve-DnsNameEx -Name (
                                Get-ClusterNode -InputObject $ClusterCurrent
                            ).Name | ForEach-Object -Process {

                                $ManagedComputerParam = @{                                
                                    vmmServer    = $vmmServer
                                    ComputerName = $psItem
                                }
                                Get-scvmmManagedComputer @ManagedComputerParam
                            }

                        $ComplianceStatusParam = @{

                            Mode             = $Mode
                            TaskName         = "$Mode $ClusterCurrentAddress"
                            ManagedComputer  = $ManagedComputer
                            ThrottleLimit    = $ThrottleLimit
                            Force            = $True
                        }

                     <# If
                        (
                            Test-Path -Path 'Variable:\OpsMgrConnection'
                        )
                        {
                            $ComplianceStatusParam.Add( 'OpsMgrConnection', $OpsMgrConnection )
                        }  #>

                        $ComplianceStatus.AddRange(
                            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]](
                                Start-scComplianceStatusEx @ComplianceStatusParam
                            )
                        )

                      # This is a special case where the clustered Library server is
                      # seen in VMM compliance dashboard as a separate Management
                      # computer instance. Because it's actually hosted by one of the
                      # cluster nodes, it has to be scanned separately.

                        $Name = @( 
                            Get-ClusterGroup -InputObject $ClusterCurrent |
                                Where-Object -FilterScript {
                                    $psItem.GroupType -eq 'FileServer'
                                } | ForEach-Object -Process {
                                    Resolve-dnsNameEx -Name $psItem.Name
                                }
                            )

                        Get-scvmmManagedComputer -vmmServer $vmmServer | Where-Object -FilterScript {                        
                            $psItem.FullyQualifiedDomainName -in $Name
                        } | ForEach-Object -Process {
                         
                            $ComplianceStatusParam = @{
                            
                                Mode             = $Mode
                                TaskName         = "$Mode $Name (Library server VCO)"
                                ManagedComputer  = $psItem
                                Force            = $True
                            }
                            $ComplianceStatus.Add(
                                $( Start-scComplianceStatusEx @ComplianceStatusParam )
                            )
                        }
                    }
                }

                'Remediate'
                {
                    If
                    (
                        $OpsMgrConnection
                    )
                    {
                        $MaintenanceModeParam = @{

                          # Unlike almost everywhere else, we need to use
                          # the flat name of the cluster here because this
                          # is how OpsMgr names objects

                            Name       = $ClusterCurrent.Name
                            Hour       =  16  # Normally would take about 8 hours on a 13-node host cluster running Windows Server 2016
                            Comment    = 'Installing updates'
                            Connection = $OpsMgrConnection
                        }
                        $MaintenanceMode =
                            Start-scomMaintenanceModeEx @MaintenanceModeParam
                    }

                  # We need to create a special “PowerShell Session 
                  # Configuration” (aka “Endpoint”) for CAU because it will 
                  # have the network path to shared modules directory added to
                  # “PS Module Path” environmental variable.
                    
                    $ConfigurationName = 'microsoft.dcaa.cau'
                    $Node              = Get-clusterNode -InputObject $ClusterCurrent
                    $NodeAddress       = Resolve-dnsNameEx -Name $Node.Name
                    $Session           = New-psSession -ComputerName $NodeAddress

                    $SessionParam = @{
                    
                        Name    = $ConfigurationName
                        Session = $Session
                      # Force   = $True
                    }
                    [System.Void]( Register-psSessionConfigurationEx @SessionParam )

                  # Prepare parameters for CAU

                    $CauPluginArgument = @{

                        IncludeRecommendedUpdates = 'True'
                        QueryString               = 'IsInstalled = 0 and IsHidden = 0'
                    }

                    $Message = "$( ( Get-Date -DisplayHint 'Time' ).DateTime )  Starting update remediation of $ClusterCurrentAddress using Cluster-Aware Updating (CAU)"
                    
                    Write-Verbose -Message $Message
                    Write-Verbose -Message ( [System.String]::Empty )
                    Write-Verbose -Message "***"
                    Write-Verbose -Message ( [System.String]::Empty )                    

                  # Apparently CAU cannot pass parameters to Pre- and Post-update scripts

                  # $Directory      = Get-Item -Path ( Split-Path -Path $myInvocation.myCommand.Path -Parent )
                  # $Directory      = Get-Item -Path ( Split-Path -Path $PSCommandPath -Parent )
                  # $TranscriptPath = Join-Path -Path $Directory.Parent.FullName -ChildPath 'Transcripts CAU'

                    $CauRunParam = @{

                        ClusterName           = $ClusterCurrentAddress
                        EnableFirewallRules   = $True
                        FailbackMode          = 'Policy'
                        RequireAllNodesOnline = $True
                        CauPluginArguments    = $CauPluginArgument

                      # Pre- and post-update scritps do not take parameters

                        PreUpdateScript       = "$psScriptRoot\Suspend-ClusterNodeEx.ps1"  # -Transcript ""$TranscriptPath"""
                        PostUpdateScript      = "$psScriptRoot\Resume-ClusterNodeEx.ps1"   # -Transcript ""$TranscriptPath"""
                        ConfigurationName     = $ConfigurationName
                      # MaxRetriesPerNode     =  8
                        Force                 = $True
                    }
                    [System.Void]( Invoke-CauRun @CauRunParam )
                    
                    $Message = "$( ( Get-Date -DisplayHint 'Time' ).DateTime )  Cluster-Aware Updating (CAU) for $ClusterCurrentAddress finished"
                                    
                    Write-Verbose -Message ( [System.String]::Empty )
                    Write-Verbose -Message "***"
                    Write-Verbose -Message ( [System.String]::Empty )
                    Write-Verbose -Message $Message

                    If
                    (
                        $OpsMgrConnection
                    )
                    {
                        $MaintenanceModeParam = @{

                            MaintenanceMode = $MaintenanceMode
                            Comment         = 'Installing updates done'
                            Connection      = $OpsMgrConnection
                        }
                        [System.Void](
                            Stop-scomMaintenanceModeEx @MaintenanceModeParam
                        )
                    }

                  # We need to invoke compliance scan with VMM anyway, regardless of the
                  # mode. For “Scan” mode, this is the only action taken. For “Remediate
                  # mode, this is still necessary to correctly reflect the result of
                  # operation in VMM dashboard.

                    $ComplianceStatusParam = @{
                    
                        Mode      = 'Scan'
                        Cluster   = $ClusterCurrent
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

                  # $Current = $Current -1

                    $ComplianceStatus.AddRange(
                        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.ComplianceStatus]](
                            Start-scComplianceStatusCluster @ComplianceStatusParam
                        )
                    )
                }
            }

            $Current++
        }

        $Message = "  $( ( Get-Date -DisplayHint Time ).DateTime )  Done"
        Write-Debug -Message $Message

        $ProgressRatio    = ( $Current-1 ) / $Total
        $ProgressPercent  = $ProgressRatio * 100
        $MessageStatus    = "Cluster " + $Current + " of " + $Total

        $ProgressParam = @{

            Activity         = $TaskName
            CurrentOperation = $Message
            PercentComplete  = $ProgressPercent
            Status           = $MessageStatus
        }
        Write-Progress @ProgressParam

        Return $ComplianceStatus
    }    
}