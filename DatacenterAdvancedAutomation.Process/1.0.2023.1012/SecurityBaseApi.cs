using System;

namespace DatacenterAdvancedAutomation.Process
{
    public class SecurityBaseApi
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

        // Enables or disables privileges in the specified access token
        // https://docs.microsoft.com/windows/win32/api/securitybaseapi/nf-securitybaseapi-adjusttokenprivileges
        public static extern System.Boolean AdjustTokenPrivileges(
            System.IntPtr TokenHandle,
            System.Boolean DisableAllPrivileges,
            ref DatacenterAdvancedAutomation.Process.TokenPrivilege NewState,
            System.Int32 BufferLength,
            System.IntPtr PreviousState,
            System.IntPtr ReturnLength
        );
    }
}