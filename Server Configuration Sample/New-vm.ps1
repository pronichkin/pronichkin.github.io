<#  To do

 1. Use CIW to generate the source disk
 2. Use ReFS block clone to create child disk
 3. Use IMC for fast specialization
 4. Use Answer File generator for more flexibility
 5. BCD manipulations?
 6. Separate functions

#>

#region Data

  # $SourcePath       = '\\winbuilds.ntdev.corp.microsoft.com\release\RS_FUN_PKG\19578.1000.200303-1600\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\19578.1000.amd64fre.rs_fun_pkg.200303-1600_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath       = '\\winbuilds.ntdev.corp.microsoft.com\release\RS_PRERELEASE\19579.1000.200303-1518\amd64fre\vhdx\vhdx_server_serverdatacentercore_en-us_vl\19579.1000.amd64fre.rs_prerelease.200303-1518_server_serverdatacentercore_en-us_vl.vhdx'
  # $SourcePath       = '\\winbuilds.ntdev.corp.microsoft.com\release\RS_PRERELEASE\19579.1000.200303-1518\amd64fre\vhdx\vhdx_server_serverdatacenter_en-us_vl\19579.1000.amd64fre.rs_prerelease.200303-1518_server_serverdatacenter_en-us_vl.vhdx'
    $SourcePath       = '\\winbuilds.ntdev.corp.microsoft.com\release\vb_release\19041.1.191206-1406\amd64fre\vhdx\vhdx_server_serverdatacenteracore_en-us_vl\19041.1.amd64fre.vb_release.191206-1406_server_serverdatacenteracore_en-us_vl.vhdx'
  # $SourcePath       = '\\winbuilds.ntdev.corp.microsoft.com\release\rs5_release_svc_refresh\17763.557.190612-0019\amd64fre\vhdx\vhdx_server_serverdatacenteracore_en-us_vl\17763.557.amd64fre.rs5_release_svc_refresh.190612-0019_server_serverdatacenteracore_en-us_vl.vhdx'

    $Name             = 'ArtemP-DB'
    $Start            =  0
    $Count            =  1

    $DomainName       = 'ntDev.corp.Microsoft.com'
    $Password         = 'P@ssw0rd.123'
  # $MemberName       = 'KeplerLabUser'
    $MemberName       = 'ArtemP'
  # $MemberDomainName = 'Redmond.corp.Microsoft.com'
    $MemberDomainName = 'ntDev.corp.Microsoft.com'

    $Path             = 'D:\Virtual Machine'

    $MinimumBytes     =  2gb
    $StartupBytes     =  4gb
    $MaximumBytes     =  8gb

#endregion Data

#region Prepare

    $PasswordSalt   = $Password + 'OfflineAdministratorPassword'
    $PasswordByte   = [System.Text.Encoding]::Unicode.GetBytes( $PasswordSalt )
    $PasswordBase64 = [System.Convert]::ToBase64String( $PasswordByte )

    $Group   = [System.Security.Principal.NTAccount]::new( $MemberDomainName, $MemberName )
    $GroupId = $Group.Translate( [System.Security.Principal.SecurityIdentifier] )

    $Source = Get-Item -Path $SourcePath

    $SourcePathLocal = Join-Path -Path $Path -ChildPath $Source.Name

    If
    (
        Test-Path -Path $SourcePathLocal
    )
    {
        $Message = "Local copy of the source disk `“$($Source.Name)`” already exists"
        Write-Verbose -Message $Message

        $Source = Get-Item -Path $SourcePathLocal
    }
    Else
    {
        $Message = "Copying the source disk `“$($Source.Name)`”. This will take some time"
        Write-Verbose -Message $Message

        $Source = Copy-Item -Path $SourcePath -Destination $Path -PassThru

        $ReadOnly  = [System.IO.FileAttributes]::ReadOnly
        $Integrity = [System.IO.FileAttributes]::IntegrityStream

        $Attribute = $Source.Attributes -bor $ReadOnly -bxor $Integrity
        Set-ItemProperty -Path $Source.FullName -Name 'Attributes' -Value $Attribute
    }

#endregion Prepare

