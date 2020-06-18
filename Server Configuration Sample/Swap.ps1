#region Data

 <# $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI_PROD1\17784.1004.200414-2230\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1004.amd64fre.rs5_release_svc_hci_prod1.200414-2230_server_serverazurestackhcicor_en-us.vhdx'

    $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI_PROD1\17763.1098.200409-1700\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17763.1098.amd64fre.rs5_release_svc_hci_prod1.200409-1700_server_serverazurestackhcicor_en-us.vhdx'  #>

    $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1048.200616-1043\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1048.amd64fre.rs5_release_svc_hci.200616-1043_server_serverazurestackhcicor_en-us.vhdx'

    $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1015.200511-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1015.amd64fre.rs5_release_svc_hci.200511-1900_server_serverazurestackhcicor_en-us.vhdx'

    $DomainName       = 'ntDev.corp.Microsoft.com'
    $Password         = 'P@ssw0rd.123'
  # $MemberName       = 'KeplerLabUser'
    $MemberName       = 'ArtemP'
  # $MemberDomainName = 'Redmond.corp.Microsoft.com'
    $MemberDomainName = 'ntDev.corp.Microsoft.com'

    $FeatureName = [System.Collections.Generic.Dictionary[
        System.String,
        System.Collections.Generic.List[
            System.String
        ]
    ]]::new()    

    $FeatureName.Add(
        
        'Enable', @(

            'Microsoft-Hyper-V-Offline'
            'Microsoft-Hyper-V-Online'
            'Microsoft-Hyper-V'
            'FailoverCluster-FullServer'
        )
    )

#endregion Data

#region Code

    $Source = Get-Item -Path $SourcePath

    $PasswordSalt   = $Password + 'OfflineAdministratorPassword'
    $PasswordByte   = [System.Text.Encoding]::Unicode.GetBytes( $PasswordSalt )
    $PasswordBase64 = [System.Convert]::ToBase64String( $PasswordByte )

    $Member   = [System.Security.Principal.NTAccount]::new( $MemberDomainName, $MemberName )
    $MemberId = $Member.Translate( [System.Security.Principal.SecurityIdentifier] )

