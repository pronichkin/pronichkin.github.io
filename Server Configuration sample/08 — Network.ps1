    #region Data

    $Subnet = [System.Collections.Generic.List[System.Net.ipAddress]]::new()
    $Subnet.Add( '192.168.0.0' )
    $Subnet.Add( '192.168.0.4' )
    $Subnet.Add( '192.168.0.8' )

    $PrefixLength = 30

#endregion Data

#region Inventory and cleanup

    $Assign  = [System.Collections.Generic.List[Microsoft.Management.Infrastructure.cimInstance]]::new()

    $netAdapter = Get-NetAdapter -cimSession $cimSession -Physical | Where-Object -FilterScript {
        $psItem.DriverDescription -eq 'Thunderbolt(TM) Networking'
    } | Enable-NetAdapter -PassThru

  # Clean up to start fresh

    Get-vmSwitch -CimSession $cimSession | Where-Object -FilterScript {
    
        $NetAdapterInterfaceGuid = $psItem.NetAdapterInterfaceGuid
    
        $Test = $netAdapter.InterfaceGuid | ForEach-Object -Process {

            [System.Guid]$psItem -in $NetAdapterInterfaceGuid
        }

        $True -in $Test
    } | Remove-vmSwitch -Force

  # Get-netIpAddress -cimSession $cimSession -InterfaceAlias $netAdapter.Name -AddressFamily IPv4 -Debug:$False | Where-Object -FilterScript {
    Get-netIpAddress -cimSession $cimSession -AddressFamily IPv4 -Debug:$False | Where-Object -FilterScript {
      # $psItem.PrefixOrigin -eq 'WellKnown' -and $psItem.SuffixOrigin -eq 'Link'
        $psItem.InterfaceAlias -in $netAdapter.Name -and
        $psItem.PrefixOrigin -eq 'Manual'           -and
        $psItem.SuffixOrigin -eq 'Manual'
    } | Remove-netIpAddress -Debug:$False -Confirm:$False

#endregion Inventory and cleanup

#region IP Address

  # Loop through all existing adapters

    $netAdapter | Sort-Object -Property @( 'psComputerName', 'MacAddress' ) | ForEach-Object -Process {

        $netAdapterCurrent = $psItem
        $cimSessionCurrent = $cimSession | Where-Object -FilterScript { $psItem.InstanceId   -eq $netAdapterCurrent.GetCimSessionInstanceId() }
        $psSessionCurrent  = $psSession  | Where-Object -FilterScript { $psItem.ComputerName -eq $cimSessionCurrent.ComputerName }

        $Message = "Processing adapter `“$($netAdapterCurrent.Name)`” on $($psSessionCurrent.ComputerName)"
        Write-Verbose -Message $Message

      # Select the pool which is not yet used on any of existing IP addresses on this machine

        $SubnetUnique = $Subnet | Where-Object -FilterScript {

            $SubnetCurrent    = $psItem

            $ipAddressCurrent = Get-netIpAddress -Debug:$False -cimSession $cimSessionCurrent -AddressFamily IPv4 | Where-Object -FilterScript {
              # $psItem.PrefixOrigin -eq 'WellKnown' -and $psItem.SuffixOrigin -eq 'Link'
                $psItem.PrefixOrigin -eq 'Manual'    -and $psItem.SuffixOrigin -eq 'Manual'
            }
        
       -Not (        
                $ipAddressCurrent | Where-Object -FilterScript {

                    $SubnetCurrent = Get-netIpSubnet -ipAddress $SubnetCurrent -PrefixLength $psItem.PrefixLength

                    Test-netIpAddress -ipAddress $psItem.IPv4Address -PrefixLength $psItem.PrefixLength -Subnet $SubnetCurrent
                }
            )
        }

      # Select the right IP address

        $Test = $False

        While
        (
            $Test -eq $False
        )
        {
          # Select the first suitable subnet

            If
            (
                $SubnetUnique
            )
            {
                $SubnetCurrentMark   = $SubnetUnique | Select-Object -First 1
                $SubnetCurrent       = Get-netIpSubnet -ipAddress $SubnetCurrentMark -PrefixLength $PrefixLength
                $SubnetCurrentInt    = ConvertFrom-netIpAddress -ipAddress $SubnetCurrent
                $SubnetBroadcast     = Get-netIpSubnetBroadcastAddress -ipAddress $SubnetCurrent -PrefixLength $PrefixLength

                $Message = "  Testing subnet  $SubnetCurrent"
                Write-Verbose -Message $Message

                $Index = $Subnet.IndexOf( $SubnetCurrentMark )

              # Increment the current subnet address to get the next IP address

                $ipAddressCurrent = [System.Net.ipAddress]::Parse( ( ConvertFrom-netIpAddress -ipAddress $SubnetCurrentMark ) + 1 )
        
                If
                (
                    $ipAddressCurrent -eq $SubnetBroadcast
                )
                {
                    $Message = "Subnet is exhausted, skipping"
                    Write-Verbose -Message $Message
                       
                    $Test = $False
                }
                Else
                {
                    $Message = "  Testing address $ipAddressCurrent"
                    Write-Verbose -Message $Message
        
                    $AssignCurrent = New-netIpAddress -cimSession $cimSessionCurrent -ifAlias $netAdapterCurrent.Name -ipAddress $ipAddressCurrent.ipAddressToString -PrefixLength $PrefixLength -Debug:$False | Where-Object -FilterScript {
        
                        $psItem.Store -eq [Microsoft.PowerShell.Cmdletization.GeneratedTypes.netIpAddress.Store]::ActiveStore
                    }

                    While
                    (
                        $AssignCurrent.AddressState -ne [Microsoft.PowerShell.Cmdletization.GeneratedTypes.netIpAddress.AddressState]::Preferred
                    )
                    {
                        $AssignCurrent = Get-netIpAddress -cimSession $cimSessionCurrent -ifAlias $netAdapterCurrent.Name -ipAddress $ipAddressCurrent.ipAddressToString -Debug:$False

                        $Message = '      Waiting for the address to come online'
                        Write-Debug -Message $Message
                        Start-Sleep -Seconds 3
                    }

                    $ipAddressCurrentInt = ConvertFrom-netIpAddress -ipAddress $ipAddressCurrent

                    If
                    (
                        $ipAddressCurrentInt -eq $SubnetCurrentInt + 1
                    )
                    {
                      # This is the first IP address in subnet, so do not perform connectivity test

                        $Test = $True
                    }
                    Else
                    {
                        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {
            
                            Test-NetConnection -ComputerName $using:SubnetCurrentMark -WarningAction SilentlyContinue
                        }

                        $Test = $Command.PingSucceeded
                    }

                    If
                    (
                        $Test
                    )
                    {
                        Write-Verbose -Message 'Success'
                    }
                    Else
                    {
                        Write-Verbose -Message 'Fail, trying next subnet'

                        [System.Void](
                            Remove-netIpAddress -cimSession $cimSessionCurrent -ifAlias $netAdapterCurrent.Name -ipAddress $ipAddressCurrent.ipAddressToString -Confirm:$False -Debug:$False
                        )
                    }
                }

                If
                (
                    $Test
                )
                {
                    $Assign.Add( $AssignCurrent )
                }
                Else
                {
                  # Iterate through the list of suitable subnets so that the next one is tried on the next loop

                    $SubnetUnique = $SubnetUnique | Where-Object -FilterScript { $psItem -ne $SubnetCurrentMark }
                }
            }
            Else
            {
                $Message = 'There are no more subnets. Process will fail'
                Throw $Message
            }
        }

        $Subnet[ $Index ] = $ipAddressCurrent
    }

