 // https://microsoft.visualstudio.com/OS/_git/os.2020?path=/minkernel/published/base/ntrtlstringandbuffer.w&_a=contents&version=GBofficial/main

namespace DatacenterAdvancedAutomation.psbcd
{
    public static class bcd01
    {
        [System.Runtime.InteropServices.StructLayoutAttribute(
            System.Runtime.InteropServices.LayoutKind.Sequential
        )]
        public struct BCDE_DEVICE_TYPE_PARTITION
        {
            public  System.UInt32       DeviceType;         // ULONG
            public  System.Guid         AdditionalOptions;
         // [System.Runtime.InteropServices.MarshalAsAttribute(
         //     System.Runtime.InteropServices.UnmanagedType.ByValArray,
         //     SizeConst = 1
            public  byte[]              Path;               //             WCHAR Path[ANYSIZE_ARRAY];
        }
    }
}