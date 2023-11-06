 <#
    This is a very simplified example of using `OpenVirtualDisk` in PowerShell.
    It serves no illustrational purpose and is only needed as a prerequisite for
    the subsequent steps.

    https://learn.microsoft.com/windows/win32/api/virtdisk/nf-virtdisk-openvirtualdisk
#>

$path = 'C:\Image\Child.vhdx'

$typeDefinition = @'

    public struct VirtualStorageType
    {
        public System.UInt32 DeviceId;  //ULONG
        public System.Guid   VendorId;  //GUID
    }

    public struct OpenVirtualDiskParameters
    {
        public System.UInt32 Version;        //OPEN_VIRTUAL_DISK_VERSION
        public bool          GetInfoOnly;    //BOOL
        public bool          ReadOnly;       //BOOL
        public System.Guid   ResiliencyGuid; //GUID 
    }

    public class VirtDisk00
    {
        [System.Runtime.InteropServices.DllImportAttribute(
            "VirtDisk.dll",
            CharSet           = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling     = true,
            SetLastError      = true,
            CallingConvention = System.Runtime.InteropServices.CallingConvention.StdCall
        )]

        public static extern System.UInt32
            OpenVirtualDisk(
              [System.Runtime.InteropServices.InAttribute()]
              [System.Runtime.InteropServices.OutAttribute()]
              ref VirtualStorageType VirtualStorageType,

              [System.Runtime.InteropServices.InAttribute()]
              [System.Runtime.InteropServices.MarshalAsAttribute(
                System.Runtime.InteropServices.UnmanagedType.LPWStr
              )]
              System.String Path,

              [System.Runtime.InteropServices.InAttribute()]
              System.UInt32 VirtualDiskAccessMask,

              [System.Runtime.InteropServices.InAttribute()]
              System.UInt32 Flags,

              [System.Runtime.InteropServices.InAttribute()]
              [System.Runtime.InteropServices.OutAttribute()]
              [System.Runtime.InteropServices.OptionalAttribute()]
              ref OpenVirtualDiskParameters Parameters,

              [System.Runtime.InteropServices.OutAttribute()]
              out Microsoft.Win32.SafeHandles.SafeFileHandle Handle
            );
    }
'@

$type = Add-Type -PassThru -TypeDefinition $typeDefinition

# creating the mininum necessary structures

$VirtualStorageType = [VirtualStorageType]::new()
$VirtualStorageType.DeviceId = 3                                       # VHDX
$VirtualStorageType.VendorId = 'EC984AEC-A0F9-47e9-901F-71415A66345B'  # Microsoft

$OpenVirtualDiskParameters = [OpenVirtualDiskParameters]::new()
$OpenVirtualDiskParameters.Version = 2

$handleParam = @(
    [System.IntPtr]::Zero  # preexistingHandle  An IntPtr object that represents the pre-existing handle to use.
    $true                  # ownsHandle
)
$handle = [Microsoft.Win32.SafeHandles.SafeFileHandle]::new.Invoke( $handleParam )

$openVirtualDiskParam = @(
    [ref]   $VirtualStorageType
            $path
            0      # VirtualDiskAccessMask = None
            1      # OpenVirtualDiskFlags  = No parents (to read broken chain)
    [ref]   $OpenVirtualDiskParameters
    [ref]   $handle
)
$result = [VirtDisk00]::OpenVirtualDisk.Invoke( $openVirtualDiskParam )

if
(
    $result
)
{
    if
    (
        $handle.IsClosed
    )
    {}
    else
    {
        $handle.Close()
    }

    throw [System.ComponentModel.Win32Exception]::new( [System.Int32]$result )
}
else
{
    Write-Verbose -Message 'OpenVirtualDisk success'
}