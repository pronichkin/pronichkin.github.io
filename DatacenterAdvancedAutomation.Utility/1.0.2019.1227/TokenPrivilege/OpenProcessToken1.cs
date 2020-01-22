using System;

using System.Runtime.InteropServices;
public class OpenProcessToken6
{
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern void OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);

    internal const int TOKEN_QUERY             = 0x00000008;
    internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;

    public static IntPtr OpenProcessToken7(long processHandle)
    {
        IntPtr hproc = new IntPtr(processHandle);

        IntPtr htok = IntPtr.Zero;

        OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);

        return htok;
    }
}