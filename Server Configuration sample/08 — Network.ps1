$Subnet = [System.Collections.Generic.List[System.Net.IPAddress]]::new()
$Subnet.Add( '192.168.0.0' )
$Subnet.Add( '192.168.0.4' )
$Subnet.Add( '192.168.0.8' )

$PrefixLength = 30

$Assign  = [System.Collections.Generic.List[Microsoft.Management.Infrastructure.CimInstance]]::new()

$netAdapter = Get-NetAdapter -CimSession $cimSession -Physical | Where-Object -FilterScript {
    $psItem.DriverDescription -eq 'Thunderbolt(TM) Networking'
}

# Clean up to start fresh

Get-NetIPAddress -CimSession $cimSession -InterfaceAlias $netAdapter.Name -AddressFamily IPv4 -Debug:$False | Where-Object -FilterScript {
  # $psItem.PrefixOrigin -eq 'WellKnown' -and $psItem.SuffixOrigin -eq 'Link'
    $psItem.PrefixOrigin -eq 'Manual'    -and $psItem.SuffixOrigin -eq 'Manual'
} | Remove-NetIPAddress -Debug:$False -Confirm:$False

# Loop through all existing adapters

$netAdapter | Sort-Object -Property @( 'psComputerName', 'MacAddress' ) | ForEach-Object -Process {

    $netAdapterCurrent = $psItem
    $cimSessionCurrent = $cimSession | Where-Object -FilterScript { $psItem.InstanceId -eq $netAdapterCurrent.GetCimSessionInstanceId() }
    $psSessionCurrent  = $psSession  | Where-Object -FilterScript { $psItem.ComputerName -eq $cimSessionCurrent.ComputerName }

    $Message = "Processing adapter `“$($netAdapterCurrent.Name)`” on $($psSessionCurrent.ComputerName)"
    Write-Verbose -Message $Message

  # Select the pool which is not yet used on any of existing IP addresses on this machine

    $SubnetUnique = $Subnet | Where-Object -FilterScript {

        $SubnetCurrent    = $psItem

        $ipAddressCurrent = Get-NetIPAddress -Debug:$False -CimSession $cimSessionCurrent -AddressFamily IPv4 | Where-Object -FilterScript {
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

        $SubnetCurrentMark   = $SubnetUnique | Select-Object -First 1
        $SubnetCurrent       = Get-netIpSubnet -ipAddress $SubnetCurrentMark -PrefixLength $PrefixLength
        $SubnetCurrentInt    = ConvertFrom-netIpAddress -ipAddress $SubnetCurrent
        $SubnetBroadcast     = Get-netIpSubnetBroadcastAddress -ipAddress $SubnetCurrent -PrefixLength $PrefixLength

        $Message = "  Testing subnet  $SubnetCurrent"
        Write-Verbose -Message $Message

        $Index = $Subnet.IndexOf( $SubnetCurrentMark )

      # Increment the current subnet address to get the next IP address

        $ipAddressCurrent = [System.Net.IPAddress]::Parse( ( ConvertFrom-netIpAddress -ipAddress $SubnetCurrentMark ) + 1 )
        
        If
        (
            $ipAddressCurrent -eq $SubnetBroadcast
        )
        {
            $Message = "Subnet is exhausted, skiping"
            Write-Verbose -Message $Message
                       
            $Test = $False
        }
        Else
        {
            $Message = "  Testing address $ipAddressCurrent"
            Write-Verbose -Message $Message
        
            $AssignCurrent = New-NetIPAddress -CimSession $cimSessionCurrent -ifAlias $netAdapterCurrent.Name -IPAddress $ipAddressCurrent.ipAddressToString -PrefixLength $PrefixLength -Debug:$False | Where-Object -FilterScript {
        
                $psItem.Store -eq [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetIPAddress.Store]::ActiveStore
            }

            While
            (
                $AssignCurrent.AddressState -ne [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetIPAddress.AddressState]::Preferred
            )
            {
                $AssignCurrent = Get-NetIPAddress -CimSession $cimSessionCurrent -ifAlias $netAdapterCurrent.Name -IPAddress $ipAddressCurrent.ipAddressToString -Debug:$False

                $Message = '      Waiting for the address to come online'
                Write-Debug -Message $Message
                Start-Sleep -Seconds 1
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
                    Remove-NetIPAddress -CimSession $cimSessionCurrent -ifAlias $netAdapterCurrent.Name -IPAddress $ipAddressCurrent.ipAddressToString -Confirm:$False -Debug:$False
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
          # Iterate throught the list of suitable subnets so that the next one is tried on the next loop

            $SubnetUnique = $SubnetUnique | Where-Object -FilterScript { $psItem -ne $SubnetCurrentMark }
        }
    }

    $Subnet[ $Index ] = $ipAddressCurrent
}

# Rename

$netAdapter = [System.Collections.Generic.List[Microsoft.Management.Infrastructure.CimInstance]]::new()

$Cluster        = Get-Cluster -Name $cimSessionCurrent.ComputerName
$ClusterNetwork = Get-ClusterNetwork -InputObject $Cluster

$Assign | ForEach-Object -Process {

    $AssignCurrent     = $psItem
    $NetIPInterface    = Get-CimAssociatedInstance -InputObject $AssignCurrent  -ResultClassName 'MSFT_NetIPInterface' -Verbose:$False
    $netAdapterCurrent = Get-CimAssociatedInstance -InputObject $NetIPInterface -ResultClassName 'MSFT_NetAdapter'     -Verbose:$False
    $cimSessionCurrent = $cimSession | Where-Object -FilterScript { $psItem.InstanceId -eq $netAdapterCurrent.GetCimSessionInstanceId() }

    $Subnet = Get-netIpSubnet -ipAddress $AssignCurrent.IPAddress -PrefixLength $AssignCurrent.PrefixLength

    $AssignPeer = $Assign | Where-Object -FilterScript {

        Test-netIpAddress -ipAddress $psItem.IPAddress -PrefixLength $psItem.PrefixLength -Subnet $Subnet
    }

    $AssignName = $AssignPeer | ForEach-Object -Process { $psItem.psComputerName.Split( '.' )[0] } | Sort-Object
    
    $Name = $AssignName -join ' — '

    $netAdapter.Add( ( Rename-NetAdapter -InputObject $netAdapterCurrent -NewName $Name -PassThru -Debug:$False -CimSession $cimSessionCurrent ) )

    $ClusterNetworkCurrent = $ClusterNetwork | Where-Object -FilterScript { $Subnet.IPAddressToString -in $psItem.Ipv4Addresses }

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