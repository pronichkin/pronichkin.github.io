# https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcd-enumerations
# http://www.geoffchappell.com/notes/windows/boot/bcd/elements.htm

Enum
ElementType
{
  # https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcdlibraryelementtypes
  # BcdLibraryElementTypes

    ApplicationDevice                               = 0x11000001
    ApplicationPath                                 = 0x12000002
    Description                                     = 0x12000004
    PreferredLocale                                 = 0x12000005
    InheritedObjects                                = 0x14000006
    TruncatePhysicalMemory                          = 0x15000007
    RecoverySequence                                = 0x14000008
    AutoRecoveryEnabled                             = 0x16000009
    BadMemoryList                                   = 0x1700000a
    AllowBadMemoryAccess                            = 0x1600000b
    FirstMegabytePolicy                             = 0x1500000c
    RelocatePhysicalMemory                          = 0x1500000D
    AvoidLowPhysicalMemory                          = 0x1500000E
    DebuggerEnabled                                 = 0x16000010
    DebuggerType                                    = 0x15000011
    SerialDebuggerPortAddress                       = 0x15000012
    SerialDebuggerPort                              = 0x15000013
    SerialDebuggerBaudRate                          = 0x15000014
  # Starting with a number causes issues in PowerShell Enum implementation
  # 1394DebuggerChannel                             = 0x15000015    # skip for now
    UsbDebuggerTargetName                           = 0x12000016
    DebuggerIgnoreUsermodeExceptions                = 0x16000017
    DebuggerStartPolicy                             = 0x15000018
    DebuggerBusParameters                           = 0x12000019
    DebuggerNetHostIP                               = 0x1500001A
    DebuggerNetPort                                 = 0x1500001B
    DebuggerNetDhcp                                 = 0x1600001C
    DebuggerNetKey                                  = 0x1200001D
    EmsEnabled_BcdLibraryBoolean                    = 0x16000020
    EmsPort                                         = 0x15000022
    EmsBaudRate                                     = 0x15000023
    LoadOptionsString                               = 0x12000030
    DisplayAdvancedOptions                          = 0x16000040
    DisplayOptionsEdit                              = 0x16000041
    BsdLogDevice                                    = 0x11000043
    BsdLogPath                                      = 0x12000044
    GraphicsModeDisabled                            = 0x16000046
    ConfigAccessPolicy                              = 0x15000047
    DisableIntegrityChecks                          = 0x16000048
    AllowPrereleaseSignatures_BcdLibraryBoolean     = 0x16000049
    FontPath                                        = 0x1200004A
    SiPolicy                                        = 0x1500004B
    FveBandId                                       = 0x1500004C
    ConsoleExtendedInput                            = 0x16000050
    GraphicsResolution                              = 0x15000052
    RestartOnFailure                                = 0x16000053
    GraphicsForceHighestMode                        = 0x16000054
    IsolatedExecutionContext                        = 0x16000060
    BootUxDisable                                   = 0x1600006C
    BootShutdownDisabled                            = 0x16000074
    AllowedInMemorySettings                         = 0x17000077
    ForceFipsCrypto                                 = 0x16000079
    AllowFlightSignatures                           = 0x1600007E
    BootUxDisplayMessage                            = 0x15000065
    BootUxDisplayMessageOverride                    = 0x15000066

  # https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcdosloaderelementtypes
  # BcdOSLoaderElementTypes

    OSDevice                                        = 0x21000001
    SystemRoot                                      = 0x22000002
  # AssociatedResumeObject                          = 0x23000003  # Duplicate?
    DetectKernelAndHal                              = 0x26000010
    KernelPath                                      = 0x22000011
    HalPath                                         = 0x22000012
    DbgTransportPath                                = 0x22000013
    NxPolicy                                        = 0x25000020
    PAEPolicy                                       = 0x25000021
    WinPEMode                                       = 0x26000022
    DisableCrashAutoReboot                          = 0x26000024
    UseLastGoodSettings                             = 0x26000025
    AllowPrereleaseSignatures_BcdOSLoader           = 0x26000027                                                    
    NoLowMemory                                     = 0x26000030
    RemoveMemory                                    = 0x25000031
    IncreaseUserVa                                  = 0x25000032
    UseVgaDriver                                    = 0x26000040
    DisableBootDisplay                              = 0x26000041
    DisableVesaBios                                 = 0x26000042
    DisableVgaMode                                  = 0x26000043
    ClusterModeAddressing                           = 0x25000050
    UsePhysicalDestination                          = 0x26000051
    RestrictApicCluster                             = 0x25000052
    UseLegacyApicMode                               = 0x26000054
    X2ApicPolicy                                    = 0x25000055
    UseBootProcessorOnly                            = 0x26000060
    NumberOfProcessors                              = 0x25000061
    ForceMaximumProcessors                          = 0x26000062
    ProcessorConfigurationFlags                     = 0x25000063
    MaximizeGroupsCreated                           = 0x26000064
    ForceGroupAwareness                             = 0x26000065
    GroupSize                                       = 0x25000066
    UseFirmwarePciSettings                          = 0x26000070
    MsiPolicy                                       = 0x25000071
    SafeBoot                                        = 0x25000080
    SafeBootAlternateShell                          = 0x26000081
    BootLogInitialization                           = 0x26000090
    VerboseObjectLoadMode                           = 0x26000091
    KernelDebuggerEnabled                           = 0x260000a0
    DebuggerHalBreakpoint                           = 0x260000a1
    UsePlatformClock                                = 0x260000A2
    ForceLegacyPlatform                             = 0x260000A3
    TscSyncPolicy                                   = 0x250000A6
    EmsEnabled_BcdOSLoaderBoolean                   = 0x260000b0
    DriverLoadFailurePolicy                         = 0x250000c1
    BootMenuPolicy_BcdOSLoader                      = 0x250000C2
    AdvancedOptionsOneTime                          = 0x260000C3
    BootStatusPolicy                                = 0x250000E0
    DisableElamDrivers                              = 0x260000E1
    HypervisorLaunchType                            = 0x250000F0
    HypervisorDebuggerEnabled                       = 0x260000F2
    HypervisorDebuggerType                          = 0x250000F3
    HypervisorDebuggerPortNumber                    = 0x250000F4
    HypervisorDebuggerBaudrate                      = 0x250000F5
    HypervisorDebugger1394Channel                   = 0x250000F6
    BootUxPolicy                                    = 0x250000F7
    HypervisorDebuggerBusParams                     = 0x220000F9
    HypervisorNumProc                               = 0x250000FA
    HypervisorRootProcPerNode                       = 0x250000FB
    HypervisorUseLargeVTlb                          = 0x260000FC
    HypervisorDebuggerNetHostIp                     = 0x250000FD
    HypervisorDebuggerNetHostPort                   = 0x250000FE
    TpmBootEntropyPolicy                            = 0x25000100
    HypervisorDebuggerNetKey                        = 0x22000110
    HypervisorDebuggerNetDhcp                       = 0x26000114
    HypervisorIommuPolicy                           = 0x25000115
    HypervisorSchedulerType                         = 0x2500011A
    XSaveDisable                                    = 0x2500012b
    Unknown_PageFile_Fallback                       = 0x21000152
    Unknown_NoClue                                  = 0x11000083

  # https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcdbootmgrelementtypes
  # BcdBootMgrElementTypes

    DisplayOrder                                    = 0x24000001
    BootSequence                                    = 0x24000002
    DefaultObject                                   = 0x23000003
    Timeout                                         = 0x25000004
    AttemptResume                                   = 0x26000005
    ResumeObject                                    = 0x23000006
    ToolsDisplayOrder                               = 0x24000010
    DisplayBootMenu                                 = 0x26000020
    NoErrorDisplay                                  = 0x26000021
    BcdDevice                                       = 0x21000022
    BcdFilePath                                     = 0x22000023
    ProcessCustomActionsFirst                       = 0x26000028
    CustomActionsList                               = 0x27000030
    PersistBootSequence                             = 0x26000031

  # https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcddeviceobjectelementtypes
  # BcdDeviceObjectElementTypes

    RamdiskImageOffset                              = 0x35000001
    TftpClientPort                                  = 0x35000002
    SdiDevice                                       = 0x31000003
    SdiPath                                         = 0x32000004
    RamdiskImageLength                              = 0x35000005
    RamdiskExportAsCd                               = 0x36000006
    RamdiskTftpBlockSize                            = 0x36000007
    RamdiskTftpWindowSize                           = 0x36000008
    RamdiskMulticastEnabled                         = 0x36000009
    RamdiskMulticastTftpFallback                    = 0x3600000A
    RamdiskTftpVarWindow                            = 0x3600000B

  # https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcdmemdiagelementtypes
  # BcdMemDiagElementTypes

    PassCount                                       = 0x25000001
    FailureCount                                    = 0x25000003

  # https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcdresumeelementtypes
  # BcdResumeElementTypes

  # Reserved1                                       = 0x21000001  # Duplicate?
  # Reserved2                                       = 0x22000002  # Duplicate?
    UseCustomSettings                               = 0x26000003
    AssociatedOsDevice                              = 0x21000005
    DebugOptionEnabled                              = 0x26000006
    BootMenuPolicy_BcdResume                        = 0x25000008

  # BcdSetup

    DeviceType                                      = 0x45000001
    ApplicationRelativePath                         = 0x42000002
    RamdiskDeviceRelativePath                       = 0x42000003
    OmitOsLoaderElements                            = 0x46000004
    ElementsToMigrate                               = 0x47000006
    RecoveryOs                                      = 0x46000010
}