namespace DatacenterAdvancedAutomation.Process
{
    public class WinBase
    {
        // Indicates that the attributed method is exposed by an unmanaged
        // dynamic-link library (DLL) as a static entry point.
        // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "advapi32.dll",
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true
        )]

        // retrieves the locally unique identifier (LUID) used on a specified
        // system to locally represent the specified privilege name
        // https://docs.microsoft.com/windows/win32/api/winbase/nf-winbase-lookupprivilegevaluew
        public static extern System.Boolean LookupPrivilegeValueW(
            System.String lpSystemName,
            System.String lpName,
            ref long lpLuid
        );
    }
}