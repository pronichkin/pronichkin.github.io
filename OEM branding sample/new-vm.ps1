$Name      = 'Contoso HCI'
$Path      = 'D:\Virtual Machine'
$ImagePath = 'D:\Image\17763.737.190906-2324.rs5_release_svc_refresh_SERVERHYPERCORE_OEM_x64FRE_en-us_1.iso'

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