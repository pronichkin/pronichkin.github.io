namespace DatacenterAdvancedAutomation.Storage
{
    #region    enum

    /// <summary>
    /// Contains the type and provider (vendor) of the virtual storage device.
    /// </summary>
    public enum VirtualStorageDeviceType : int
    {
        /// <summary>
        /// The storage type is unknown or not valid.
        /// </summary>
        Unknown = 0x00000000,
        /// <summary>
        /// For internal use only.  This type is not supported.
        /// </summary>
        ISO = 0x00000001,
        /// <summary>
        /// Virtual Hard Disk device type.
        /// </summary>
        VHD = 0x00000002,
        /// <summary>
        /// Virtual Hard Disk v2 device type.
        /// </summary>
        VHDX = 0x00000003,
        /// <summary>
        /// Virtual Hard Disk Set device type.
        /// </summary>
        VHDS = 0x00000004
    }

    /// <summary>
    /// https://learn.microsoft.com/windows/win32/api/virtdisk/ne-virtdisk-open_virtual_disk_version
    /// OPEN_VIRTUAL_DISK_VERSION
    /// Contains the version of the virtual disk OPEN_VIRTUAL_DISK_PARAMETERS
    /// structure to use in calls to virtual disk functions.
    /// </summary>
    public enum OpenVirtualDiskVersion : int
    {
        VersionUnspecified = 0x00000000,
        Version1 = 0x00000001,
        Version2 = 0x00000002,
        Version3 = 0x00000003,
        Version4 = 0x00000004
    }

    /// <summary>
    /// https://msdn.microsoft.com/library/windows/desktop/dd323662
    /// CREATE_VIRTUAL_DISK_VERSION
    /// Indicates the version of the virtual disk to create.
    /// Contains the version of the virtual disk CREATE_VIRTUAL_DISK_PARAMETERS
    /// structure to use in calls to virtual disk functions.
    /// </summary>
    public enum CreateVirtualDiskVersion : int
    {
        VersionUnspecified = 0x00000000,
        Version1 = 0x00000001,
        Version2 = 0x00000002,
        Version3 = 0x00000003,
        Version4 = 0x00000004
    }

    /// <summary>
    /// https://learn.microsoft.com/windows/win32/api/virtdisk/ne-virtdisk-get_virtual_disk_info_version
    /// GET_VIRTUAL_DISK_INFO_VERSION 
    /// Contains the kinds of virtual hard disk (VHD) information that you can
    /// retrieve
    /// </summary>
    public enum GetVirtualDiskInfoVersion : int
    {
        Unspecified = 0x00000000,
        Size = 0x00000001,
        Identifier = 0x00000002,
        ParentLocation = 0x00000003,
        ParentIdentifier = 0x00000004,
        ParentTimestamp = 0x00000005,
        VirtualStorageType = 0x00000006,
        ProviderSubtype = 0x00000007,
        Is4KAligned = 0x00000008,
        PhysicalDisk = 0x00000009,
        VhdPhysicalSectorSize = 0x0000000A,
        SmallestSafeVirtualSize = 0x0000000B,
        Fragmentation = 0x0000000C,
        IsLoaded = 0x0000000D,
        VirtualDiskId = 0x0000000E,
        ChangeTrackingState = 0x0000000F
    }

    #endregion enum

    #region    flag

    /// <summary>
    /// Contains the bit mask for specifying access rights to a virtual hard
    /// disk (VHD)
    /// https://learn.microsoft.com/windows/win32/api/virtdisk/ne-virtdisk-virtual_disk_access_mask-r1
    /// </summary>
    [System.FlagsAttribute]
    public enum VirtualDiskAccessMask
    {
        /// <summary>
        /// Only Version2 of OpenVirtualDisk API accepts this parameter
        /// </summary>
        None = 0x00000000,
        /// <summary>
        /// Open the virtual disk for read-only attach access. The caller must
        /// have READ access to the virtual disk image file.
        /// </summary>
        /// <remarks>
        /// If used in a request to open a virtual disk that is already open,
        /// the other handles must be limited to either
        /// VIRTUAL_DISK_ACCESS_DETACH or VIRTUAL_DISK_ACCESS_GET_INFO access,
        /// otherwise the open request with this flag will fail.
        /// </remarks>
        AttachReadOnly = 0x00010000,
        /// <summary>
        /// Open the virtual disk for read-write attaching access. The caller
        /// must have (READ | WRITE) access to the virtual disk image file.
        /// </summary>
        /// <remarks>
        /// If used in a request to open a virtual disk that is already open,
        /// the other handles must be limited to either
        /// VIRTUAL_DISK_ACCESS_DETACH or VIRTUAL_DISK_ACCESS_GET_INFO access,
        /// otherwise the open request with this flag will fail.
        /// If the virtual disk is part of a differencing chain, the disk for
        /// this request cannot be less than the readWriteDepth specified
        /// during the prior open request for that differencing chain.
        /// </remarks>
        AttachReadWrite = 0x00020000,
        /// <summary>
        /// Open the virtual disk to allow detaching of an attached virtual
        /// disk. The caller must have (FILE_READ_ATTRIBUTES | FILE_READ_DATA)
        /// access to the virtual disk image file.
        /// </summary>
        Detach = 0x00040000,
        /// <summary>
        /// Information retrieval access to the virtual disk. The caller must
        /// have READ access to the virtual disk image file.
        /// </summary>
        GetInfo = 0x00080000,
        /// <summary>
        /// Virtual disk creation access.
        /// </summary>
        Create = 0x00100000,
        /// <summary>
        /// Open the virtual disk to perform offline meta-operations. The
        /// caller must have (READ | WRITE) access to the virtual disk image
        /// file, up to readWriteDepth if working with a differencing chain.
        /// </summary>
        /// <remarks>
        /// If the virtual disk is part of a differencing chain, the backing
        /// store (host volume) is opened in RW exclusive mode up to
        /// readWriteDepth.
        /// </remarks>
        MetaOperations = 0x00200000,
        /// <summary>
        /// Reserved.
        /// </summary>
        Read = 0x000D0000,
        /// <summary>
        /// Allows unrestricted access to the virtual disk. The caller must
        /// have unrestricted access rights to the virtual disk image file.
        /// </summary>
        All = 0x003F0000,
        /// <summary>
        /// Reserved.
        /// </summary>
        Writable = 0x00320000
    }

    /// <summary>
    /// Contains virtual hard disk (VHD) open request flags.
    /// https://learn.microsoft.com/windows/win32/api/virtdisk/ne-virtdisk-open_virtual_disk_flag
    /// </summary>
    [System.FlagsAttribute]
    public enum OpenVirtualDiskFlags
    {
        /// <summary>
        /// No flags. Use system defaults.
        /// </summary>
        None = 0x00000000,
        /// <summary>
        /// Open the VHD file (backing store) without opening any
        /// differencing-chain parents. Used to correct broken parent links.
        /// </summary>
        NoParents = 0x00000001,
        /// <summary>
        /// Reserved.
        /// </summary>
        BlankFile = 0x00000002,
        /// <summary>
        /// Reserved.
        /// </summary>
        BootDrive = 0x00000004,
        /// <summary>
        /// Indicates that the virtual disk should be opened in cached mode.
        /// By default the virtual disks are opened using FILE_FLAG_NO_BUFFERING
        /// and FILE_FLAG_WRITE_THROUGH.
        /// </summary>
        CachedIO = 0x00000008,
        /// <summary>
        /// Indicates the VHD file is to be opened without opening any
        /// differencing-chain parents and the parent chain is to be created
        /// manually using the AddVirtualDiskParent function.
        /// </summary>
        CustomDiffChain = 0x00000010,
        ParentCachedIO = 0x00000020,
        VhdSetFileOnly = 0x00000040,
        IgnoreRelativeParentLocator = 0x00000080,
        NoWriteHardening = 0x00000100
    }

    #endregion flag

    #region    struct

    #region    miscellaneous

    /// <summary>
    /// https://msdn.microsoft.com/library/windows/desktop/dd323704
    /// https://learn.microsoft.com/windows/win32/api/virtdisk/ns-virtdisk-virtual_storage_type
    /// VIRTUAL_STORAGE_TYPE
    /// Contains the type and provider (vendor) of the virtual storage device.
    /// </summary>
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct VirtualStorageType
    {
        public VirtualStorageDeviceType DeviceId;  //ULONG
        public System.Guid VendorId;  //GUID
    }

    //[System.Runtime.InteropServices.StructLayoutAttribute(
    //    System.Runtime.InteropServices.LayoutKind.Sequential,
    //    CharSet = System.Runtime.InteropServices.CharSet.Unicode//,
    //                                                            //Pack = 1
    //)]
    //unsafe struct FooStruct
    //struct FooStruct
    //{
    //    //fixed int[64] data;
    //    fixed int[] data;
    //}
    /*
    [StructLayout(LayoutKind.Explicit)]
    unsafe struct headerUnion                  // 2048 bytes in header
    {
        [FieldOffset(0)]
        public fixed byte headerBytes[2048];
        [FieldOffset(0)]
        public int header;
    }
    */

    #endregion miscellaneous

    #region    OpenVirtualDisk

    /// <sumary>
    /// https://learn.microsoft.com/windows/win32/api/virtdisk/ns-virtdisk-open_virtual_disk_parameters
    /// OPEN_VIRTUAL_DISK_PARAMETERS
    /// Contains virtual disk open request parameters
    /// </summary>
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct OpenVirtualDiskParameters
    {
        /// <summary>
        /// A OPEN_VIRTUAL_DISK_VERSION enumeration that specifies the version
        /// of the OPEN_VIRTUAL_DISK_PARAMETERS structure being passed to or
        /// from the virtual hard disk (VHD) functions.
        /// </summary>
        public OpenVirtualDiskVersion Version;   //OPEN_VIRTUAL_DISK_VERSION

        /// <summary>
        /// 
        /// </summary>
        public OpenVirtualDiskParametersUnion Union;

    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Explicit,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct OpenVirtualDiskParametersUnion
    {
        /// <summary>
        /// 
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public OpenVirtualDiskParametersVersion1 Version1;

        /// <summary>
        /// 
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public OpenVirtualDiskParametersVersion2 Version2;

        /// <summary>
        /// 
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public OpenVirtualDiskParametersVersion3 Version3;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct OpenVirtualDiskParametersVersion1
    {
        /// <summary>
        /// 
        /// </summary>
        public System.UInt32 RWDepth;  //ULONG
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct OpenVirtualDiskParametersVersion2
    {
        /// <summary>
        /// If TRUE, indicates the handle is only to be used to get information
        /// on the virtual disk.
        /// </summary>
        public bool GetInfoOnly; //BOOL

        /// <summary>
        /// If TRUE, indicates the file backing store is to be opened as read-only.
        /// </summary>
        public bool ReadOnly; //BOOL

        /// <summary>
        /// Resiliency GUID to specify when opening files.
        /// </summary>
        public System.Guid ResiliencyGuid; //GUID 
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct OpenVirtualDiskParametersVersion3
    {
        /// <summary>
        /// If TRUE, indicates the handle is only to be used to get information
        /// on the virtual disk.
        /// </summary>
        public bool GetInfoOnly; //BOOL

        /// <summary>
        /// If TRUE, indicates the file backing store is to be opened as read-only.
        /// </summary>
        public bool ReadOnly; //BOOL

        /// <summary>
        /// Resiliency GUID to specify when opening files.
        /// </summary>
        public System.Guid ResiliencyGuid; //GUID 

        /// <summary>
        /// 
        /// </summary>
        public System.Guid SnapshotId; //GUID
    }

    #endregion OpenVirtualDisk

    #region    GetVirtualDiskInfo

    /// <summary>
    /// https://learn.microsoft.com/windows/win32/api/virtdisk/ns-virtdisk-get_virtual_disk_info
    /// GET_VIRTUAL_DISK_INFO
    /// Contains virtual hard disk (VHD) information.
    /// </summary>
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct GetVirtualDiskInfo
    {
        /// <summary>
        /// A value of the GET_VIRTUAL_DISK_INFO_VERSION enumeration that specifies
        /// the version of the GET_VIRTUAL_DISK_INFO structure being passed to or
        /// from the virtual disk functions. This determines what parts of this
        /// structure will be used.
        /// </summary>
        public GetVirtualDiskInfoVersion Version; //GET_VIRTUAL_DISK_INFO_VERSION

        /// <summary>
        /// 
        /// </summary>
        public GetVirtualDiskInfoUnion Union;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Explicit,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct GetVirtualDiskInfoUnion
    {
        /// <summary>
        /// A structure with the following members. Set the Version member to
        /// GET_VIRTUAL_DISK_INFO_SIZE.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public GetVirtualDiskInfoSize Size;

        /// <summary>
        /// Unique identifier of the virtual disk. Set the Version member to
        /// GET_VIRTUAL_DISK_INFO_IDENTIFIER.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.Guid Identifier; //GUID

        /// <summary>
        /// A structure with the following members. Set the Version member to
        /// GET_VIRTUAL_DISK_INFO_PARENT_LOCATION.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public GetVirtualDiskInfoParentLocation ParentLocation;

        /// <summary>
        /// Unique identifier of the parent disk backing store. Set the Version
        /// member to GET_VIRTUAL_DISK_INFO_PARENT_IDENTIFIER.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.Guid ParentIdentifier; //GUID

        /// <summary>
        /// Internal time stamp of the parent disk backing store. Set the Version
        /// member to GET_VIRTUAL_DISK_INFO_PARENT_TIMESTAMP.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 ParentTimestamp; //ULONG

        /// <summary>
        /// VIRTUAL_STORAGE_TYPE structure containing information about the type
        /// of virtual disk. Set the Version member to
        /// GET_VIRTUAL_DISK_INFO_VIRTUAL_STORAGE_TYPE.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public VirtualStorageType VirtualStorageType; //VIRTUAL_STORAGE_TYPE

        /// <summary>
        /// Provider-specific subtype. Set the Version member to
        /// GET_VIRTUAL_DISK_INFO_PROVIDER_SUBTYPE.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 ProviderSubtype; //ULONG

        /// <summary>
        /// Indicates whether the virtual disk is 4 KB aligned. Set the Version
        /// member to GET_VIRTUAL_DISK_INFO_IS_4K_ALIGNED.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public bool Is4kAligned; //BOOL

        /// <summary>
        /// Indicates whether the virtual disk is currently mounted and in use.
        /// TRUE if the virtual disk is currently mounted and in use; otherwise
        /// FALSE. Set the Version member to GET_VIRTUAL_DISK_INFO_IS_LOADED.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public bool IsLoaded; //BOOL

        /// <summary>
        /// Details about the physical disk on which the virtual disk resides.
        /// Set the Version member to GET_VIRTUAL_DISK_INFO_PHYSICAL_DISK.
        /// </summary>        
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public GetVirtualDiskInfoPhysicalDisk PhysicalDisk;

        /// <summary>
        /// The physical sector size of the virtual disk. Set the Version member
        /// to GET_VIRTUAL_DISK_INFO_VHD_PHYSICAL_SECTOR_SIZE.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 VhdPhysicalSectorSize; //ULONG

        /// <summary>
        /// The smallest safe minimum size of the virtual disk. Set the Version
        /// member to GET_VIRTUAL_DISK_INFO_SMALLEST_SAFE_VIRTUAL_SIZE.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt64 SmallestSafeVirtualSize; //ULONGLONG

        /// <summary>
        /// The fragmentation level of the virtual disk. Set the Version member
        /// to GET_VIRTUAL_DISK_INFO_FRAGMENTATION.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.UInt32 FragmentationPercentage; //ULONG

        /// <summary>
        /// The identifier that is uniquely created when a user first creates the
        /// virtual disk to attempt to uniquely identify that virtual disk. Set
        /// the Version member to GET_VIRTUAL_DISK_INFO_VIRTUAL_DISK_ID.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public System.Guid VirtualDiskId; //GUID

        /// <summary>
        /// The state of resilient change tracking (RCT) for the virtual disk.
        /// Set the Version member to GET_VIRTUAL_DISK_INFO_CHANGE_TRACKING_STATE.
        /// </summary>
        [System.Runtime.InteropServices.FieldOffsetAttribute(0)]
        public GetVirtualDiskInfoChangeTrackingState ChangeTrackingState;
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct GetVirtualDiskInfoSize
    {
        /// <summary>
        /// Virtual size of the virtual disk, in bytes.
        /// </summary>
        public System.UInt64 VirtualSize; //ULONGLONG

        /// <summary>
        /// Physical size of the virtual disk on physical disk, in bytes.
        /// </summary>
        public System.UInt64 PhysicalSize; //ULONGLONG

        /// <summary>
        /// Block size of the virtual disk, in bytes.
        /// </summary>
        public System.UInt32 BlockSize; //ULONG

        /// <summary>
        /// Sector size of the virtual disk, in bytes.
        /// </summary>
        public System.UInt32 SectorSize; //ULONG
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    //public unsafe struct GetVirtualDiskInfoParentLocation
    public struct GetVirtualDiskInfoParentLocation
    {
        /// <summary>
        /// Parent resolution. TRUE if the parent backing store was successfully
        /// resolved, FALSE if not.
        /// </summary>
        //[System.Runtime.InteropServices.MarshalAsAttribute(
        //  System.Runtime.InteropServices.UnmanagedType.Bool
        //)]
        public bool ParentResolved; //BOOL

        /// <summary>
        /// If the ParentResolved member is TRUE, contains the path of the parent
        /// backing store.
        /// If the ParentResolved member is FALSE, contains all of the parent
        /// paths present in the search list.
        /// </summary>
        /// <remarks>
        /// useless
        /// </remarks>
        public char ParentLocationBuffer;             //WCHAR[1]

        /*  other implementations: 1  */

        /*  This is suggested by
            https://stackoverflow.com/questions/37763090/how-to-marshal-wchar-in-c-sharp
            however it's rather pointless. The value of this parameter is not
            a pointer, as explained at
            https://stackoverflow.com/questions/4120658/difference-between-char-and-char1
            https://stackoverflow.com/questions/3711233/is-the-struct-hack-technically-undefined-behavior
            https://stackoverflow.com/questions/4412749/are-flexible-array-members-valid-in-c
         */
        /* public System.IntPtr ParentLocationBuffer; //WCHAR[1]
         */

        /*  other implementations: 2  */

        /*  this works, provided that the struct is declared as “unsafe”. However,
            it's also quite pointless given that the real output value will
            likely be a lot shorter. And it's easier to marshal the array if you 
            know the real length, not the maximum one  */
        /*
            public fixed char ParentLocationBuffer[769];
         */

        /*  other implementations: 3  */

        /*  /termsrv/wms/test/WMS.Test/Tools/NebulaVHDCreation/DllWrapper.cs
            last updated before 2016  */

        /*  This syntax is used inside the
            “Anonymous_12d73763_a8b0_405c_b6b8_b816be8b8a64” struct that is
            defined inside “DllWrapper” class but never used. (And this is why it
            compiles successfully.)  */

        /*  Trying to use this syntax fails “because it contains an object field
            at offset 0 that is incorrectly aligned or overlapped by a non-object
            field.”  */

        /* [System.Runtime.InteropServices.MarshalAsAttribute(
               System.Runtime.InteropServices.UnmanagedType.ByValTStr,
               SizeConst = 1)]
           public string ParentLocationBuffer;
         */

        /*  /vm/test/fr/CTP/Library/Win32Wrapper.cs
            last updated before 2016
            Loading this file “as is” fails with fails “because it contains an
            object field at offset 0 that is incorrectly aligned or overlapped by
            a non-object field”  */

        /*  This syntax used inside “GET_VIRTUAL_DISK_INFO_ParentLocation” which
            is part of “GET_VIRTUAL_DISK_INFO_Union” which is used inside
           “GET_VIRTUAL_DISK_INFO” structure which is apparently not used in any
            method or function.  */

        /*  Trying to use this syntax fails “because it contains an object field
            at offset 0 that is incorrectly aligned or overlapped by a non-object
            field.”  */

        /*  [MarshalAs(
                UnmanagedType.ByValTStr,
                SizeConst = 769
            )]
            public byte[] ParentLocationBuffer;
         */

        /*  This syntax used inside “GET_PARENT_INFO” struct which is used for
           “GetVirtualDiskParentPath” method of “IoctlWrapper” class which uses
           “GetVirtualDiskParentInformation” function which is a redefined
            implementation of “GetVirtualDiskInformation.” (This is the only
            implementation of “GetVirtualDiskInformation” in this document.)  */

        /*  Trying to use this syntax fails “because it contains an object field
            at offset 0 that is incorrectly aligned or overlapped by a non-object
            field.”  */

        /*  [MarshalAs(
                UnmanagedType.ByValArray,
                SizeConst = 769
            )]
            public byte[] ParentLocationBuffer;
         */

        /*  /amcore/Antimalware/Source/Test/Libs/VirtualDisk/StorageLib/Native.cs
            /base/fs/test/Shared_Libs/RMLib/VHDLib/StorageLib/native.cs    
            /vm/test/tools/storage/VDiskInterop/dll/StorageLib/native.cs

            three files are different in other aspects, but contain identical
            pair of implementations. The last file was modified in 2019 in the
           “base” path.  */

        /*  This syntax is used inside “GetVirtualDiskInfoParentLocation” struct
            which is used inside “GetVirtualDiskInfoUnion” which is part of
           “GetVirtualDiskInfo” struct which is used for calling
           “GetVirtualDiskInformation.”  */

        /*  Trying to use this syntax will compile. However, it provides unusable
            results, as the comments around the implementation suggests.  */

        /*  public char ParentLocationBuffer;
         */

        /*  This syntax is used inside “GetParentInfoHack” struct which is used
            for calling “GetVirtualDiskParentInformation” which is a redefined
            implementation of “GetVirtualDiskInformation”  */

        /*  This syntax works in independent struct when ut is used directly in 
           “GetVirtualDiskInformation.” However, when used as part of Union, it
            fails “because it contains an object field at offset 0 that is
            incorrectly aligned or overlapped by a non-object field.”  */

        /*  [MarshalAs(UnmanagedType.ByValArray, SizeConst = 769)]
            public byte[] ParentLocationBuffer;
        */
    }

    /*
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct GetVirtualDiskInfoParentLocationWorkaround
    {
        //public GetVirtualDiskInfoVersion Version;

        /// <summary>
        /// Parent resolution. TRUE if the parent backing store was successfully
        /// resolved, FALSE if not.
        /// </summary>
        /// <remarks>
        /// This part is useless
        /// </remarks>
        //[System.Runtime.InteropServices.MarshalAsAttribute(
        //  System.Runtime.InteropServices.UnmanagedType.Bool
        //)]
        public bool ParentResolved; //BOOL

        /// <summary>
        /// If the ParentResolved member is TRUE, contains the path of the parent
        /// backing store.
        /// If the ParentResolved member is FALSE, contains all of the parent
        /// paths present in the search list.
        /// </summary>
        [System.Runtime.InteropServices.MarshalAsAttribute(
            // System.Runtime.InteropServices.UnmanagedType.LPWStr,
            // System.Runtime.InteropServices.UnmanagedType.ByValArray,
            System.Runtime.InteropServices.UnmanagedType.ByValTStr,
            // SizeConst = 1
            SizeConst = 769
        )]
        // public System.String ParentLocationBuffer; //WCHAR[1]        
        // public System.Int64  ParentLocationBuffer; //WCHAR[1]
        // public System.IntPtr ParentLocationBuffer; //WCHAR[1]
        public byte[] ParentLocationBuffer;           //WCHAR[1]
    }
    */

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct GetVirtualDiskInfoPhysicalDisk
    {
        /// <summary>
        /// The logical sector size of the physical disk.
        /// </summary>
        public System.UInt32 LogicalSectorSize; //ULONG

        /// <summary>
        /// The physical sector size of the physical disk.
        /// </summary>
        public System.UInt32 PhysicalSectorSize; //ULONG

        /// <summary>
        /// Indicates whether the physical disk is remote.
        /// </summary>
        public bool IsRemote; //BOOL
    }

    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        CharSet = System.Runtime.InteropServices.CharSet.Unicode
    )]
    public struct GetVirtualDiskInfoChangeTrackingState
    {
        /// <summary>
        /// Whether RCT is turned on. TRUE if RCT is turned on; otherwise FALSE.
        /// </summary>
        [System.Runtime.InteropServices.MarshalAsAttribute(
            System.Runtime.InteropServices.UnmanagedType.Bool
        )]
        public bool Enabled; //BOOL

        /// <summary>
        /// Whether the virtual disk has changed since the change identified by
        /// the MostRecentId member occurred. TRUE if the virtual disk has
        /// changed since the change identified by the MostRecentId member
        /// occurred; otherwise FALSE.
        /// </summary>
        [System.Runtime.InteropServices.MarshalAsAttribute(
            System.Runtime.InteropServices.UnmanagedType.Bool
        )]
        public bool NewerChanges; //BOOL

        /// <summary>
        /// The change tracking identifier for the change that identifies the
        /// state of the virtual disk that you want to use as the basis of
        /// comparison to determine whether the NewerChanges member reports new
        /// changes.
        /// </summary>
        /// <remarks>
        /// useless
        /// </remarks>
        //[System.Runtime.InteropServices.MarshalAsAttribute(
        //  //System.Runtime.InteropServices.UnmanagedType.LPWStr
        //  System.Runtime.InteropServices.UnmanagedType.ByValTStr,
        //  SizeConst = 1
        //)]
        // public System.String MostRecentId; //WCHAR[1]
        public System.IntPtr MostRecentId;    //WCHAR[1]
        // public char MostRecentId;          //WCHAR[1]
    }

    #endregion GetVirtualDiskInfo

    #endregion struct

    public class VirtDisk
    {
        #region    method

        #region    OpenVirtualDisk

        // Indicates that the attributed method is exposed by an unmanaged
        // dynamic-link library (DLL) as a static entry point.
        // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "VirtDisk.dll",
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true,
            CallingConvention = System.Runtime.InteropServices.CallingConvention.StdCall
        )]

        // Retrieves information about a virtual hard disk (VHD)
        // https://learn.microsoft.com/windows/win32/api/virtdisk/nf-virtdisk-openvirtualdisk
        public static extern System.UInt32
            OpenVirtualDisk(
              // [in] PVIRTUAL_STORAGE_TYPE VirtualStorageType,
              // A pointer to a valid VIRTUAL_STORAGE_TYPE structure.
              [System.Runtime.InteropServices.InAttribute()]
              [System.Runtime.InteropServices.OutAttribute()]
              ref VirtualStorageType VirtualStorageType,

              // [in] PCWSTR Path,
              // A pointer to a valid path to the virtual disk image to open.
              [System.Runtime.InteropServices.InAttribute()]
              [System.Runtime.InteropServices.MarshalAsAttribute(
                System.Runtime.InteropServices.UnmanagedType.LPWStr
              )]
              System.String Path,

              // [in] VIRTUAL_DISK_ACCESS_MASK VirtualDiskAccessMask,
              // A valid value of the VIRTUAL_DISK_ACCESS_MASK enumeration.
              [System.Runtime.InteropServices.InAttribute()]
              VirtualDiskAccessMask VirtualDiskAccessMask,

              // [in] OPEN_VIRTUAL_DISK_FLAG Flags,
              // A valid combination of values of the OPEN_VIRTUAL_DISK_FLAG enumeration.
              [System.Runtime.InteropServices.InAttribute()]
              OpenVirtualDiskFlags Flags,

              // [in, optional] POPEN_VIRTUAL_DISK_PARAMETERS Parameters,
              // An optional pointer to a valid OPEN_VIRTUAL_DISK_PARAMETERS structure. Can be NULL.
              [System.Runtime.InteropServices.InAttribute()]
              [System.Runtime.InteropServices.OutAttribute()]
              [System.Runtime.InteropServices.OptionalAttribute()]
              ref OpenVirtualDiskParameters Parameters,

              // [out] PHANDLE Handle
              // A pointer to the handle object that represents the open virtual disk.
              [System.Runtime.InteropServices.OutAttribute()]
              out Microsoft.Win32.SafeHandles.SafeFileHandle Handle
            );

        #endregion OpenVirtualDisk

        #region    GetVirtualDiskInformation

        // Indicates that the attributed method is exposed by an unmanaged
        // dynamic-link library (DLL) as a static entry point.
        // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "VirtDisk.dll",
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true,
            CallingConvention = System.Runtime.InteropServices.CallingConvention.StdCall
        )]

        // Retrieves information about a virtual hard disk (VHD)
        // https://learn.microsoft.com/windows/win32/api/virtdisk/nf-virtdisk-getvirtualdiskinformation
        public static extern System.UInt32
            GetVirtualDiskInformation(
              //  [in]                HANDLE                 VirtualDiskHandle,
              // A handle to the open VHD, which must have been opened using the
              // VIRTUAL_DISK_ACCESS_GET_INFO flag set in the VirtualDiskAccessMask
              // parameter to the OpenVirtualDisk function.
              [System.Runtime.InteropServices.InAttribute]
              Microsoft.Win32.SafeHandles.SafeFileHandle Handle,

              // [in, out] PULONG VirtualDiskInfoSize,
              // A pointer to a ULONG that contains the size of the VirtualDiskInfo
              // parameter.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute]
              ref System.UInt32 VirtualDiskInfoSize,

              // [in, out] PGET_VIRTUAL_DISK_INFO VirtualDiskInfo,
              // A pointer to a valid GET_VIRTUAL_DISK_INFO structure. The format
              // of the data returned is dependent on the value passed in the Version
              // member by the caller.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute]
              System.IntPtr VirtualDiskInfo,

              // [in, out, optional] PULONG SizeUsed
              // A pointer to a ULONG that contains the size used.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute, System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );

        // Indicates that the attributed method is exposed by an unmanaged
        // dynamic-link library (DLL) as a static entry point.
        // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "VirtDisk.dll",
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true,
            CallingConvention = System.Runtime.InteropServices.CallingConvention.StdCall
        )]

        // Retrieves information about a virtual hard disk (VHD)
        // https://learn.microsoft.com/windows/win32/api/virtdisk/nf-virtdisk-getvirtualdiskinformation
        public static extern System.UInt32
            GetVirtualDiskInformation(
              //  [in]                HANDLE                 VirtualDiskHandle,
              // A handle to the open VHD, which must have been opened using the
              // VIRTUAL_DISK_ACCESS_GET_INFO flag set in the VirtualDiskAccessMask
              // parameter to the OpenVirtualDisk function.
              [System.Runtime.InteropServices.InAttribute]
              Microsoft.Win32.SafeHandles.SafeFileHandle Handle,

              // [in, out] PULONG VirtualDiskInfoSize,
              // A pointer to a ULONG that contains the size of the VirtualDiskInfo
              // parameter.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute]
              ref System.UInt32 VirtualDiskInfoSize,

              // [in, out] PGET_VIRTUAL_DISK_INFO VirtualDiskInfo,
              // A pointer to a valid GET_VIRTUAL_DISK_INFO structure. The format
              // of the data returned is dependent on the value passed in the Version
              // member by the caller.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute]
              ref GetVirtualDiskInfo VirtualDiskInfo,

              // [in, out, optional] PULONG SizeUsed
              // A pointer to a ULONG that contains the size used.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute, System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );

        /*
        // Indicates that the attributed method is exposed by an unmanaged
        // dynamic-link library (DLL) as a static entry point.
        // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "VirtDisk.dll",
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true,
            CallingConvention = System.Runtime.InteropServices.CallingConvention.StdCall
        )]       
        
        // Retrieves information about a virtual hard disk (VHD)
        // https://learn.microsoft.com/windows/win32/api/virtdisk/nf-virtdisk-getvirtualdiskinformation
        public static extern System.UInt32
            GetVirtualDiskInformation(
              //  [in]                HANDLE                 VirtualDiskHandle,
              // A handle to the open VHD, which must have been opened using the
              // VIRTUAL_DISK_ACCESS_GET_INFO flag set in the VirtualDiskAccessMask
              // parameter to the OpenVirtualDisk function.
              [System.Runtime.InteropServices.InAttribute]
              Microsoft.Win32.SafeHandles.SafeFileHandle Handle,

              // [in, out] PULONG VirtualDiskInfoSize,
              // A pointer to a ULONG that contains the size of the VirtualDiskInfo
              // parameter.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute]
              ref System.UInt32 VirtualDiskInfoSize,

              // [in, out] PGET_VIRTUAL_DISK_INFO VirtualDiskInfo,
              // A pointer to a valid GET_VIRTUAL_DISK_INFO structure. The format
              // of the data returned is dependent on the value passed in the Version
              // member by the caller.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute]
              ref GetVirtualDiskInfoParentLocationWorkaround VirtualDiskInfo,

              // [in, out, optional] PULONG SizeUsed
              // A pointer to a ULONG that contains the size used.
              [System.Runtime.InteropServices.InAttribute, System.Runtime.InteropServices.OutAttribute, System.Runtime.InteropServices.OptionalAttribute]
              ref System.UInt32 SizeUsed
        );
        */

        #endregion GetVirtualDiskInformation

        #region    EnumerateMetadata

        #endregion EnumerateMetadata

        #region    GetVirtualDiskMetadata

        // Indicates that the attributed method is exposed by an unmanaged
        // dynamic-link library (DLL) as a static entry point.
        // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "VirtDisk.dll",
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true
        )]

        // Retrieves the specified metadata from the virtual disk
        // https://learn.microsoft.com/windows/win32/api/virtdisk/nf-virtdisk-getvirtualdiskmetadata
        public static extern System.UInt32 GetVirtualDiskMetadata(
            System.Int32 hKey,       // A handle to the key where the subkey will be created
            System.String lpSubKey,  // The name of the key to be created under hKey
            System.String lpFile     // The name of the file containing the registry data
        );

        #endregion GetVirtualDiskMetadata

        #endregion method
    }
}