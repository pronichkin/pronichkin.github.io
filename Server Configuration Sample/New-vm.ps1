<#  To do

 1. Use CIW to generate the source disk
 2. Use ReFS block clone to create child disk
 3. Use IMC for fast specialization
 4. Use Answer File generator for more flexibility
 5. BCD manipulations?
 6. Separate functions

#>

#region Random

  # Random
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS_FUN_PKG\19578.1000.200303-1600\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\19578.1000.amd64fre.rs_fun_pkg.200303-1600_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS_PRERELEASE\19579.1000.200303-1518\amd64fre\vhdx\vhdx_server_serverdatacentercore_en-us_vl\19579.1000.amd64fre.rs_prerelease.200303-1518_server_serverdatacentercore_en-us_vl.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS_PRERELEASE\19579.1000.200303-1518\amd64fre\vhdx\vhdx_server_serverdatacenter_en-us_vl\19579.1000.amd64fre.rs_prerelease.200303-1518_server_serverdatacenter_en-us_vl.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\rs_onecore_base2_has2\20209.1000.200903-1919\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\20209.1000.amd64fre.rs_onecore_base2_has2.200903-1919_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\rs_onecore_base2_has2\20210.1000.200904-1919\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\20210.1000.amd64fre.rs_onecore_base2_has2.200904-1919_server_serverazurestackhcicor_en-us.vhdx'

#endregion Random

#region Release

  # RS5 Desktop LTSC
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE\17763.1.180914-1434\amd64fre\vhdx\vhdx_server_serverdatacenter_en-us_vl\17763.1.amd64fre.rs5_release.180914-1434_server_serverdatacenter_en-us_vl.vhdx'
  # $Name       = 'ArtemP-RS5DL'

  # RS5 Core LTSC
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE\17763.1.180914-1434\amd64fre\vhdx\vhdx_server_serverdatacentercore_en-us_vl\17763.1.amd64fre.rs5_release.180914-1434_server_serverdatacentercore_en-us_vl.vhdx'
  # $Name       = 'ArtemP-RS5CL'

  # RS5 Core SAC
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE\17763.1.180914-1434\amd64fre\vhdx\vhdx_server_serverdatacenteracore_en-us_vl\17763.1.amd64fre.rs5_release.180914-1434_server_serverdatacenteracore_en-us_vl.vhdx'
  # $Name       = 'ArtemP-RS5CS'

  # RS5 Core HVS
  # $SourcePath = 'C:\Users\artemp\Downloads\17763.1.amd64fre.rs5_release.180914-1434_Server_ServerHyperCore_en-US.vhdx'
  # $Name       = 'ArtemP-RS5CV'

  # RS5 Core HCI
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1068.200716-1400\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1068.amd64fre.rs5_release_svc_hci.200716-1400_server_serverazurestackhcicor_en-us.vhdx'
  # $Name       = 'ArtemP-RS5CI'

  # RS5 Core Turbine
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1068.200716-1400\amd64fre\vhdx\vhdx_server_azurecore_en-us_vl\17784.1068.amd64fre.rs5_release_svc_hci.200716-1400_server_serverturbinecore_en-us_vl.vhdx'
  # $Name       = 'ArtemP-RS5CT'

  # RS5 Refresh
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\rs5_release_svc_refresh\17763.557.190612-0019\amd64fre\vhdx\vhdx_server_serverdatacenteracore_en-us_vl\17763.557.amd64fre.rs5_release_svc_refresh.190612-0019_server_serverdatacenteracore_en-us_vl.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\rs5_release_svc_refresh\17763.1339.200710-1755\amd64fre\vhdx\vhdx_server_serverstandard_en-us_vl\17763.1339.amd64fre.rs5_release_svc_refresh.200710-1755_server_serverstandard_en-us_vl.vhdx'

  # Vb Core SAC
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\vb_release\19041.1.191206-1406\amd64fre\vhdx\vhdx_server_serverdatacenteracore_en-us_vl\19041.1.amd64fre.vb_release.191206-1406_server_serverdatacenteracore_en-us_vl.vhdx'
  # $Name       = 'ArtemP-VbCS'

