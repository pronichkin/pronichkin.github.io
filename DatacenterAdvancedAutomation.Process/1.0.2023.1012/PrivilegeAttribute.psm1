# https://learn.microsoft.com/windows/win32/api/winnt/ns-winnt-privilege_set

Enum
PrivilegeAttribute
{
    SE_PRIVILEGE_DISABLED           = 0x00000000
    SE_PRIVILEGE_ENABLED_BY_DEFAULT = 0x00000001
    SE_PRIVILEGE_ENABLED            = 0x00000002
    SE_PRIVILEGE_REMOVED            = 0x00000004
    SE_PRIVILEGE_USED_FOR_ACCESS    = 0x80000000
}