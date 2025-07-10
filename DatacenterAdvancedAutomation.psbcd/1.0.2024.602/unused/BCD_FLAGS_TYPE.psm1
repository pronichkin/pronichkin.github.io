# superceded by bcdtypes
# should be no longer needed

#
# Flags that control the conversion of boot environment device to a device element.
#

enum BCD_FLAGS_TYPE
{
    # This is the default value for flags.
    NONE                          = 0x0000

    # This value is used when requesting qualified partition information.
    QUALIFIED_PARTITION           = 0x0001

    # This value is used to disable translation of device to its corresponding
    # NT device path.
    NO_DEVICE_TRANSLATION         = 0x0002

    # This value is used to enumerate subelements in an inherited object.
    ENUMERATE_INHERITED_OBJECTS   = 0x0004

    # This value is used to enumerate device options.
    ENUMERATE_DEVICE_OPTIONS      = 0x0008

    # This value is used to collapse elements based on precedence.
    OBSERVE_PRECEDENCE            = 0x0010

    # This flag is used to display VHD devices as file devices.
    DISABLE_VHD_NT_TRANSLATION    = 0x0020

    # This flag suppresses automatic VHD partition device detection such that
    # standard hard disk partition devices are created instead.
    DISABLE_VHD_DEVICE_DETECTION  = 0x0040

    # This flag disables checks against secure boot policy. The entry might still
    # be ignored during boot if it violated policy, but will be allowed to be set
    # offline.
    DISABLE_POLICY_CHECKS         = 0x0080

    # This flag resolves LOCATE keyword within the bcd enumerate elements routine.
    RESOLVE_LOCATE                = 0x0100
}