#endregion Release

#region HCI

  # HCI
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1048.200616-1043\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1048.amd64fre.rs5_release_svc_hci.200616-1043_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1060.200708-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1060.amd64fre.rs5_release_svc_hci.200708-1900_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1060.200708-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_ru-ru\17784.1060.amd64fre.rs5_release_svc_hci.200708-1900_server_serverazurestackhcicor_ru-ru.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI_PROD1\17784.1081.200712-1700\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1081.amd64fre.rs5_release_svc_hci_prod1.200712-1700_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI_PROD1\17784.1082.200713-1700\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1082.amd64fre.rs5_release_svc_hci_prod1.200713-1700_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI_PROD1\17784.1082.200713-1700\amd64fre\vhdx\vhdx_server_serverdatacenter_en-us_vl\17784.1082.amd64fre.rs5_release_svc_hci_prod1.200713-1700_server_serverdatacenter_en-us_vl.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1065.200713-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1065.amd64fre.rs5_release_svc_hci.200713-1900_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1066.200714-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1066.amd64fre.rs5_release_svc_hci.200714-1900_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1066.200714-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_ru-ru\17784.1066.amd64fre.rs5_release_svc_hci.200714-1900_server_serverazurestackhcicor_ru-ru.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1066.200714-1900\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_fr-fr\17784.1066.amd64fre.rs5_release_svc_hci.200714-1900_server_serverazurestackhcicor_fr-fr.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1067.200715-1945\amd64fre\vhdx\vhdx_server_azurecore_en-us\17784.1067.amd64fre.rs5_release_svc_hci.200715-1945_server_serverturbinecore_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1068.200716-1400\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_en-us\17784.1068.amd64fre.rs5_release_svc_hci.200716-1400_server_serverazurestackhcicor_en-us.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1068.200716-1400\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_ru-ru\17784.1068.amd64fre.rs5_release_svc_hci.200716-1400_server_serverazurestackhcicor_ru-ru.vhdx'
  # $SourcePath = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE_SVC_HCI\17784.1068.200716-1400\amd64fre\vhdx\vhdx_server_serverazurestackhcicor_zh-cn\17784.1068.amd64fre.rs5_release_svc_hci.200716-1400_server_serverazurestackhcicor_zh-cn.vhdx'

  # Turbine
  # $SourcePath = 'C:\Users\artemp\Downloads\17784.1067.amd64fre.rs5_release_svc_hci.200715-1945_Server_ServerTurbineCorCore_en-US.vhdx'
  # $SourcePath = 'C:\Users\artemp\Downloads\17784.1068.amd64fre.rs5_release_svc_hci.200716-1400_Server_ServerTurbineCorCore_en-US.vhdx'

#endregion HCI
 
  # $Name             = 'ArtemP-HCI'
  # $Name             = 'ArtemP-Vb'
  # $Name             = 'ArtemP-HVS'
  # $Name             = 'ArtemP-Dsktp'
  # $Name             = 'ArtemP-Trbn'
  # $Name             = 'ArtemP-RS5CL'

#region Data

  # $Start            =  23
    $Count            =   2

    $DomainAddress    = 'ntDev.corp.Microsoft.com'
    $Password         = 'P@ssw0rd.123'
  # $MemberName       = 'KeplerLabUser'
    $MemberName       = 'ArtemP'
  # $MemberDomainName = 'Redmond.corp.Microsoft.com'
    $MemberDomainName = 'ntDev.corp.Microsoft.com'

    $HostName         = 'Kepler004'
  # $Path             = 'D:\Virtual Machine'

    $MinimumBytes     =  2gb
    $StartupBytes     =  4gb
    $MaximumBytes     =  8gb

#endregion Data

