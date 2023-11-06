<#
    Attempt 04. Change `SizeConst` dynamically by fiddling with code with
    PowerShell instead of hardcoding
#>

$typeDefinition = @'
    
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Explicit,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct VirtualDiskInfo04
    {
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 Version;

        [System.Runtime.InteropServices.FieldOffsetAttribute(8)]
        public VirtualDiskInfoParentLocation04 ParentLocation;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct VirtualDiskInfoParentLocation04
    {
        public bool ParentResolved;        //BOOL        
        public char ParentLocationBuffer;  //WCHAR[1]
    }

    public class VirtDisk04
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
              ref VirtualDiskInfo04 VirtualDiskInfo,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              [System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );
    }
'@

$type = Add-Type -PassThru -TypeDefinition $typeDefinition

$VirtualDiskInfo = [VirtualDiskInfo04]::new()
$VirtualDiskInfo.Version = 3  # ParentLocation

[System.UInt32]$VirtualDiskInfoSize = [System.Runtime.InteropServices.Marshal]::SizeOf( $VirtualDiskInfo )

 <# currently the struct is only 16 bytes long, and the function will return
   "The parameter is incorrect" if it's lower than 32  #>
[System.UInt32]$VirtualDiskInfoSize = 32
[System.UInt32]$SizeUsed = $null

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
    [ref]   $VirtualDiskInfo
    [ref]   $SizeUsed
)
$result = [VirtDisk04]::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )

 <# Just like in the previou example, the above will return "The data area
    passed to a system call is too small" and at the same time it will populate
    $VirtualDiskInfoSize with actual size needed. But now instead of manually
    allocating memory we'll change how our struct looks like.  #>

 <# From the previous experiment we know that the size of the struct sans the
    ParentLocationBuffer member is 12 bytes. And each char takes two bytes.  #>
 
$stringLength = ($VirtualDiskInfoSize - 12)/2
$VirtualDiskInfoName               = 'VirtualDiskInfoFor'               + $stringLength
$VirtualDiskInfoParentLocationName = 'VirtualDiskInfoParentLocationFor' + $stringLength
$VirtDiskName                      = 'VirtDiskFor'                      + $stringLength

$typeDefinition = @"
    
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Explicit,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct $VirtualDiskInfoName
    {
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 Version;

        [System.Runtime.InteropServices.FieldOffsetAttribute(8)]
        public $VirtualDiskInfoParentLocationName ParentLocation;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct $VirtualDiskInfoParentLocationName
    {
        public bool ParentResolved;          //BOOL

        [System.Runtime.InteropServices.MarshalAsAttribute(
            System.Runtime.InteropServices.UnmanagedType.ByValArray,
            SizeConst = $stringLength        // no longer a guess!
        )]
        public char[] ParentLocationBuffer;  //WCHAR[1]
    }

    public class $VirtDiskName
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
              ref $VirtualDiskInfoName VirtualDiskInfo,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              [System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );
    }
"@

$type = Add-Type -PassThru -TypeDefinition $typeDefinition

$VirtualDiskInfo = ([System.Type]$VirtualDiskInfoName)::new()
$VirtualDiskInfo.Version = 3  # ParentLocation

[System.UInt32]$VirtualDiskInfoSize = [System.Runtime.InteropServices.Marshal]::SizeOf( $VirtualDiskInfo )
[System.UInt32]$SizeUsed = $null

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
    [ref]   $VirtualDiskInfo
    [ref]   $SizeUsed
)
$result = ([System.Type]$VirtDiskName)::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )

# 24 bytes or 12 symbols at the end are still gibberish
$ParentLocationBufferSize = $VirtualDiskInfo.ParentLocation.ParentLocationBuffer.Length - 13

$ParentLocation = [System.String]::new( $VirtualDiskInfo.ParentLocation.ParentLocationBuffer[0..$ParentLocationBufferSize] )

$ParentLocation = $ParentLocation.Split( "`0" )

return $ParentLocation

# just in case
$ParentLocationExtra = $VirtualDiskInfo.ParentLocation.ParentLocationBuffer[($ParentLocationBufferSize+1)..($ParentLocationBufferSize+12)]