enum BcdOpenFlags
{
    None                 = 0x0
    OpenStoreOffline     = 0x1   # BCD_FLAG_OPEN_STORE_OFFLINE          0x00000001
    SynchFirmwareEntries = 0x2   # BCD_FLAG_SYNCH_FIRMWARE_ENTRIES      0x00000002 - synchronize NVRAM entries when the store is opened. Only applicable if opening system store.
}