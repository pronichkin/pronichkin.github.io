﻿
            namespace Microsoft.PowerShell.Commands.AddType.AutoGeneratedTypes
            {
             // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.structlayoutattribute
                [System.Runtime.InteropServices.StructLayout(
                    System.Runtime.InteropServices.LayoutKind.Sequential,
                    Pack = 1
                )]
             // https://docs.microsoft.com/windows/win32/api/winnt/ns-winnt-token_privileges
                public struct TokenPrivilege
                {
                    public int  Count;  // PrivilegeCount
                 // https://docs.microsoft.com/windows/win32/api/winnt/ns-winnt-luid_and_attributes
                    public long Luid;   // Luid
                    public int  Attr;   // Attributes
                }
            }