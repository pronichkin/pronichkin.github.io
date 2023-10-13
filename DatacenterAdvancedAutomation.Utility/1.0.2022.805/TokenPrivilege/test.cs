[DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);