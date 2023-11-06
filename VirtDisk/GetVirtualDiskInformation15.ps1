<#
    Attempt 15. Pre-fill the array using the default constructor
    Note: this will crash
#>

$typeDefinition = @'
    
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Explicit,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct VirtualDiskInfo15
    {
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 Version;

        [System.Runtime.InteropServices.FieldOffsetAttribute(8)]
        public VirtualDiskInfoParentLocation15 ParentLocation;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct VirtualDiskInfoParentLocation15
    {
        public bool     ParentResolved;
        public char[]   ParentLocationBuffer;

        public VirtualDiskInfoParentLocation15 ( System.Object bogus )
        {
            ParentResolved       = false;
            ParentLocationBuffer = new char [2048];        
        }
    }

    public class VirtDisk15
    {
        [System.Runtime.InteropServices.DllImportAttribute(
            "VirtDisk.dll",
            CharSet           = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling     = true,
            SetLastError      = true,
            CallingConvention = System.Runtime.InteropServices.CallingConvention.StdCall
        )]       
        
        public static extern System.UInt32
            GetVirtualDiskInformation(
              [System.Runtime.InteropServices.InAttribute]
              Microsoft.Win32.SafeHandles.SafeFileHandle Handle,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              ref System.UInt32 VirtualDiskInfoSize,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              ref VirtualDiskInfo15 VirtualDiskInfo,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              [System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );
    }
'@

$type = Add-Type -PassThru -TypeDefinition $typeDefinition

$VirtualDiskInfo = [VirtualDiskInfo15]::new()
$VirtualDiskInfo.Version = 3  # ParentLocation

 <# This will output 20 which is clearly not enough memory for proper output
    [System.Runtime.InteropServices.Marshal]::SizeOf( $VirtualDiskInfo )
  #>

[System.UInt32]$VirtualDiskInfoSize = 32
[System.UInt32]$SizeUsed = $null

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
    [ref]   $VirtualDiskInfo
    [ref]   $SizeUsed
)
$result = [VirtDisk15]::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )

 <# Running this for the first time will return “The data area passed to a system
    call is too small.” However, it will adjust the value of $VirtualDiskInfoSize
   (without doing anything to the size of the struct.) And therefore, running
    this again will crash.  #>

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
    [ref]   $VirtualDiskInfo
    [ref]   $SizeUsed
)
$result = [VirtDisk15]::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )