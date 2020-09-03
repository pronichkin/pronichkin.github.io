#region Data

  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\vb_release\19041.1.191206-1406\amd64fre\vhdx\vhdx_server_serverdatacenteracore_en-us_vl\19041.1.amd64fre.vb_release.191206-1406_server_serverdatacenteracore_en-us_vl.vhdx'

  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI_PROD1\17763.1098.200409-1700\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17763.1098.amd64fre.rs5_release_svc_hci_prod1.200409-1700_server_serverazurestackhcicor_en-us.vhdx'

  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI_PROD1\17784.1004.200414-2230\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1004.amd64fre.rs5_release_svc_hci_prod1.200414-2230_server_serverazurestackhcicor_en-us.vhdx'

  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1015.200511-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1015.amd64fre.rs5_release_svc_hci.200511-1900_server_serverazurestackhcicor_en-us.vhdx'

  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1048.200616-1043\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1048.amd64fre.rs5_release_svc_hci.200616-1043_server_serverazurestackhcicor_en-us.vhdx'

    $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1068.200716-1400\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1068.amd64fre.rs5_release_svc_hci.200716-1400_server_serverazurestackhcicor_en-us.vhdx'

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

 <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Starting upgrade for `“$AddressCurrent`”"
    Write-Verbose -Message $Message  #>

    $Message = "Starting upgrade for `“$AddressCurrent`”"
    Write-Message -Channel Verbose -Message $Message

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
     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Server already runs the target image `“$($Source.BaseName)`”. Skipping"
        Write-Verbose -Message $Message  #>

        $Message = "Server already runs the target image `“$($Source.BaseName)`”. Skipping"
        Write-Message -Channel Verbose -Message $Message
    }
    Else
    {
        If
        (
            Test-Path -Path 'variable:\Credential'
        )
        {
            $Message = 'Non-domain server, skipping cluster checks'
            Write-Message -Channel Debug -Message $Message
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
                        Drain                         = $True
                        ForceDrain                    = $True
                        RetryDrainOnFailure           = $True
                        AvoidPlacement                = $False
                        Wait                          = $True
                        Verbose                       = $False
                    }
                    $Node    = Suspend-ClusterNode @NodeParam

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

      # Store Virtual Switch information to be restored later

        $Switch = [System.Collections.Generic.Dictionary[
            System.String,
            System.Collections.Generic.List[
                System.Net.NetworkInformation.PhysicalAddress
            ]
        ]]::new()

        $SwitchParam = @{

            CimSession = $cimSessionCurrent
            SwitchType = [Microsoft.HyperV.PowerShell.vmSwitchType]::External
        }
        Get-vmSwitch @SwitchParam | ForEach-Object -Process {

            $SwitchCurrent = $psItem

            $PhysicalAddress = [System.Collections.Generic.List[
                System.Net.NetworkInformation.PhysicalAddress
            ]]::new()

            $AdapterParam = @{
            
                CimSession           = $cimSessionCurrent
                InterfaceDescription = $SwitchCurrent.NetAdapterInterfaceDescriptions
                Verbose              = $False
            }
            Get-NetAdapter @AdapterParam | ForEach-Object -Process {

                $PhysicalAddressCurrent = [System.Net.NetworkInformation.PhysicalAddress]::Parse( $psItem.MacAddress )

                $PhysicalAddress.Add( $PhysicalAddressCurrent )
            }

            $Switch.Add( 
                $SwitchCurrent.Name,
                $PhysicalAddress
            )
        }

      # Locate target (physical disk)

        $Disk = Get-Disk -cimSession $cimSessionCurrent | Where-Object -FilterScript {
            $psItem.BootFromDisk
        }

        $Partition = Get-Partition -Disk $Disk | Where-Object -FilterScript {
            $psItem.Type -eq 'Basic'
        }

      # Copy disk and mount it

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Copying the disk"
        Write-Verbose -Message $Message  #>

        $Message = 'Copying the disk'
        Write-Message -Channel Debug -Message $Message

        $ItemParam = @{

            Path        = $Source.FullName
            Destination = $Partition.AccessPaths[0]
            ToSession   = $psSessionCurrent
            PassThru    = $True
        }
        Copy-Item @ItemParam

     <# Join-Path fails if local machine does not have a disk with the same drive
        letter

        $Path = Join-Path -Path $Partition.AccessPaths[0] -ChildPath $Source.Name  #>

        $Path = [System.IO.Path]::Combine( $Partition.AccessPaths[0], $Source.Name )

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

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Setting disk to not expand on boot"
        Write-Verbose -Message $Message  #>

        $Message = 'Setting disk to not expand on boot'
        Write-Message -Channel Debug -Message $Message

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

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Setting boot target to the new image"
        Write-Verbose -Message $Message  #>

        $Message = 'Setting boot target to the new image'
        Write-Message -Channel Debug -Message $Message

        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {
        
            & $using:bcdBoot $using:Windows /v
        }

      # Prepare answer file for OS specialization

        If
        (
            Test-Path -Path 'variable:\Credential'
        )
        {
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
      </OfflineUserAccounts>        
    </component>
  </settings>
</unattend>
"@
        }
        Else
        {
            $odjPath = Join-Path -Path $env:Temp -ChildPath $NameCurrent

         <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Requesting Offline Domain Join"
            Write-Verbose -Message $Message  #>

            $Message = 'Requesting Offline Domain Join'
            Write-Message -Channel Debug -Message $Message

            $dJoin = dJoin.exe /Provision /Reuse /Domain "$DomainName" /Machine "$NameCurrent" /Reuse /PrintBlob /SaveFile $odjPath
        
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
        }

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Creating answer file"
        Write-Verbose -Message $Message  #>

        $Message = 'Creating answer file'
        Write-Message -Channel Debug -Message $Message

        $Temp = Invoke-Command -Session $psSessionCurrent -ScriptBlock { $env:Temp }

        $AnswerPath = Join-Path -Path $Temp -ChildPath 'Unattend.xml'

      # Apply the answer file

        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

            $xmlDocument = [System.Xml.XmlDocument]::new()
            $xmlDocument.LoadXml( $using:xml )
            $xmlDocument.Save( $using:AnswerPath )
        }
    
     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Applying the answer file"
        Write-Verbose -Message $Message  #>

        $Message = 'Applying the answer file'
        Write-Message -Channel Debug -Message $Message

        $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

            Use-WindowsUnattend -UnattendPath $using:AnswerPath -Path $using:Partition.AccessPaths[0]
    
            Remove-Item -Path $using:AnswerPath
        }

      # Cleanup and reboot
        
        $DiskImage = Dismount-DiskImage -InputObject $DiskImage

        If
        (
            Test-Path -Path 'variable:\odjPath'
        )
        {
            Remove-Item -Path $odjPath
        }

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Restarting"
        Write-Verbose -Message $Message  #>

        $Message = 'Restarting'
        Write-Message -Channel Debug -Message $Message

        Invoke-Command -Session $psSessionCurrent -ScriptBlock {
    
            Restart-Computer -Force
        }

        Start-Sleep -Seconds 30

      # Wait for restart

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Waiting for HTTP"
        Write-Verbose -Message $Message  #>

        $Message = 'Waiting for HTTP'
        Write-Message -Channel Debug -Message $Message

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

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Waiting for WinRM"
        Write-Verbose -Message $Message  #>

        $Message = 'Waiting for WinRM'
        Write-Message -Channel Debug -Message $Message

        $wsManParam = @{
        
            ComputerName   = $AddressCurrent            
            ErrorAction    = [System.Management.Automation.ActionPreference]::SilentlyContinue
        }

        $psSessionParam = @{

            ComputerName   = $AddressCurrent
          # Verbose        = $False
        }

        $cimSessionParam = @{

            ComputerName   = $AddressCurrent
            Verbose        = $False
        }

        If
        (
            Test-Path -Path 'variable:\Credential'
        )
        {
            $wsManParam.Add(
                'Authentication',
                [Microsoft.wsMan.Management.AuthenticationMechanism]::Negotiate
            )

            $wsManParam.Add(
                'Credential',
                $Credential
            )

            $psSessionParam.Add(
                'Authentication',
                [System.Management.Automation.Runspaces.AuthenticationMechanism]::Negotiate
            )

            $psSessionParam.Add(
                'Credential',
                $Credential
            )            
            
            $cimSessionParam.Add(
                'Authentication',
                [Microsoft.Management.Infrastructure.Options.PasswordAuthenticationMechanism]::Negotiate
            )

            $cimSessionParam.Add(
                'Credential',
                $Credential
            )
        }
        Else
        {
            $wsManParam.Add(
                'Authentication',
                [Microsoft.wsMan.Management.AuthenticationMechanism]::Kerberos
            )

            $psSessionParam.Add(
                'Authentication',
                [System.Management.Automation.Runspaces.AuthenticationMechanism]::Kerberos
            )

            $cimSessionParam.Add(
                'Authentication',
                [Microsoft.Management.Infrastructure.Options.PasswordAuthenticationMechanism]::Kerberos
            )
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

        $psSessionCurrent  = New-psSession  @psSessionParam
        $cimSessionCurrent = New-cimSession @cimSessionParam

      # Install driver

        $InstanceParam = @{
            
            CimSession = $cimSessionCurrent
            ClassName  = 'win32_ComputerSystem'
            Verbose    = $False
        }
        $Instance = Get-CimInstance @InstanceParam

        If
        (
            $Instance.Model -eq 'Kepler 47'
        )
        {
         <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Installing driver"
            Write-Verbose -Message $Message  #>

            $Message = 'Installing driver'
            Write-Message -Channel Debug -Message $Message

          # $Name = 'TBT_WIN10_64_DCH_58'
            $Name = 'Thunderbolt_Win10_Version-66'

            $Path = Join-Path -Path $env:Temp -ChildPath "$Name.zip"

            $RequestParam = @{
                
                UseBasicParsing = $True
                Uri             = "https://downloadmirror.intel.com/28735/eng/$Name.zip"
                OutFile         = $Path
                PassThru        = $True
                Verbose         = $False
            }
            $Request = Invoke-WebRequest @RequestParam

            $ItemParam = @{

                Path        = $Path
                ToSession   = $psSessionCurrent
                Destination = $Temp
            }
            Copy-Item @ItemParam

            $Command = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

                Set-Location -Path $using:Temp

                Expand-Archive -Path ".\$($using:Name).zip" -Force -Verbose:$False

                pnputil.exe /Add-Driver ".\$($using:Name)\*.inf" /Install
            }
        }

      # Changing feature state

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Modifying feature"
        Write-Verbose -Message $Message  #>

        $Message = 'Modifying feature'
        Write-Message -Channel Debug -Message $Message

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
         <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Restarting"
            Write-Verbose -Message $Message  #>

            $Message = 'Restarting'
            Write-Message -Channel Debug -Message $Message

            $ComputerParam = @{
    
                ComputerName = $AddressCurrent
                Protocol     = 'wsMan'
                Wait         = $True
                Force        = $True
            }

            If
            (
                Test-Path -Path 'variable:\Credential'
            )
            {
                $ComputerParam.Add(
                    'wsmanAuthentication', 'Negotiate'
                )
        
                $ComputerParam.Add(
                    'Credential',          $Credential
                )
            }

            Restart-Computer @ComputerParam

            $psSessionCurrent  = New-psSession  @psSessionParam
            $cimSessionCurrent = New-cimSession @cimSessionParam
        }

      # Restore network settings

        $Message = 'Restoring Virtual Switch'
        Write-Message -Channel Debug -Message $Message

        $SwitchRestore = [System.Collections.Generic.List[
            Microsoft.HyperV.PowerShell.vmSwitch
        ]]::new()

        $Switch.GetEnumerator() | ForEach-Object -Process {

            $SwitchCurrent = $psItem

            $AdapterParam = @{
                
                CimSession = $cimSessionCurrent
                Physical   = $True
                Verbose    = $False
            }
            $Adapter = Get-NetAdapter @AdapterParam | Where-Object -FilterScript {
                $psItem.MacAddress -in $SwitchCurrent.Value
            }

            $SwitchParam = @{
                
                Name                           = $SwitchCurrent.Key
                NetAdapterInterfaceDescription = $Adapter.InterfaceDescription
                AllowManagementOS              = $True
                MinimumBandwidthMode           = [Microsoft.HyperV.PowerShell.vmSwitchBandwidthMode]::None
                EnableEmbeddedTeaming          = $True
                CimSession                     = $cimSessionCurrent
            }
            $SwitchRestore.Add( ( New-vmSwitch @SwitchParam ) )
        }

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Restoring Static IP Address"
        Write-Verbose -Message $Message  #>

        $Message = 'Restoring Static IP Address'
        Write-Message -Channel Debug -Message $Message

        $ipAddressRestore = [System.Collections.Generic.List[
            Microsoft.Management.Infrastructure.CimInstance
        ]]::new()

        $ipAddress.GetEnumerator() | ForEach-Object -Process {

            $PhysicalAddress = $psItem.Key

         <# This does not work as designed for Thunderbolt adapters because
            apparently they use a different MAC address each time. However, this
            does not block the upgrade. Hence, the current solution is to assign
            static IP addresses manually afterwards, or using a separate script  #>

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

      # Add the node back to the cluster

        If
        (
            Test-Path -Path 'Variable:\Cluster'
        )
        {
         <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Adding cluster node"
            Write-Verbose -Message $Message  #>

            $Message = 'Adding cluster node'
            Write-Message -Channel Debug -Message $Message

            $Node    = Add-ClusterNode -Name $NameCurrent -InputObject $Cluster

            While
            (
                Get-StorageJob -CimSession $cimSessionCurrent
            )
            {
                $Message = 'Waiting for storage jobs to complete'
                Write-Message -Channel Debug -Message $Message

                Start-Sleep -Seconds 60
            }
        }

     <# $Message = "$((Get-Date).ToUniversalTime().ToLongTimeString())    Machine `“$AddressCurrent`” upgraded successfully"
        Write-Verbose -Message $Message  #>

        $Message = "Machine `“$AddressCurrent`” upgraded successfully"
        Write-Message -Channel Verbose -Message $Message
    }
}

If
(
    Test-Path -Path 'Variable:\Cluster'
)
{
    $Cluster = Update-ClusterFunctionalLevel -InputObject $Cluster -Force -Verbose:$False
}

#endregion Code