#endregion IP Address

#region NIC name

  # Rename

    $netAdapter = [System.Collections.Generic.List[Microsoft.Management.Infrastructure.cimInstance]]::new()

    $Service = Get-Service -ComputerName $cimSessionCurrent.ComputerName -DisplayName 'Cluster Service'

    If
    (
        $Service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running
    )
    {
        $Cluster        = Get-Cluster -Name $cimSessionCurrent.ComputerName
        $ClusterNetwork = Get-ClusterNetwork -InputObject $Cluster
    }
    Else
    {
        $Message = 'Cluster service is not running, will not obtain cluster and skip cluster network rename'
        Write-Verbose -Message $Message
    }

    $Assign | ForEach-Object -Process {

        $AssignCurrent     = $psItem
        $NetIPInterface    = Get-CimAssociatedInstance -InputObject $AssignCurrent  -ResultClassName 'MSFT_NetIPInterface' -Verbose:$False
        $netAdapterCurrent = Get-CimAssociatedInstance -InputObject $NetIPInterface -ResultClassName 'MSFT_NetAdapter'     -Verbose:$False
        $cimSessionCurrent = $cimSession | Where-Object -FilterScript { $psItem.InstanceId -eq $netAdapterCurrent.GetCimSessionInstanceId() }

        $Subnet = Get-netIpSubnet -ipAddress $AssignCurrent.ipAddress -PrefixLength $AssignCurrent.PrefixLength

        $AssignPeer = $Assign | Where-Object -FilterScript {

            Test-netIpAddress -ipAddress $psItem.ipAddress -PrefixLength $psItem.PrefixLength -Subnet $Subnet
        }

        $AssignName = $AssignPeer | ForEach-Object -Process { $psItem.psComputerName.Split( '.' )[0] } | Sort-Object
    
        $Name = $AssignName -join ' — '

        $netAdapter.Add( ( Rename-NetAdapter -InputObject $netAdapterCurrent -NewName $Name -PassThru -Debug:$False -cimSession $cimSessionCurrent ) )

        If
        (
            $Service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running
        )
        {
            $ClusterNetworkCurrent = $ClusterNetwork | Where-Object -FilterScript { $Subnet.ipAddressToString -in $psItem.Ipv4Addresses }

            If
            (
                $ClusterNetworkCurrent.Name -eq $Name
            )
            {
              # Skip rename
            }
            Else
            {
                $ClusterNetworkCurrent.Name  =  $Name
            }
        }
    }

#endregion NIC name