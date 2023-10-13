namespace DatacenterAdvancedAutomation.Process
{
    public class ProcessThreadsApi
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

        // opens the access token associated with a process
        // https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocesstoken
        public static extern System.Boolean OpenProcessToken(
            System.IntPtr ProcessHandle,    // A handle to the process whose access token is opened.
            int DesiredAccess,     // Specifies an access mask that specifies the requested types of access to the access token.
            ref System.IntPtr TokenHandle   // A pointer to a handle that identifies the newly opened access token when the function returns.
        );
    }
}