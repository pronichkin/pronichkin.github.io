namespace DatacenterAdvancedAutomation.Process
{
    // Lets you control the physical layout of the data fields of a class or
    // structure in memory.
    // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.structlayoutattribute
    [System.Runtime.InteropServices.StructLayoutAttribute(
        System.Runtime.InteropServices.LayoutKind.Sequential,
        Pack = 1
    )]

    // The TOKEN_PRIVILEGES structure contains information about a set of
    // privileges for an access token.
    // https://docs.microsoft.com/windows/win32/api/winnt/ns-winnt-token_privileges
    public struct TokenPrivilege
    {
        public int Count;  // PrivilegeCount
                           // https://docs.microsoft.com/windows/win32/api/winnt/ns-winnt-luid_and_attributes
        public long Luid;  // Luid
        public int Attr;   // Attributes
    }
}