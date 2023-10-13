
             // using System;
             // using System.Runtime.InteropServices;

                namespace DatacenterAdvancedAutomation.Process
                {
                    public class AdjustTokenPrivilege
                    {
                        [System.Runtime.InteropServices.DllImportAttribute(
                            "advapi32.dll",
                            CharSet       = System.Runtime.InteropServices.CharSet.Unicode,
                            ExactSpelling = true,
                            SetLastError  = true
                        )]

                     // https://docs.microsoft.com/windows/win32/api/securitybaseapi/nf-securitybaseapi-adjusttokenprivileges
                        public static extern bool  AdjustTokenPrivileges(
                            System.IntPtr                                             TokenHandle,
                            bool                                                      DisableAllPrivileges,
                            ref  DatacenterAdvancedAutomation.Process.TokenPrivilege  NewState,
                            int                                                       BufferLength,
                            System.IntPtr                                             PreviousState,
                            System.IntPtr                                             ReturnLength
                        );
                    }
                }