#region Provision

    $Start..($Start+$Count-1) | ForEach-Object -Process {

        $Number = $psItem.toString( 'D2')

        $NameCurrent = "$Name-$Number"

        $vm = Get-VM | Where-Object -FilterScript { $psItem.Name -eq $NameCurrent }

        If
        (
            $vm
        )
        {
            $Message = "Virtual Machine `“$NameCurrent`” already exists, skipping"
            Write-Verbose -Message $Message
        }
        Else
        {
            $Message = "Deploying `“$NameCurrent`”"
            Write-Verbose -Message $Message

            $odjPath = Join-Path -Path $env:Temp -ChildPath $NameCurrent

            $Message = 'Requesting Offline Domain Join'
            Write-Verbose -Message $Message

            $dJoin = dJoin.exe /Provision /Domain "$DomainName" /Machine "$NameCurrent" /Reuse /PrintBlob /SaveFile $odjPath

            $Message = "Creating differencing disk `“$("$NameCurrent$($Source.Extension)")`”"
            Write-Verbose -Message $Message

            $VirtualDiskPath = Join-Path -Path $Path -ChildPath "$NameCurrent$($Source.Extension)"

            $VirtualDisk = New-VHD -Differencing -ParentPath $SourcePathLocal -Path $VirtualDiskPath

         <# $VirtualDisk = Copy-Item -Path $SourcePath -Destination $Path -PassThru

            $VirtualDisk = Rename-Item -Path $VirtualDisk.FullName -NewName "$NameCurrent.vhdx" -PassThru  #>

            $Message = "Creating answer file"
            Write-Verbose -Message $Message

            $AnswerPath = Join-Path -Path $env:Temp -ChildPath 'Unattend.xml'

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
  <!--  <OfflineAdministratorPassword>
          <Value>$PasswordBase64</Value>
          <PlainText>false</PlainText>
        </OfflineAdministratorPassword>  -->
        <OfflineDomainAccounts>
          <OfflineDomainAccount>
            <SID>$($GroupId.Value)</SID>
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
    <component name="Microsoft-Windows-DeviceGuard-Unattend"
            processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35"            
            language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">            
      <EnableVirtualizationBasedSecurity>1</EnableVirtualizationBasedSecurity>
      <HypervisorEnforcedCodeIntegrity>1</HypervisorEnforcedCodeIntegrity>
      <LsaCfgFlags>1</LsaCfgFlags>
    </component>
<!--<component name="Microsoft-Windows-CodeIntegrity" 
            processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" 
            language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SkuPolicyRequired>1</SkuPolicyRequired>
    </component>  -->
  </settings>
</unattend>
"@

            $xmlDocument = [System.Xml.XmlDocument]::new()
            $xmlDocument.LoadXml( $xml )
            $xmlDocument.Save( $AnswerPath )

            $Message = 'Applying the answer file'
            Write-Verbose -Message $Message

            $DiskImage = Get-DiskImage -ImagePath $VirtualDisk.Path
        
            $DiskImage = Mount-DiskImage -InputObject $DiskImage -NoDriveLetter -PassThru

            $Disk = Get-Disk -Number $DiskImage.Number

            $Partition = Get-Partition -Disk $Disk | Where-Object -FilterScript { $psItem.Type -eq 'Basic' }

            [System.Void]( Use-WindowsUnattend -UnattendPath $AnswerPath -Path $Partition.AccessPaths[0] )
    
            $DiskImage = Dismount-DiskImage -InputObject $DiskImage
    
            Remove-Item -Path $AnswerPath
            Remove-Item -Path $odjPath

            $Message = "Creating virtual machine"
            Write-Verbose -Message $Message

            $vm = New-vm -Name $NameCurrent -vhdPath $VirtualDisk.Path -Path $Path -SwitchName 'Ethernet' -Generation 2 -Version 9.2

            Set-vmMemory -vm $vm -DynamicMemoryEnabled $True -MinimumBytes $MinimumBytes -StartupBytes $StartupBytes -MaximumBytes $MaximumBytes

            Set-vmProcessor -vm $vm -Count 4

            Set-vmFirmware  -vm $vm -ConsoleMode None -PauseAfterBootFailure On  # -FirstBootDevice $Drive

            Set-vm -vm $vm -LockOnDisconnect On -CheckpointType Disabled -BatteryPassthroughEnabled $True -AutomaticCheckpointsEnabled $False

            Get-vmIntegrationService -vm $vm | Where-Object -FilterScript { -not $psItem.Enabled } | Enable-vmIntegrationService
        }

        $Message = "Starting virtual machine"
        Write-Verbose -Message $Message

        Start-vm -vm $vm

        vmConnect.exe LocalHost $vm.Name
    }

#endregion Provision