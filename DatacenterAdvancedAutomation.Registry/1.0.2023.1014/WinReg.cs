namespace DatacenterAdvancedAutomation.Registry
{
    public class WinReg
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

        // Creates a subkey under HKEY_USERS or HKEY_LOCAL_MACHINE and loads the
        // data from the specified registry hive into that subkey.
        // https://learn.microsoft.com/windows/win32/api/winreg/nf-winreg-regloadkeyw
        public static extern System.Int32 RegLoadKeyW(
            System.Int32 hKey,       // A handle to the key where the subkey will be created
            System.String lpSubKey,  // The name of the key to be created under hKey
            System.String lpFile     // The name of the file containing the registry data
        );

        // Indicates that the attributed method is exposed by an unmanaged
        // dynamic-link library (DLL) as a static entry point.
        // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "advapi32.dll",
            CharSet = System.Runtime.InteropServices.CharSet.Unicode,
            ExactSpelling = true,
            SetLastError = true
        )]

        // Unloads the specified registry key and its subkeys from the registry.
        // https://learn.microsoft.com/windows/win32/api/winreg/nf-winreg-regunloadkeyw
        public static extern System.Int32 RegUnLoadKeyW(
            System.Int32 hKey,       // A handle to the registry key to be unloaded
            System.String lpSubKey   // The name of the subkey to be unloaded
        );
    }
}