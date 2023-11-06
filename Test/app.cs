using System;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Security.Permissions;
using System.Text;

namespace ConsoleApplication1
{
    class Program
    {
        public static Guid VirtualStorageTypeVendorMicrosoft = new Guid("EC984AEC-A0F9-47e9-901F-71415A66345B");

        static void Main(string[] args)
        {
            var handle = new VirtualDiskSafeHandle();
            var storageType = new VirtualStorageType
            {
                DeviceId = VirtualStorageDeviceType.Vhdx,
                VendorId = VirtualStorageTypeVendorMicrosoft
            };

            var parameters = new OpenVirtualDiskParameters
            {
                Version = OpenVirtualDiskVersion.Version2
            };

            var result = OpenVirtualDisk(ref storageType, @"C:\Image\vhdx_server_serverdatacentercore_ac_en-us_vl\25398.1.amd64fre.zn_release.230610-1204_server_serverdatacentercore_ac_en-us_vl.vhdx", VirtualDiskAccessMask.None, OpenVirtualDiskFlag.None,
                ref parameters, ref handle);

            if (result != 0)
            {
                throw new Win32Exception((int)result);
            }

            IntPtr raw = Marshal.AllocHGlobal(1024);
            // This is the GetVirtualDiskInfo from your provided code.
            GetVirtualDiskInfo info = new GetVirtualDiskInfo { Version = GetVirtualDiskInfoVersion.ParentLocation };
            Marshal.StructureToPtr(info, raw, true);

            var infoSize = (uint)80;//Marshal.SizeOf(info);
            uint sizeUsed = 0;

            result = GetVirtualDiskInformation(handle, ref infoSize, raw, ref sizeUsed);

            if (result != 0)
            {
                throw new Win32Exception((int)result);
            }

            IntPtr offsetToUnion = Marshal.OffsetOf(typeof(GetVirtualDiskInfo), "Union");
            IntPtr data = raw + offsetToUnion.ToInt32();

            bool parentResolved = Marshal.ReadInt32(data) != 0;
            string parentLocationBuffer = Marshal.PtrToStringUni(data + 4);

            Console.WriteLine(parentResolved);
            Console.WriteLine(parentLocationBuffer);
            Console.WriteLine(sizeUsed);
            Console.ReadLine();

            Marshal.FreeHGlobal(raw)
        }

        [DllImport("virtdisk.dll", CharSet = CharSet.Unicode)]
        public static extern uint OpenVirtualDisk(
            [In] ref VirtualStorageType virtualStorageType,
            [In] string path,
            [In] VirtualDiskAccessMask virtualDiskAccessMask,
            [In] OpenVirtualDiskFlag flags,
            [In] ref OpenVirtualDiskParameters parameters,
            [In, Out] ref VirtualDiskSafeHandle handle);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(
            [In] IntPtr hObject);

        [DllImport("virtdisk.dll", CharSet = CharSet.Unicode)]
        public static extern uint GetVirtualDiskInformation(
                VirtualDiskSafeHandle virtualDiskHandle,
            ref uint virtualDiskInfoSize,
            IntPtr virtualDiskInfo,
            ref uint sizeUsed);

        [SecurityPermission(SecurityAction.Demand)]
        public class VirtualDiskSafeHandle : SafeHandle
        {
            public VirtualDiskSafeHandle() : base(IntPtr.Zero, true) { }

            public override bool IsInvalid => IsClosed || (handle == IntPtr.Zero);

            public bool IsOpen => !IsInvalid;

            protected override bool ReleaseHandle()
            {
                return CloseHandle(handle);
            }

            public override string ToString()
            {
                return handle.ToString();
            }
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct OpenVirtualDiskParameters
        {
            public OpenVirtualDiskVersion Version; //OPEN_VIRTUAL_DISK_VERSION
            public OpenVirtualDiskParametersUnion Union;
        }

