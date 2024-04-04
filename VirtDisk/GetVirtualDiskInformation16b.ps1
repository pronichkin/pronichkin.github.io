<#
    Attempt 16h. Fixed buffer
    Note: this will not crash but it's unclear how to interpret the results
#>

$typeDefinition = @'

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Explicit,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public struct VirtualDiskInfo16h
    {
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 Version;

        [System.Runtime.InteropServices.FieldOffsetAttribute(8)]
        public VirtualDiskInfoParentLocation16h ParentLocation;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode,
        Pack    = 4
    )]
    public unsafe struct VirtualDiskInfoParentLocation16h
    {
        public       bool   ParentResolved;
     // public fixed char   ParentLocationBuffer [2048];
        public fixed byte   ParentLocationBuffer [4096];
     // public       Blob16h   ParentLocationBuffer;

     /* public char read
        (
            int  index
        )
        {
            fixed
            (
                char* charPtr = this.ParentLocationBuffer
            )
            {
                return charPtr[index];
            }
        }

        public void write
        (
            int  index,
            char value
        )
        {
            fixed
            (
                char* charPtr = this.ParentLocationBuffer
            )
            {
                charPtr[index] = value;
            }
        }   */
    }

    public class VirtDisk16h
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
              ref VirtualDiskInfo16h VirtualDiskInfo,

              [System.Runtime.InteropServices.InAttribute]
              [System.Runtime.InteropServices.OutAttribute]
              [System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );

     /* [System.Runtime.InteropServices.DllImportAttribute(
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
        );  */

     /* public static void AccessEmbeddedArray
        (
            VirtualDiskInfoParentLocation16h ParentLocation
        )
        {
            unsafe
            {
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[0].ToString());
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[1].ToString());
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[2].ToString()); 
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[3].ToString()); 
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[4].ToString()); 
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[5].ToString()); 
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[6].ToString()); 
                System.Console.WriteLine(ParentLocation.ParentLocationBuffer[7].ToString()); 
            }
        }  */
    }
'@

$CompilerParameter = [CodeDom.Compiler.CompilerParameters]::new()
$CompilerParameter.CompilerOptions = '/unsafe'

$type = Add-Type -PassThru -TypeDefinition $typeDefinition -CompilerParameters $CompilerParameter

$VirtualDiskInfo = [VirtualDiskInfo16h]::new()
$VirtualDiskInfo.Version = 3  # ParentLocation

 <# Note that the total size of the struct appears to be enough now.  #>

[System.UInt32]$VirtualDiskInfoSize = [System.Runtime.InteropServices.Marshal]::SizeOf( $VirtualDiskInfo )
[System.UInt32]$SizeUsed = $null

$getVirtualDiskInformationParam = @(
            $handle # VirtualDiskHandle
    [ref]   $VirtualDiskInfoSize
    [ref]   $VirtualDiskInfo
  #         $VirtualDiskInfo
    [ref]   $SizeUsed
)
$result = [VirtDisk16h]::GetVirtualDiskInformation.Invoke( $getVirtualDiskInformationParam )

 <# This is a quick and dirty way to extract first 8 characters from the array.
    But in our case it only returns the first character correctly and a bunch of
    whitespace after it  #>

[VirtDisk16h]::AccessEmbeddedArray( $VirtualDiskInfo.ParentLocation )

 <# This is supposedly the same but with marshaling. It also returns only the code
    of the first characater and a bunch of nulls after it  #>

0..16 | ForEach-Object -Process {
    [System.Runtime.InteropServices.Marshal]::ReadByte( $VirtualDiskInfo.ParentLocation.ParentLocationBuffer, $psItem )
}