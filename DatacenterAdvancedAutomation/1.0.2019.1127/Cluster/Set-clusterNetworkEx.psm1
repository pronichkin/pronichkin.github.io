<#
    define network settings on cluster
#>

Set-StrictMode -Version 'Latest'

Function
Set-clusterNetworkEx
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
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $LiveMigrationMaximum        = 2
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $LiveStorageMigrationMaximum = 2
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $LiveMigrationBandwidthLimit = 1gb
 <# ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        $ClusterNetworkParam    #>
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        $SiteProperty
    )

    Begin
    {
        $Message = "  Entering Set-ClusterNetworkEx for $Cluster"
        Write-Debug -Message $Message

        $vmHostAll        = @()
        $vmHostClusterAll = @()
        $ClusterAll       = @()

        $ClusterType = $Cluster.GetType().FullName
    }

    Process
    {
        $Cluster | ForEach-Object -Process {

            $ClusterCurrent = $psItem

           #region Set Live Migration maximums using VMM cmdlets (if available)

                Switch
                (
                    $ClusterType
                )
                {
                    'Microsoft.FailoverClusters.PowerShell.Cluster'
                    {
        
                      # We're *not* going to define Live Migration settings
                      # using native Hyper-V Management tools.
                      # This state is transistent (while VMM is not deployed yet)
                      # Thus, not all networks are properly defined yet.

                        $ClusterName    = $ClusterCurrent.Name
                        $ClusterAddress = Resolve-DnsNameEx -Name $ClusterName        
                    }

                    'Microsoft.SystemCenter.VirtualMachineManager.HostCluster'
                    {
                        $ClusterAddress = $ClusterCurrent.Name
                        
                        $vmHostClusterAll += Read-scvmHostCluster -vmHostCluster $Cluster

                        $Cluster.Nodes | Sort-Object -Property 'Name' | ForEach-Object -Process {
    
                            $NodeCurrent = $psItem

                            Write-Verbose -Message "Setting Live Migration parameters for $NodeCurrent"

                            $SetscvmHostParam = @{

                                vmHost                      = $NodeCurrent
                                LiveMigrationMaximum        = $LiveMigrationMaximum
                                LiveStorageMigrationMaximum = $LiveStorageMigrationMaximum
                                MigrationAuthProtocol       = "Kerberos"
                                MigrationPerformanceOption  = "UseSmbTransport"
                                UseAnyMigrationSubnet       = $False 
                            }
                            $NodeCurrent = Set-scvmHost @SetscvmHostParam

                            $Session = New-cimSessionEx -Name $NodeCurrent.Name

                            $BandwidthLimitParam = @{                            
                                
                                Category       = 'LiveMigration'
                                BytesPerSecond = $LiveMigrationBandwidthLimit
                                CimSession     = $Session
                            }
                            Set-SmbBandwidthLimit @BandwidthLimitParam
                        }
                    }

                    'Microsoft.SystemCenter.VirtualMachineManager.StorageFileServer'
                    {

                      # There's nothing to configure here.
                      # Storage File Server does not have Live Migration settings.

                        $ClusterAddress = $ClusterCurrent.StorageProvider.name
                    }
                }

           #endregion Set Live Migration maximums using VMM cmdlets (if available)

           #region Rename Networks
  
                $SiteProperty | ForEach-Object -Process {

                    $SitePropertyCurrent = $psItem

                    $SitePropertyCurrent.ClusterNetworkParam | ForEach-Object -Process {

                        $ClusterNetworkParamCurrent = $psItem

                        $ClusterNetwork = Get-ClusterNetwork -Cluster $ClusterAddress | 
                            Where-Object -FilterScript {
                                $psItem.Address -in $ClusterNetworkParamCurrent.Subnet
                            }

                        $ClusterNetworkName = $ClusterNetworkParamCurrent.Name + ' — ' + $SitePropertyCurrent.Name

                        If
                        (
                            (
                                $ClusterNetwork
                            ) -and
                            (
                                $ClusterNetwork.Name -ne $ClusterNetworkName
                            )
                        )

                      # The network was found and has different name.
                        {
                            $ClusterNetwork.Name = $ClusterNetworkName
                        }
                    }
                }

           #endregion Rename Networks

           #region Cluster Resource to configure Live Migration setting

                $GetClusterResourceTypeParam = @{

                    Name    = "Virtual Machine"
                    Cluster = $ClusterAddress
                }
                $ResourceType = Get-ClusterResourceType @GetClusterResourceTypeParam
  
           #endregion Cluster Resource to configure Live Migration setting

           #region Calculate “Migration Exclude Network” Parameter

              # There might be no “Migration Exclude Network”
              # if the cluster is not designated for Hyper-V

                $MigrationExcludeNetwork = [System.String]::Empty

                $MigrationExcludeNetworkParam = $SiteProperty.ClusterNetworkParam | 
                    Where-Object -FilterScript {
                        $psItem[ 'Disable' ]
                    }

                If
                (
                    $MigrationExcludeNetworkParam
                )
                {
                    $MigrationExcludeNetworkParam.Name | Sort-Object -Unique | ForEach-Object -Process {
    
                        $MigrationExcludeNetworkName = $psItem

                      # Get Cluster Network

                      # $ClusterNetwork = $Null

                        $ClusterNetwork = Get-ClusterNetwork -Cluster $ClusterAddress |
                            Where-Object -FilterScript {
                                $psItem.Name -like "$MigrationExcludeNetworkName*"
                            }

                      # Get Cluster Network ID

                        If
                        (
                            $ClusterNetwork
                        )
                        {
                            $ClusterNetwork | ForEach-Object -Process {

                                $ClusterNetworkID = $psItem.ID

                                Write-Verbose -Message "Exclude this network from Live Migration and Cluster usage: $($psItem.Name)"

                                $MigrationExcludeNetwork =
                                    $MigrationExcludeNetwork,$ClusterNetworkID -Join ";"

                                If
                                (    
                                    $psItem.Role -eq 1
                                )
                                {
                                    $psItem.Role = 0
                                }
                            }
                        }
                        Else
                        {
                            $Message = "    Network `“$MigrationExcludeNetworkName`” is specified to exclude from Live Migration, but it was not found in this cluster"
                            Write-Debug -Message $Message
                        }
                    }

                    $Message = 'Setting “Migration Exclude Networks”'
                    Write-Verbose -Message $Message

                    $SetClusterParameterParam = @{

                        Name        = 'MigrationExcludeNetworks'
                        Value       = $MigrationExcludeNetwork
                      # Multiple    = $Multiple
                        InputObject = $ResourceType 
                    }
                    Set-ClusterParameter @SetClusterParameterParam
                }
                Else
                {
                    $Message = '    There are no network(s) specified to exclude from Live Migration'
                    Write-Debug -Message $Message
                }

           #endregion Calculate “Migration Exclude Networks” Parameter

           #region Calculate “Migration Network Order” Parameter

              # There might be no “Migration Network Order”
              # if the cluster is not designated for Hyper-V

                $MigrationNetworkOrder = [System.String]::Empty

                $MigrationNetworkOrderParam = $SiteProperty.ClusterNetworkParam |
                    Where-Object -FilterScript {
                        -Not $psItem[ 'Disable' ]
                    }

                If
                (
                    $MigrationNetworkOrderParam
                )
                {
                    $MigrationNetworkOrderParam.Name | Sort-Object -Unique | ForEach-Object -Process {
    
                        $MigrationNetworkOrderName = $psItem
    
                      # Get Cluster Network

                      # $ClusterNetwork = $Null

                        $ClusterNetwork = Get-ClusterNetwork -Cluster $ClusterAddress |
                            Where-Object -FilterScript {
                                $psItem.Name -like "$MigrationNetworkOrderName*"
                            }

                      # Get Cluster Network ID

                        If
                        (
                            $ClusterNetwork
                        )
                        {
                            $ClusterNetwork | ForEach-Object -Process {

                                $ClusterNetworkID = $psItem.ID

                                Write-Verbose -Message "Include this network to Live Migration: $($psItem.Name)"

                                $MigrationNetworkOrder = 
                                    $MigrationNetworkOrder,$ClusterNetworkID -Join ";"
                            }
                        }
                        Else
                        {
                            $Message = "    Network `“$MigrationNetworkOrderName`” is specified to include for Live Migration, but it was not found in this cluster"
                            Write-Debug -Message $Message
                        }
                    }

                    $Message = 'Setting “Migration Network Order”'
                    Write-Verbose -Message $Message

                    $SetClusterParameterParam = @{

                        Name        = 'MigrationNetworkOrder'
                        Value       = $MigrationNetworkOrder
                      # Multiple    = $Multiple
                        InputObject = $ResourceType 
                    }
                    Set-ClusterParameter @SetClusterParameterParam
                }
                Else
                {
                    $Message = '    There are no network(s) specified to include for Live Migration'
                    Write-Debug -Message $Message
                }

           #endregion Calculate “Migration Network Order” Parameter

           #region Get Resource Type and set its properties

             <# Hash Table for Set Cluster Parameters

                $Multiple = @{}  #>

             <# $Multiple.Add(

                        "MigrationExcludeNetworks",
                        $MigrationExcludeNetwork
                )  #>

             <# $Multiple.Add(

                    "MigrationNetworkOrder",
                    $MigrationNetworkOrder
                )  #>

             <# Write-Verbose -Message "Live Migration Settings:"

                $Multiple.GetEnumerator() | ForEach-Object -Process {

                    Write-Verbose -Message "Key:   $($psItem.Key)"
                    Write-Verbose -Message "Value: $($psItem.Value)"
                } #>

             <# Set Cluster Parameter for This Resource Type

                $SetClusterParameterParam = @{

                    Multiple    = $Multiple
                    InputObject = $ResourceType 
                }
                Set-ClusterParameter @SetClusterParameterParam  #>

           #endregion Get Resource Type and set its properties

          <#region Disable networks for Cluster use

                If
                (
                    $MigrationExcludeNetworkParam
                )
                {
                    $MigrationExcludeNetworkParam.Name | Sort-Object -Unique | ForEach-Object -Process {

                        $MigrationExcludeNetworkName = $psItem

                        $ClusterNetwork = $Null

                        $ClusterNetwork = Get-ClusterNetwork -Cluster $ClusterAddress |
                            Where-Object -FilterScript {
                                $psItem.Name -like "$MigrationExcludeNetworkName*"
                            }
        
                        If
                        (
                            (
                                $ClusterNetwork
                            ) -and
                            (    
                                $ClusterNetwork.Role -eq 1
                            )
                        )
                        {
                            $ClusterNetwork.Role = 0
                        }
                    }
                }

           #endregion Disable networks for Cluster use  #>

           #region Set explicit Metric for CSV Network

                $CsvNetworkParam = $SiteProperty.ClusterNetworkParam | Where-Object -FilterScript {
                    $psItem[ 'CsvDefault' ]
                }

              # $ClusterNetwork = $Null

                If
                (
                    $CsvNetworkParam
                )
                {
                    $CsvNetworkParam.Name | Sort-Object -Unique | ForEach-Object -Process {

                        $CsvNetworkName = $psItem

                        $ClusterNetwork = Get-ClusterNetwork -Cluster $ClusterAddress |
                            Where-Object -FilterScript {
                                $psItem.Name -like "$CsvNetworkName*"
                            }

                        If
                        (
                            $ClusterNetwork
                        )
                        {
                            $ClusterNetwork | ForEach-Object -Process {

                                $Message = "    Setting network `“$psItem`” as default for CSV redirection traffic"
                                Write-Debug -Message $Message

                                $psItem.Metric = 900
                            }
                        }
                        Else
                        {
                            $Message = '    Network `“$CsvNetworkName`” is specified as default for CSV redirection traffic, but it was not found in this cluster'
                            Write-Debug -Message $Message
                        }
                    }
                }
                Else
                {
                    $Message = '    There are no network(s) specified as default for CSV redirection traffic'
                    Write-Verbose -Message $Message
                }

           #endregion Set explicit Metric for CSV Network

        }
    }
    
    End
    {
        $Message = "  Exiting Set-ClusterNetworkEx for $Cluster"
        Write-Debug -Message $Message

      # Return $vmHostClusterAll, $ClusterAll
    }
}