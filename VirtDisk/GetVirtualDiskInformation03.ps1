<#
    Attempt 03. Allocate memory and marshal it manually.
#>

$typeDefinition = @'
    
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Explicit,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct VirtualDiskInfo03
    {
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 Version;

        [System.Runtime.InteropServices.FieldOffsetAttribute(8)]
        public VirtualDiskInfoParentLocation03 ParentLocation;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct VirtualDiskInfoParentLocation03
    {
        public bool ParentResolved;        //BOOL        
        public char ParentLocationBuffer;  //WCHAR[1]
    }

    public class VirtDisk03
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
              ref VirtualDiskInfo03 VirtualDiskInfo,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              [System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );
    }
'@

$type = Add-Type -PassThru -TypeDefinition $typeDefinition

$VirtualDiskInfo = [VirtualDiskInfo03]::new()
$VirtualDiskInfo.Version = 3  # ParentLocation

[System.UInt32] $VirtualDiskInfoSize = [System.Runtime.InteropServices.Marshal]::SizeOf( $VirtualDiskInfo )

 <# currently the struct is only 16 bytes long, and the function will return
   “The parameter is incorrect” if it's lower than 32  #>
[System.UInt32] $VirtualDiskInfoSize = 32
[System.UInt32] $SizeUsed = $null

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
    [ref]   $VirtualDiskInfo
    [ref]   $SizeUsed
)
$result = [VirtDisk03]::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )

 <# The above will return “The data area passed to a system call is too small”
    but at the same time it will populate $VirtualDiskInfoSize with actual size
    needed. So now we can allocate exactly the right amount of memory.
 #>

[System.IntPtr] $VirtualDiskInfoRaw = [System.Runtime.InteropServices.Marshal]::AllocHGlobal( $VirtualDiskInfoSize )
[System.Runtime.InteropServices.Marshal]::StructureToPtr( $VirtualDiskInfo, $VirtualDiskInfoRaw, $true )

# But now we can redefine our function so that it consumes a pointer instead of ref

$typeDefinition = @'
    
    public class VirtDisk03withPtr
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
              System.IntPtr VirtualDiskInfo,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              [System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );
    }
'@

$type = Add-Type -PassThru -TypeDefinition $typeDefinition

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
            $VirtualDiskInfoRaw  # this is no longer a ref but rather a pointer
    [ref]   $SizeUsed
)
$result = [VirtDisk03withPtr]::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )

$VirtualDiskInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure( $VirtualDiskInfoRaw, [System.Type][VirtualDiskInfo03] )

 <# The above is almost pointless. It can be used to inspect `ParentResolved`
    but `ParentLocationBuffer` is trimmed to the first character only because
    this is how the struct has to be defined without knowing the size upfront.

    But now that we have raw memory, we can marshal it manually to extract some
    meaningful output.  #>

[System.Int64]  $offsetToParentLocation       = [System.Runtime.InteropServices.Marshal]::OffsetOf( [VirtualDiskInfo03],               'ParentLocation'       )
[System.Int64]  $offsetToParentLocationBuffer = [System.Runtime.InteropServices.Marshal]::OffsetOf( [VirtualDiskInfoParentLocation03], 'ParentLocationBuffer' )
[System.IntPtr] $ParentLocationBufferRaw      = $VirtualDiskInfoRaw + $offsetToParentLocation + $offsetToParentLocationBuffer

 <# Regardless of the output size in different cases, there are 24 bytes at the
    end of `ParentLocationBuffer` which seem to be never used, although allocated.
    Four of them are double \0 characters to signify the end of MULTI_SZ. But
    what are the 20 extra? Beats me.  #>

$ParentLocationBufferSize = $VirtualDiskInfoSize - $offsetToParentLocation - $offsetToParentLocationBuffer - 24

$ParentLocationBuffer = 0..($ParentLocationBufferSize-1) | ForEach-Object -Process {
    [System.Runtime.InteropServices.Marshal]::ReadByte( $ParentLocationBufferRaw, $psItem )
}

$ParentLocationString = [System.Text.UnicodeEncoding]::Unicode.GetString( $ParentLocationBuffer )

 <# Note that unlike the previous examples, there's no longer the need to trim
    extra whitespace since we allocated (and marshalled) the exact amount of
    memory instead of guessing and overprovisioning.  #>

$ParentLocation       = $ParentLocationString.Split( "`0" )

return $ParentLocation

 <# Just in case. Those are sometimes zeros and sometimes gibberish in those
    24 bytes at the end.  #>

$ParentLocationExtra = $ParentLocationBufferSize..($ParentLocationBufferSize+23) | ForEach-Object -Process {
    [System.Runtime.InteropServices.Marshal]::ReadByte( $ParentLocationBufferRaw, $psItem )
}

[System.Runtime.InteropServices.Marshal]::FreeHGlobal( $VirtualDiskInfoRaw )