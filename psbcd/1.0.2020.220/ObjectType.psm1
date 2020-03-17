# https://docs.microsoft.com/en-us/previous-versions/windows/desktop/bcd/bcdobject
# http://www.geoffchappell.com/notes/windows/boot/bcd/objects.htm

Enum
ObjectType
{
 <# BCD_OBJECT_TYPE_APPLICATION (0x1rtaaaaa)

    an object type for a boot environment application, functional usage of the
    application and the image type  #>

  # BCD_IMAGE_TYPE_FIRMWARE_APPLICATION = 0x10100000  # Mask

  #     BCD_APPLICATION_TYPE_FIRMWARE_BOOT_MANAGER
    Firmware_boot_manager               = 0x10100001  # {fwbootmgr}
  #     BCD_APPLICATION_TYPE_WINDOWS_BOOT_MANAGER
    Windows_boot_manager                = 0x10100002  # {bootmgr}
    Firmware                            = 0x101FFFFF

  # BCD_IMAGE_TYPE_BOOT_APPLICATION     = 0x10200000  # Mask

  #     BCD_APPLICATION_TYPE_WINDOWS_BOOT_LOADER 
    Windows_boot_loader                 = 0x10200003  # /application osloader
  #     BCD_APPLICATION_TYPE_WINDOWS_RESUME_APPLICATION
    Windows_resume_application          = 0x10200004  # /application resume
  #     BCD_APPLICATION_TYPE_WINDOWS_MEMORY_TESTER
    Memory_test                         = 0x10200005  # {memdiag}

  # BCD_IMAGE_TYPE_LEGACY_LOADER        = 0x10300000  # Mask

  #     BCD_APPLICATION_TYPE_LEGACY_NTLDR
    Legacy_NtLdr                        = 0x10300006  # {ntldr}
  #     BCD_APPLICATION_TYPE_LEGACY_SETUPLDR
    Legacy_SetupLdr                     = 0x10300007  # {setupldr}
  #     BCD_APPLICATION_TYPE_BOOT_SECTOR
    Boot_Sector                         = 0x10300008  # /application bootsector

  # BCD_IMAGE_TYPE_REALMODE_CODE        = 0x10400000  # Mask

    Startup_module                      = 0x10400009  # /application startup
    Generic_application                 = 0x1040000a  # /application bootapp

 <# BCD_OBJECT_TYPE_INHERITED (0x2nnnnnnn)

    describes a set of data elements which can be inherited (inheritable) from
    a BCD object for a boot application or from another inheritable object  #>

  # Inherit                    = 0x20000000  # Mask
    
  # BCDE_CLASS_LIBRARY      Inheritable by Any Objects
    Inherit_Any                = 0x20100000  # /inherit {badmemory}, {dbgsettings}, {emssettings}, {globalsettings}

  # BCDE_CLASS_APPLICATION  Inheritable by Application Objects
  # Inherit_Application        = 0x20200000  # Mask
    Inherit_Fwbootmgr          = 0x20200001	 # /inherit {fwbootmgr}
    Inherit_Bootmgr            = 0x20200002	 # /inherit {bootmgr}
    Inherit_Osloader           = 0x20200003  # /inherit osloader, {bootloadersettings}, {hypervisorsettings}, {kerneldbgsettings}
    Inherit_Resume             = 0x20200004  # /inherit resume, {resumeloadersettings}
    Inherit_Memdiag            = 0x20200005  # /inherit {memdiag}
    Inherit_NtLdr              = 0x20200006  # /inherit {ntldr}
    Inherit_Setupldr           = 0x20200007  # /inherit {setupldr}
    Inherit_Bootsector         = 0x20200008  # /inherit bootsector
    Inherit_Startup            = 0x20200009  # /inherit startup

  # BCDE_CLASS_DEVICE       Inheritable by Device Objects
    Inherit_Device             = 0x20300000  # /inherit device

  # BCD_OBJECT_TYPE_DEVICE
    Device                     = 0x30000000  # /device {ramdiskoptions}
}