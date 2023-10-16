// [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
[DllImport("advapi32.dll", SetLastError=true)]
// public static extern Int32    RegLoadKey(Int32 hKey, String lpSubKey, String lpFile);
public static extern long RegLoadKey(int hKey, String lpSubKey, String lpFile);
// static extern Int32 RegLoadKey(UInt32 hKey, String lpSubKey, String lpFile);
// public static extern Int32  RegUnLoadKey(Int32 hKey, string lpSubKey);