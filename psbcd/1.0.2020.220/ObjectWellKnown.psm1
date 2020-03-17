<#

$global:ObjectWellKnown = [System.Collections.Generic.Dictionary[
    System.Guid, System.Collections.Generic.List[System.String]
]]::new()

#>

$global:ObjectWellKnown = [System.Collections.Generic.Dictionary[
    System.String, System.Guid
]]::new()

# Special shortcut

$ObjectWellKnown.Add( 'Current',              '{FA926493-6F1C-4193-A414-58F0B2456D1E}' )
$ObjectWellKnown.Add( 'Default',              '{1CAE1EB7-A0DF-4D4D-9851-4860E34EF535}' )

# Regular entry

$ObjectWellKnown.Add( 'EmsSettings',          '{0CE4991B-E6B3-4B16-B23C-5E0D9250E5D9}' )
$ObjectWellKnown.Add( 'ResumeLoaderSettings', '{1AFA9C49-16AB-4A5C-901B-212802DA9460}' )

 <# Only found at http://www.geoffchappell.com/notes/windows/boot/bcd/objects.htm?tx=5
    Probably a typo or obsolete value (same ID as above, but the GUID is not commonly found)

$ObjectWellKnown.Add( 'ResumeLoaderSettings', '{1AFA9C49-16AB-4A5C-4A90-212802DA9460}' )  #>

$ObjectWellKnown.Add( 'KernelDbgSettings',    '{313E8EED-7098-4586-A9BF-309C61F8D449}' )
$ObjectWellKnown.Add( 'DbgSettings',          '{4636856E-540F-4170-A130-A84776F4C654}' )
$ObjectWellKnown.Add( 'EventSettings',        '{4636856E-540F-4170-A130-A84776F4C654}' )
$ObjectWellKnown.Add( 'Legacy',               '{466F5A88-0AF2-4F76-9038-095B170DC21C}' )
$ObjectWellKnown.Add( 'NtLdr',                '{466F5A88-0AF2-4F76-9038-095B170DC21C}' )
$ObjectWellKnown.Add( 'BadMemory',            '{5189B25C-5558-4BF2-BCA4-289B11BD29E2}' )
$ObjectWellKnown.Add( 'BootloaderSettings',   '{6EFB52BF-1766-41DB-A6B3-0EE5EFF72BD7}' )
$ObjectWellKnown.Add( 'GlobalSettings',       '{7EA2E1AC-2E61-4728-AAA3-896D9D0A9F0E}' )
$ObjectWellKnown.Add( 'HypervisorSettings',   '{7FF607E0-4395-11DB-B0DE-0800200C9A66}' )
$ObjectWellKnown.Add( 'BootMgr',              '{9DEA862C-5CDD-4E70-ACC1-F32B344D4795}' )
$ObjectWellKnown.Add( 'FWBootMgr',            '{A5A30FA2-3D06-4E9F-B5F4-A01DF9D1FCBA}' )
$ObjectWellKnown.Add( 'RamDiskOptions',       '{AE5534E0-A924-466C-B836-758539A3EE3A}' )
$ObjectWellKnown.Add( 'MemDiag',              '{B2721D73-1DB4-4C62-BF78-C548A880142D}' )
$ObjectWellKnown.Add( 'SetupEFI',             '{7254A080-1510-4E85-AC0F-E7FB3D444736}' )
$ObjectWellKnown.Add( 'TargetTemplateEFI',    '{B012B84D-C47C-4ED5-B722-C0C42163E569}' )
$ObjectWellKnown.Add( 'SetupPCAT',            '{CBD971BF-B7B8-4885-951A-FA03044F5D71}' )
$ObjectWellKnown.Add( 'TargetTemplatePCAT',   '{A1943BBC-EA85-487C-97C7-C9EDE908A38A}' )