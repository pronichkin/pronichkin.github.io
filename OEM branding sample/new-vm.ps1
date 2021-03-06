  # $Name      = 'Proseware HCI'
  # $Name      = 'ArtemP-RS5ru'
  # $Name      = 'ArtemP-RS5fr'
  # $Name      = 'ArtemP-RS5de'
  # $Name      = 'ArtemP-RS5it'
  # $Name      = 'ArtemP-RS5es'
  # $Name      = 'ArtemP-RS5cn'
  # $Name      = 'ArtemP-RS5ja'
  # $Name      = 'ArtemP-RS1-01'
  # $Name      = 'ArtemP-RS5ja01'
  # $Name      = 'ArtemP-RS5cl01'
  # $Name      = 'ArtemP-RS5en01'
    $Name      = 'ArtemP-RS5fr01'

  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso'
  # $ImagePath = 'D:\Image\SW_DVD9_Win_Server_STD_CORE_2019_1809.2_64Bit_English_DC_STD_MLF_X22-18452.ISO'
  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_ru-ru_1.iso'
    $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_fr-fr_1.iso'
  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_de-de_1.iso'
  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_it-it_1.iso'
  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_es-es_1.iso'
  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_zh-cn_1.iso'
  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_ja-jp_1.iso'
  # $ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_EN-US_1.iso'
  # $ImagePath = 'D:\Image\Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO'
  # $ImagePath = 'D:\Image\17763.107.101029-1455.rs5_release_svc_refresh_CLIENT_LTSC_EVAL_x64FRE_en-us.iso'

    $Path      = 'D:\Virtual Machine'

$vm = Get-vm | Where-Object -FilterScript {
    $psItem.Name -eq $Name
}

If
(
    $vm
)
{
    $Message = "Virtual Machine `“$Name`” already exists"
    Write-Verbose -Message $Message
}
Else
{
    $Message = "Creating Virtual Machine `“$Name`”"
    Write-Verbose -Message $Message

    $vm = New-vm -Name $Name -SwitchName 'Ethernet' -Path $Path -Version ( [System.Version]9.2 ) -Generation 2
}

$Drive = Get-vmDvdDrive -vm $vm | Where-Object -FilterScript {
    $psItem.Path -eq $ImagePath
}

If
(
    $Drive
)
{
    $Message = "Image `“$ImagePath`” is already attached"
    Write-Verbose -Message $Message
}
Else
{
    $Drive = Add-vmDvdDrive -vm $vm -Path $ImagePath -Passthru
}

Set-vmProcessor -vm $vm -Count 4
Set-vmMemory    -vm $vm -DynamicMemoryEnabled $True -MaximumBytes 8gb -StartupBytes 2gb
Set-vmFirmware  -vm $vm -ConsoleMode None -PauseAfterBootFailure On -FirstBootDevice $Drive
Set-vm -vm $vm -LockOnDisconnect On -CheckpointType Disabled -BatteryPassthroughEnabled $True -AutomaticCheckpointsEnabled $False

$DiskPath = Join-Path -Path $Path -ChildPath "$Name.vhdx"

$Drive = Get-vmHardDiskDrive -vm $vm | Where-Object -FilterScript {
    $psItem.Path -eq $DiskPath
}

If
(
    $Drive
)
{
    $Message = "Drive `“$DiskPath`” is already attached"
    Write-Verbose -Message $Message
}
Else
{
    $Disk = New-VHD -Path $DiskPath -SizeBytes 16gb -Dynamic
    Add-vmHardDiskDrive -vm $vm -Path $Disk.Path
}

$ImagePath = Join-Path -Path $Path -ChildPath "$Name.iso"

$Drive = Get-vmDvdDrive -vm $vm | Where-Object -FilterScript {
    $psItem.Path -eq $ImagePath
}

If
(
    $Drive
)
{
    $Message = "Image `“$ImagePath`” is already attached"
    Write-Verbose -Message $Message
}
Else
{
    $Directory = New-Item -Path $Path -Name 'Answer' -ItemType 'Directory'

    $AnswerPath = Join-Path -Path $Directory.FullName -ChildPath 'Unattend.xml'

    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
    <!--  Sample Answer file to demonstrate the usage of “OEMInformation” directive
          Last edit 2020-01-24 by Artem Pronichkin
          For explanation please see https://pronichkin.com -->
    <unattend xmlns="urn:schemas-microsoft-com:unattend">
      <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"  >
          <OEMInformation>
            <SupportProvider>$Name</SupportProvider>
          </OEMInformation>
        </component>
      </settings>
    </unattend>
"@

    $xmlDocument = [System.Xml.XmlDocument]::new()
    $xmlDocument.LoadXml( $xml )
    $xmlDocument.Save( $AnswerPath )

    [System.Void](
        & 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe' -u1 -udfver102 $Directory.FullName $ImagePath
    )

    Remove-Item -Path $Directory.FullName -Confirm:$False -Recurse

    Add-vmDvdDrive -vm $vm -Path $ImagePath
}

Start-vm -vm $vm

vmConnect.exe LocalHost $name