        [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
        public struct OpenVirtualDiskParametersUnion
        {
            [FieldOffset(0)]
            public OpenVirtualDiskParametersVersion1 Version1;

            [FieldOffset(0)]
            public OpenVirtualDiskParametersVersion2 Version2;

            [FieldOffset(0)]
            public OpenVirtualDiskParametersVersion3 Version3;
        }

        /// <summary>
        /// </summary>
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct OpenVirtualDiskParametersVersion1
        {
            public uint RWDepth; //ULONG
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct OpenVirtualDiskParametersVersion2
        {
            public bool GetInfoOnly; //BOOL
            public bool ReadOnly; //BOOL
            public Guid ResiliencyGuid; //GUID
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct OpenVirtualDiskParametersVersion3
        {
            public bool GetInfoOnly; //BOOL
            public bool ReadOnly; //BOOL
            public Guid ResiliencyGuid; //GUID
            public Guid SnapshotId; //GUID
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct GetVirtualDiskInfo
        {
            public GetVirtualDiskInfoVersion Version; //GET_VIRTUAL_DISK_INFO_VERSION
            public GetVirtualDiskInfoUnion Union;
        }

        [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
        public struct GetVirtualDiskInfoUnion
        {
            [FieldOffset(0)] public GetVirtualDiskInfoSize Size;
            [FieldOffset(0)] public Guid Identifier; //GUID
            [FieldOffset(0)] public GetVirtualDiskInfoParentLocation ParentLocation;
            [FieldOffset(0)] public Guid ParentIdentifier; //GUID
            [FieldOffset(0)] public uint ParentTimestamp; //ULONG
            [FieldOffset(0)] public VirtualStorageType VirtualStorageType; //VIRTUAL_STORAGE_TYPE
            [FieldOffset(0)] public uint ProviderSubtype; //ULONG
            [FieldOffset(0)] public bool Is4kAligned; //BOOL
            [FieldOffset(0)] public bool IsLoaded; //BOOL
            [FieldOffset(0)] public GetVirtualDiskInfoPhysicalDisk PhysicalDisk;
            [FieldOffset(0)] public uint VhdPhysicalSectorSize; //ULONG
            [FieldOffset(0)] public ulong SmallestSafeVirtualSize; //ULONGLONG
            [FieldOffset(0)] public uint FragmentationPercentage; //ULONG
            [FieldOffset(0)] public Guid VirtualDiskId; //GUID
            //[FieldOffset(0)] public GetVirtualDiskInfoChangeTrackingState ChangeTrackingState;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct GetVirtualDiskInfoSize
        {
            public ulong VirtualSize; //ULONGLONG
            public ulong PhysicalSize; //ULONGLONG
            public uint BlockSize; //ULONG
            public uint SectorSize; //ULONG
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct GetVirtualDiskInfoParentLocation
        {
            public bool ParentResolved; //BOOL
            public IntPtr ParentLocationBuffer; //WCHAR[1]
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct GetVirtualDiskInfoPhysicalDisk
        {
            public uint LogicalSectorSize; //ULONG
            public uint PhysicalSectorSize; //ULONG
            public bool IsRemote; //BOOL
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct GetVirtualDiskInfoChangeTrackingState
        {
            public bool Enabled; //BOOL
            public bool NewerChanges; //BOOL
            public IntPtr MostRecentId; //WCHAR[1]
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct VirtualStorageType
        {
            public VirtualStorageDeviceType DeviceId; //ULONG
            public Guid VendorId; //GUID
        }

        public enum GetVirtualDiskInfoVersion
        {
            Unspecified = 0,
            Size = 1,
            Identifier = 2,
            ParentLocation = 3,
            ParentIdentifier = 4,
            ParentTimestamp = 5,
            VirtualStorageType = 6,
            ProviderSubtype = 7,
            Is4KAligned = 8,
            PhysicalDisk = 9,
            VhdPhysicalSectorSize = 10,
            SmallestSafeVirtualSize = 11,
            Fragmentation = 12,
            IsLoaded = 13,
            VirtualDiskId = 14,
            ChangeTrackingState = 15
        }

        public enum VirtualStorageDeviceType
        {
            Unknown = 0,
            Iso = 1,
            Vhd = 2,
            Vhdx = 3,
            Vhdset = 4
        }

        public enum VirtualDiskAccessMask
        {
            None = 0x00000000,
            AttachRo = 0x00010000,
            AttachRw = 0x00020000,
            Detach = 0x00040000,
            GetInfo = 0x00080000,
            Create = 0x00100000,
            Metaops = 0x00200000,
            Read = 0x000d0000,
            All = 0x003f0000,
            Writable = 0x00320000
        }

        [Flags]
        public enum OpenVirtualDiskFlag
        {
            None = 0x00000000,
            NoParents = 0x00000001,
            BlankFile = 0x00000002,
            BootDrive = 0x00000004,
            CachedIo = 0x00000008,
            CustomDiffChain = 0x00000010,
            ParentCachedIo = 0x00000020,
            VhdsetFileOnly = 0x00000040
        }

        public enum OpenVirtualDiskVersion
        {
            Unspecified = 0,
            Version1 = 1,
            Version2 = 2,
            Version3 = 3,
        }
    }
}