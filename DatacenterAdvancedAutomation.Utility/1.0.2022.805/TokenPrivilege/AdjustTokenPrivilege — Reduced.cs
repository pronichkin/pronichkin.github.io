using System;

using System.Runtime.InteropServices;
public class AdjustTokenPrivilege
{
    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

    public static long EnablePrivilege(string name)
    {
        long Luid = 0;

        if (LookupPrivilegeValue(null, name, ref Luid))        
            System.Console.WriteLine("LookupPrivilegeValue succeed");
        else
            System.Console.WriteLine(Marshal.GetLastWin32Error());

        return Luid;
    }
}