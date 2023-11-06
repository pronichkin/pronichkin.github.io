<#
    Attempt 20. An idea about variable SizeConst.
    Note: this won't compile.
#>

$typeDefinition = @'
    
    public class Test20
    {
        System.Int32 Length = 2048;  // could be a parameter

        [System.Runtime.InteropServices.StructLayoutAttribute(
            System.Runtime.InteropServices.LayoutKind.Explicit,
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            Pack    = 4
        )]
        public struct VirtualDiskInfo20
        {
            [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
            public System.UInt32 Version;

            [System.Runtime.InteropServices.FieldOffsetAttribute(8)]
            public VirtualDiskInfoParentLocation20 ParentLocation;
        }

        [System.Runtime.InteropServices.StructLayoutAttribute(
            System.Runtime.InteropServices.LayoutKind.Sequential,
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            Pack    = 4
        )]
        public struct VirtualDiskInfoParentLocation20
        {
            public bool ParentResolved;          //BOOL

            [System.Runtime.InteropServices.MarshalAsAttribute(
                System.Runtime.InteropServices.UnmanagedType.ByValArray,
                SizeConst = Length               // This could be variable
            )]
            public char[] ParentLocationBuffer;  //WCHAR[1]
        }
    }

    public class VirtDisk20
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
              ref Test20.VirtualDiskInfo20 VirtualDiskInfo,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              [System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );
    }
'@

$type = Add-Type -PassThru -TypeDefinition $typeDefinition

$VirtualDiskInfo = [VirtualDiskInfo20]::new()
$VirtualDiskInfo.Version = 3  # ParentLocation

[System.UInt32]$VirtualDiskInfoSize = [System.Runtime.InteropServices.Marshal]::SizeOf( $VirtualDiskInfo )
[System.UInt32]$SizeUsed = $null

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
    [ref]   $VirtualDiskInfo
    [ref]   $SizeUsed
)
$result = [VirtDisk20]::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )

if
(
    $result
)
{
    throw [System.ComponentModel.Win32Exception]::new( [System.Int32]$result )
}
else
{
    Write-Verbose -Message 'GetVirtualDiskInformation success'
}

# this is not useful anymore since it's just an array of chars, not a few strings as we'd expect
$ParentLocation = $VirtualDiskInfo.ParentLocation.ParentLocationBuffer

# now we need to construct a string from those chars
$ParentLocation = [System.String]::new( $VirtualDiskInfo.ParentLocation.ParentLocationBuffer )

# unfortunately now all the values are in one string, so we need to split them
$ParentLocation = $ParentLocation.Split( "`0", [System.StringSplitOptions]::RemoveEmptyEntries )

return $ParentLocation