$psSession | ForEach-Object -Process {

  # Filter Sessions

    $psSessionCurrent  = $psItem
    $AddressCurrent    = $psSessionCurrent.ComputerName
    $NameCurrent       = $AddressCurrent.Split( '.' )[0]

    $cimSessionCurrent = $cimSession | Where-Object -FilterScript {
        $psItem.ComputerName -eq $AddressCurrent
    }    

    $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Starting upgrade for `“$AddressCurrent`”"
    Write-Verbose -Message $Message

  # Check if the server already runs the target image

    $Disk = Get-Disk -CimSession $cimSessionCurrent | Where-Object -FilterScript {
        $psItem.IsBoot
    }

    If
    (
        $Disk.BusType -eq 'File Backed Virtual' -and
        ( Split-Path -Path $Disk.Location -Leaf ) -eq $Source.Name    
    )
    {
        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Server already runs the target image `“$($Source.BaseName)`”. Skipping"
        Write-Verbose -Message $Message
    }
    Else
    {
      # Check cluster membership and remove node if needed

        $Computer = Get-adComputer -Identity $NameCurrent -Properties 'servicePrincipalName'

        If
        (
            $Computer.servicePrincipalName | Where-Object -FilterScript {
                $psItem -like 'msServerClusterMgmtAPI/*'
            }
        )
        {
            $Service = Get-Service -ComputerName $AddressCurrent -Name 'clusSvc'

            If
            (
                $Service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running
            )
            {
                $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Removing cluster node"
                Write-Verbose -Message $Message

                $Cluster = Get-Cluster -Name $AddressCurrent
                $Node    = Get-ClusterNode -InputObject $Cluster -Name $NameCurrent

                $NodeParam = @{

                    InputObject                   = $Node
                    IgnoreStorageConnectivityLoss = $True
                    Force                         = $True
                    Verbose                       = $False
                }
                $Node    = Remove-ClusterNode @NodeParam
            }
            Else
            {
                $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Cluster service is stopped. Skipping cluster membership steps"
                Write-Verbose -Message $Message
            }
        }

      # Store Static IP Address information to be restored later

        $ipAddress = [System.Collections.Generic.Dictionary[
            System.Net.NetworkInformation.PhysicalAddress,
            Microsoft.Management.Infrastructure.CimInstance
        ]]::new()

        $AdapterParam = @{

            cimSession = $cimSessionCurrent
            Physical   = $True
            Verbose    = $False
            Debug      = $False
        }
        Get-NetAdapter @AdapterParam | ForEach-Object -Process {
        
            $AdapterName = $psItem.Name

            $AddressParam = @{

                cimSession     = $cimSessionCurrent                
                Verbose        = $False
                Debug          = $False
            }
            $ipAddressCurrent = Get-NetIPAddress @AddressParam | Where-Object -FilterScript {

                $psItem.InterfaceAlias -eq $AdapterName -and
                $psItem.PrefixOrigin   -eq 'Manual'
            }

            If
            (
                $ipAddressCurrent
            )
            {
                $ipAddress.Add(
                    [System.Net.NetworkInformation.PhysicalAddress]::Parse( $psItem.MacAddress ),
                    $ipAddressCurrent
                )
            }
        }

      # Locate target (physical disk)

        $Disk = Get-Disk -cimSession $cimSessionCurrent | Where-Object -FilterScript {
            $psItem.BootFromDisk
        }

        $Partition = Get-Partition -Disk $Disk | Where-Object -FilterScript {
            $psItem.Type -eq 'Basic'
        }

      # Copy disk and mount it

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Copying the disk"
        Write-Verbose -Message $Message

        $ItemParam = @{

            Path        = $Source.FullName
            Destination = $Partition.AccessPaths[0]
            ToSession   = $psSessionCurrent
            PassThru    = $True
        }
        Copy-Item @ItemParam

        $Path = Join-Path -Path $Partition.AccessPaths[0] -ChildPath $Source.Name

        $DiskImage = Get-DiskImage -cimSession $cimSessionCurrent -ImagePath $Path

        $DiskImage = Mount-DiskImage -InputObject $DiskImage -PassThru

      # Locate future boot partition and set future OS to boot
    
        $Disk = Get-Disk -cimSession $cimSessionCurrent -Number $DiskImage.Number

        $Partition = Get-Partition -Disk $Disk | Where-Object -FilterScript {
            $psItem.Type -eq 'Basic'
        }

      # Load registry hive and set VHDX to not expand on boot

        $HivePath = [System.IO.Path]::Combine(
            $Partition.AccessPaths[0],
            'Windows\System32\Config\System'
        )

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Setting disk to not expand on boot"
        Write-Verbose -Message $Message

        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

            reg.exe Load "hklm\Mount" $using:HivePath
            Set-ItemProperty -Path 'hklm:\mount\ControlSet001\Services\FsDepends\Parameters' -Name 'VirtualDiskExpandOnMount' -Value 4
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            reg.exe unLoad "hklm\Mount"
        }

      # Does not work because the drive does not exist on local machine
      # $Path = Join-Path -Path $Partition.AccessPaths[0] -ChildPath 'Windows\System32\bcdBoot.exe'
    
        $bcdBoot = [System.IO.Path]::Combine(
            $Partition.AccessPaths[0],
            'Windows\System32\bcdBoot.exe'
        )

        $Windows = [System.IO.Path]::Combine(
            $Partition.AccessPaths[0],
            'Windows'
        )

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Setting boot target to the new image"
        Write-Verbose -Message $Message

        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {
        
            & $using:bcdBoot $using:Windows /v
        }

      # Prepare answer file for OS specialization

        $odjPath = Join-Path -Path $env:Temp -ChildPath $NameCurrent

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Requesting Offline Domain Join"
        Write-Verbose -Message $Message

        $dJoin = dJoin.exe /Provision /Reuse /Domain "$DomainName" /Machine "$NameCurrent" /Reuse /PrintBlob /SaveFile $odjPath

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Creating answer file"
        Write-Verbose -Message $Message

        $Temp = Invoke-Command -Session $psSessionCurrent -ScriptBlock { $env:Temp }

        $AnswerPath = Join-Path -Path $Temp -ChildPath 'Unattend.xml'

        $xml = @"
<?xml version="1.0" encoding="utf-8"?>
  <!--  Sample Answer file to automate minimal viable manageable configuration
        Last edit 2020-03-03 by Artem Pronichkin
        For explanation please see https://pronichkin.com -->
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="offlineServicing">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <ComputerName>$NameCurrent</ComputerName>
      <OfflineUserAccounts>
        <OfflineAdministratorPassword>
          <Value>$PasswordBase64</Value>
          <PlainText>false</PlainText>
        </OfflineAdministratorPassword>
        <OfflineDomainAccounts>
          <OfflineDomainAccount>
            <SID>$($MemberId.Value)</SID>
            <Group>Administrators</Group>
          </OfflineDomainAccount>
        </OfflineDomainAccounts>
      </OfflineUserAccounts>        
    </component>
    <component name="Microsoft-Windows-UnattendedJoin"
               processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35"
               language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <OfflineIdentification>
        <Provisioning>
          <AccountData>$($dJoin[12])</AccountData>
        </Provisioning>
      </OfflineIdentification>
    </component>
  </settings>
</unattend>
"@

      # Apply the answer file

        Invoke-Command -Session $psSessionCurrent -ScriptBlock {

            $xmlDocument = [System.Xml.XmlDocument]::new()
            $xmlDocument.LoadXml( $using:xml )
            $xmlDocument.Save( $using:AnswerPath )
        }
    
        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Applying the answer file"
        Write-Verbose -Message $Message

        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

            Use-WindowsUnattend -UnattendPath $using:AnswerPath -Path $using:Partition.AccessPaths[0]
    
            Remove-Item -Path $using:AnswerPath
        }

      # Cleanup and reboot
        
        $DiskImage = Dismount-DiskImage -InputObject $DiskImage

        Remove-Item -Path $odjPath

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Restarting"
        Write-Verbose -Message $Message

        Invoke-Command -Session $psSessionCurrent -ScriptBlock {
    
            Restart-Computer -Force
        }

        Start-Sleep -Seconds 30

      # Wait for restart

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Waiting for HTTP"
        Write-Verbose -Message $Message

        $ConnectionParam = @{

            ComputerName  = $AddressCurrent
            CommonTCPPort = 'WinRM'
            Verbose       = $False
            Debug         = $False
            WarningAction = [System.Management.Automation.ActionPreference]::SilentlyContinue
        }
        $Test = Test-NetConnection @ConnectionParam

        While
        (
            -Not $test.TcpTestSucceeded
        )
        {
            Start-Sleep -Seconds 3

            $Test = Test-NetConnection @ConnectionParam
        }

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Waiting for WinRM"
        Write-Verbose -Message $Message

        $wsManParam = @{
        
            ComputerName   = $AddressCurrent
            Authentication = [Microsoft.WSMan.Management.AuthenticationMechanism]::Kerberos
            ErrorAction    = [System.Management.Automation.ActionPreference]::SilentlyContinue
        }
        $Test = Test-wsMan @wsManParam

        While
        (
            -not $Test -or
            $Test.ProductVersion -eq 'OS: 0.0.0 SP: 0.0 Stack: 3.0'
        )
        {
            Start-Sleep -Seconds 3

            $Test = Test-wsMan @wsManParam
        }
    
        $SessionParam = @{

            ComputerName = $AddressCurrent
            Verbose      = $False
        }
        $psSessionCurrent  = New-psSession  @SessionParam
        $cimSessionCurrent = New-cimSession @SessionParam

      # Restore network settings

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Installing driver"
        Write-Verbose -Message $Message

      # $Name = 'TBT_WIN10_64_DCH_58'
        $Name = 'Thunderbolt_Win10_Version-66'

        $ItemParam = @{

            Path        = "$($env:UserProfile)\Downloads\$Name.zip"
            ToSession   = $psSessionCurrent
            Destination = $Temp
        }
        Copy-Item @ItemParam

        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

            Set-Location -Path $using:Temp

            Expand-Archive -Path ".\$($using:Name).zip"

            pnputil.exe /Add-Driver ".\$($using:Name)\*.inf" /Install
        }

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Restoring Static IP Address"
        Write-Verbose -Message $Message

        $ipAddressRestore = [System.Collections.Generic.List[
            Microsoft.Management.Infrastructure.CimInstance
        ]]::new()

        $ipAddress.GetEnumerator() | ForEach-Object -Process {

            $PhysicalAddress = $psItem.Key

            $netAdapterCurrent = Get-NetAdapter -cimSession $cimSessionCurrent | Where-Object -FilterScript {

                [System.Net.NetworkInformation.PhysicalAddress]::Parse( $psItem.MacAddress ) -eq $PhysicalAddress
            }

            If
            (
                $netAdapterCurrent
            )
            {
                $AddressParam = @{
                
                    cimSession     = $cimSessionCurrent
                    InterfaceAlias = $netAdapterCurrent.Name
                    IPAddress      = $psItem.Value.ipAddress
                    PrefixLength   = $psItem.Value.PrefixLength
                    Verbose        = $False
                    Debug          = $False
                }
                New-NetIPAddress @AddressParam | ForEach-Object -Process {
                    $ipAddressRestore.Add( $psItem )
                }
            }
        }

      # Changing feature state

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Modifying feature"
        Write-Verbose -Message $Message

        $FeatureName.GetEnumerator() | ForEach-Object -Process {

            $CommandCurrent = "$($psItem.Key)-WindowsOptionalFeature"

            $FeatureParam = @{

                Online        = $True
                FeatureName   = $psItem.Value
                NoRestart     = $True
                WarningAction = [System.Management.Automation.ActionPreference]::SilentlyContinue
            }

            $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

                & $using:CommandCurrent @using:FeatureParam
            }
        }

        If
        (
            $Command.RestartNeeded
        )
        {
            $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Restarting"
            Write-Verbose -Message $Message

            Restart-Computer -ComputerName $AddressCurrent -Wait -Protocol 'wsMan' -Force

            $psSessionCurrent  = New-psSession  @SessionParam
            $cimSessionCurrent = New-cimSession @SessionParam
        }

      # Add the node back to the cluster

        If
        (
            Test-Path -Path 'Variable:\Cluster'
        )
        {
            $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Adding cluster node"
            Write-Verbose -Message $Message

                $Node    = Add-ClusterNode -Name $NameCurrent -InputObject $Cluster
        }

        $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Machine `“$AddressCurrent`” upgraded successfully"
        Write-Verbose -Message $Message
    }
}

$Cluster = Update-ClusterFunctionalLevel -InputObject $Cluster -Force -Verbose:$False

#endregion Code