#region Prepare

   #region Miscellaneous

        $PasswordSalt   = $Password + 'OfflineAdministratorPassword'
        $PasswordByte   = [System.Text.Encoding]::Unicode.GetBytes( $PasswordSalt )
        $PasswordBase64 = [System.Convert]::ToBase64String( $PasswordByte )

        $Group   = [System.Security.Principal.ntAccount]::new( $MemberDomainName, $MemberName )
        $GroupId = $Group.Translate( [System.Security.Principal.SecurityIdentifier] )

        $HostAddress = Resolve-DnsName -Name $HostName -Verbose:$False -Debug:$False | Sort-Object -Property 'Name' -Unique | Select-Object -First 1 -Property 'Name'
        $cimSession  = New-CimSession -ComputerName $HostAddress.Name -Verbose:$False
        $psSession   = New-PSSession  -ComputerName $HostAddress.Name

   #endregion Miscellaneous

   #region Path

        $Source      = Get-Item -Path $SourcePath
        $Computer    = Get-adComputer -Identity $HostName -Properties 'servicePrincipalName'
        $HostCurrent = Get-vmHost -cimSession $cimSession

        If
        (
            $Computer.servicePrincipalName | Where-Object -FilterScript {
                $psItem -like 'msServerClusterMgmtAPI/*'
            }
        )
        {
            $Service = Get-Service -ComputerName $HostAddress.Name | Where-Object -FilterScript { $psItem.Name -eq 'clusSvc' }
        }

        If
        (
            $Service -and        
            $Service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running
        )
        {
            $Cluster             = Get-Cluster -Name $HostAddress.Name
            $ClusterSharedVolume = Get-ClusterSharedVolume -InputObject $Cluster
            $Partition           = $ClusterSharedVolume.SharedVolumeInfo.Partition | Sort-Object -Property 'FreeSpace' | Select-Object -First 1

            $ClusterSharedVolumeCurrent = $ClusterSharedVolume | Where-Object -FilterScript {

                $psItem.SharedVolumeInfo[0].Partition.Name -eq $Partition.Name
            }

            $Path = $ClusterSharedVolumeCurrent.SharedVolumeInfo[0].FriendlyVolumeName

            $PathParam = @{

                Path      = $Path
                ChildPath = 'Virtual Hard Disks'
            }
            $PathDisk = Join-Path @PathParam

         <# Setting default paths at the host level allows us to omit explicit
            path at VM creation time. This way all the VM files get arranged in
            canonical locations, i.e. without a sub-folder based on VM Name.
           (The sub-folder  is always created when you create a VM using an
            explicitly specified, non-default path  #>

            $HostParam = @{

                CimSession          = $cimSession
                VirtualMachinePath  = $Path
                VirtualHardDiskPath = $PathDisk
                Passthru            = $True
            }
            $HostCurrent = Set-vmHost @HostParam
        }
        Else
        {   
            $Path     = $HostCurrent.VirtualMachinePath
            $PathDisk = $HostCurrent.VirtualHardDiskPaths
        }

   #endregion Path

   #region Disk

        $PathParam = @{
        
            Path      = $PathDisk
            ChildPath = $Source.Name
        }
        $SourcePathLocal = Join-Path @PathParam

        If
        (
            Invoke-Command -Session $psSession -ScriptBlock {
                Test-Path -Path $using:SourcePathLocal 
            }
        )
        {
            $Message = "Local copy of the source disk `“$($Source.Name)`” already exists"
            Write-Message -Channel Debug -Message $Message
        }
        Else
        {
            $Message = "Copying the source disk `“$($Source.Name)`”. This will take some time"
            Write-Message -Channel Verbose -Message $Message

            $ItemParam = @{
            
                Path        = $Source.FullName
                ToSession   = $psSession
                Destination = $PathDisk
                PassThru    = $True
            }
            Copy-Item @ItemParam

            $Message = "Setting file attribute"
            Write-Message -Channel Debug -Message $Message

            $IntegrityParam = @{
        
                CimSession = $cimSession
                FileName   = $SourcePathLocal
                Enable     = $True
                Enforce    = $True
            }
            Set-FileIntegrity @IntegrityParam

            $ReadOnly  = [System.IO.FileAttributes]::ReadOnly
            $noIndex   = [System.IO.FileAttributes]::NotContentIndexed

            Invoke-Command -Session $psSession -ScriptBlock {
        
                $Source = Get-Item -Path $using:SourcePathLocal

              # The bitwise OR may be used to set to 1 the selected bits of the register
                $Attribute = $Source.Attributes
                $Attribute = $Attribute -bOr $using:ReadOnly
                $Attribute = $Attribute -bOr $using:noIndex
          
             <# One thing to keep in mind about using the Set-ItemProperty cmdlet to work
                with file attributes through the FileSystem provider is that it is limited
                to working with the following attributes: Archive, Hidden, Normal,
                ReadOnly, or System. An error will be generated, and the attributes will
                not be modified if a file is compressed or encrypted  #>

              # Set-ItemProperty -Path $Source.FullName -Name 'Attributes' -Value $Attribute -PassThru
                $Source.Attributes = $Attribute
            }
        }

   #endregion Disk

   #region Name

        $NameAll = [System.Collections.Generic.List[
            System.String
        ]]::new()

        If
        (
            Test-Path -Path 'Variable:\Start'
        )
        {
            $Start..($Start+$Count-1) | ForEach-Object -Process {

                $Number      = $psItem.toString( 'D2' )
                $NameCurrent = "$Name-$Number"

                $NameAll.Add( $NameCurrent )
            }
        }
        Else
        {
            $Number = 0

            1..$Count | ForEach-Object -Process {

                $Computer = $True

                While
                (
                    $Computer
                )
                {
                    $Number++

                    $NumberCurrent = $Number.toString( 'D2' )
                    $NameCurrent   = "$Name-$NumberCurrent"

                    $Computer = Get-adComputer -Filter "Name -like '$NameCurrent'"
                }

                $NameAll.Add( $NameCurrent )
            }
        }

   #endregion Name

#endregion Prepare

#region Provision

    $NameAll | ForEach-Object -Process {

        $NameCurrent    =  $psItem
        $AddressCurrent = "$NameCurrent.$DomainAddress"

        $vm = Get-VM -CimSession $cimSession | Where-Object -FilterScript { 
            $psItem.Name -eq $AddressCurrent
        }

        If
        (
            $vm
        )
        {
            $Message = "Virtual Machine `“$AddressCurrent`” already exists, skipping"
            Write-Message -Channel Verbose -Message $Message
        }
        Else
        {
            $Message = "Deploying `“$AddressCurrent`”"
            Write-Message -Channel Verbose -Message $Message

            $odjPath = Join-Path -Path $env:Temp -ChildPath $AddressCurrent

            $Message = 'Requesting Offline Domain Join'
            Write-Message -Channel Debug -Message $Message

            $dJoin = dJoin.exe /Provision /Domain "$DomainAddress" /Machine "$NameCurrent" /Reuse /PrintBlob /SaveFile $odjPath

            $VirtualHardDiskName = "$AddressCurrent$($Source.Extension)"

            $Message = "Creating differencing disk `“$VirtualHardDiskName`”"
            Write-Message -Channel Debug -Message $Message

            $VirtualHardDiskPath = Join-Path -Path $PathDisk -ChildPath $VirtualHardDiskName

            $VirtualHardDiskParam = @{ 
                
                CimSession   = $cimSession
                Differencing = $True
                ParentPath   = $SourcePathLocal
                Path         = $VirtualHardDiskPath
            }
            $VirtualHardDisk = New-VHD @VirtualHardDiskParam

         <# $VirtualHardDisk = Copy-Item -Path $SourcePath -Destination $PathDisk -PassThru

            $VirtualHardDisk = Rename-Item -Path $VirtualHardDisk.FullName -NewName "$AddressCurrent.vhdx" -PassThru  #>

            $Message = 'Creating answer file'
            Write-Message -Channel Debug -Message $Message

            $AnswerPath = Join-Path -Path $env:Temp -ChildPath "$AddressCurrent.xml"

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
            Write-Message -Channel Debug -Message $Message
            
            $DiskImage = Get-DiskImage -CimSession $cimSession -ImagePath $VirtualHardDisk.Path
        
            $DiskImage = Mount-DiskImage -InputObject $DiskImage -NoDriveLetter -PassThru

            $Disk = Get-Disk -CimSession $cimSession -Number $DiskImage.Number

            Set-Disk -InputObject $Disk -IsOffline $False

            $PartitionBoot   = Get-Partition -Disk $Disk | Where-Object -FilterScript {
                $psItem.Type -eq 'Basic'
            }

         # “Use-WindowsUnattend” requires a drive letter

            If
            (
                $PartitionBoot.AccessPaths.Count -eq 1
            )
            {
                $PartitionBoot   = Add-PartitionAccessPath -InputObject $PartitionBoot   -AssignDriveLetter -PassThru

             # “Add-PartitionAccessPath” does not return an updated objects
                $PartitionBoot   = Get-Partition -Disk $Disk | Where-Object -FilterScript {
                    $psItem.Type -eq 'Basic'
                }
            }

            $PartitionSystem = Get-Partition -Disk $Disk | Where-Object -FilterScript {
                $psItem.Type -eq 'System'
            }

            Copy-Item -ToSession $psSession -Path $AnswerPath -Destination $Path

            $AnswerPathLocal = Join-Path -Path $Path -ChildPath "$AddressCurrent.xml"

            $UnattendParam = @{
                
                UnattendPath = $AnswerPathLocal
                Path         = $PartitionBoot.AccessPaths[0]
            }

            $PathBcd = Join-Path -Path $PartitionSystem.AccessPaths[0] -ChildPath 'Efi\Microsoft\Boot\BCD'
            $PathOs  = $PartitionBoot.AccessPaths[0].TrimEnd( '\' )

            [System.Void]( Invoke-Command -Session $psSession -ScriptBlock {

                Use-WindowsUnattend @using:UnattendParam

                Remove-Item -Path $using:AnswerPathLocal

             <# In case there's another disk with the same ID already mounted
               (that might be typical in native boot scenarios where the host is
                booted from a copy of the same disk), the VM will fail to boot
                with 0xc000000e (A device which does not exist was specified).
                Hence we need to correct the partition reference in BCD  #>

                bcdEdit.exe /Store $using:PathBcd /Set `{Default`}   Device hd_Partition=$using:PathOs
                bcdEdit.exe /Store $using:PathBcd /Set `{Default`} osDevice hd_Partition=$using:PathOs
            } )
    
            $DiskImage = Dismount-DiskImage -InputObject $DiskImage
    
            Remove-Item -Path $AnswerPath
            Remove-Item -Path $odjPath

            $Message = 'Creating virtual machine'
            Write-Message -Channel Debug -Message $Message

          # Creating a VM by 

            $vm = New-vm -CimSession $cimSession -Name $AddressCurrent -vhdPath $VirtualHardDisk.Path -SwitchName 'Ethernet' -Generation 2 -Version $HostCurrent.SupportedVmVersions[-1]

            Set-vmMemory    -vm $vm -DynamicMemoryEnabled $True -MinimumBytes $MinimumBytes -StartupBytes $StartupBytes -MaximumBytes $MaximumBytes
            Set-vmProcessor -vm $vm -Count 4
            Set-vmFirmware  -vm $vm -ConsoleMode None -PauseAfterBootFailure On  # -FirstBootDevice $Drive
            Set-vm          -vm $vm -LockOnDisconnect On -CheckpointType Disabled -BatteryPassthroughEnabled $True -AutomaticCheckpointsEnabled $False

            Get-vmIntegrationService -vm $vm | Where-Object -FilterScript { -not $psItem.Enabled } | Enable-vmIntegrationService

            $Message = 'Starting virtual machine'
            Write-Message -Channel Debug -Message $Message

            If
            (
                Test-Path -Path 'variable:\Cluster'
            )
            {
                $Group = Add-ClusterVirtualMachineRole -InputObject $Cluster -vmId $vm.Id
                $Group = Start-ClusterGroup -InputObject $Group -ChooseBestNode -Verbose:$False

                $HostAddress = Resolve-DnsName -Name $Group.OwnerNode.Name -Verbose:$False -Debug:$False | Sort-Object -Property 'Name' -Unique | Select-Object -First 1 -Property 'Name'
            }
            Else
            {
                Start-vm -vm $vm
            }
        }        

        vmConnect.exe $HostAddress.Name $vm.Name
    }

#endregion Provision