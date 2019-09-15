[DllImport("advapi32.dll", SetLastError=true)]
public static extern int  RegUnLoadKey(Int32 hKey,string lpSubKey);
public static extern long RegLoadKey(Int hKey, String lpSubKey, String lpFile);