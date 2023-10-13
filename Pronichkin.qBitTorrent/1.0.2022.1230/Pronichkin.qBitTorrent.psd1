@{

  # Script module or binary module file associated with this manifest.
  # RootModule = ''

  # Version number of this module.
    ModuleVersion = '1.0.2022.1230'

  # Supported psEditions
    CompatiblePsEditions = 'Desktop'

  # ID used to uniquely identify this module
    GUID = 'a1d34e58-7a4b-4279-9d1f-6fb341080a2e'

  # Author of this module
    Author = 'Artem Pronichkin  artem@pronichkin.com'

  # Company or vendor of this module
  # CompanyName = 'Artem Pronichkin'

  # Copyright statement for this module
  # Copyright = 'Artem Pronichkin'

  # Description of the functionality provided by this module
    Description = 'Remote PowerShell management for qBittorrent'

  # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1.0.0'

  # Name of the PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # DotNetFrameworkVersion = ''

  # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # ClrVersion = ''

  # Processor architecture (None, X86, Amd64) required by this module
  # ProcessorArchitecture = ''

  # Modules that must be imported into the global environment prior to importing this module
  # RequiredModules = @()

  # Assemblies that must be loaded prior to importing this module
  # RequiredAssemblies = 'QBittorrent.Client, Version=1.8.0.0,     Culture=neutral, PublicKeyToken=null'
  # RequiredAssemblies = 'QBittorrent.Client, Version=1.8.22216.3, Culture=neutral, PublicKeyToken=null'
    RequiredAssemblies = 'QBittorrent.Client, Version=1.8.23016.2, Culture=neutral, PublicKeyToken=null'

  # Script files (.ps1) that are run in the caller's environment prior to importing this module.
  # ScriptsToProcess = @()

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
    
        'Connect-qbTorrent.psm1'
        'Get-qbTorrent.psm1'
        'Get-qbTorrentContent.psm1'
        'Get-qbTorrentLog.psm1'
        'Set-qbTorrent.psm1'
        'Rename-qbTorrentContent.psm1'
        'Test-qbTorrent.psm1'
        'Test-qbTorrentConnection.psm1'
        'Stop-qbTorrent.psm1'
        'Invoke-AsynchronousTask.psm1'   # internal helper
    )

  # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
    
        'Connect-qbTorrent'
        'Get-qbTorrent'
        'Get-qbTorrentContent'
        'Get-qbTorrentLog'
        'Set-qbTorrent'
        'Rename-qbTorrentContent'
        'Test-qbTorrent'
        'Test-qbTorrentConnection'
        'Stop-qbTorrent'
      # 'Invoke-AsynchronousTask'
    )

  # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
  # CmdletsToExport = @()

  # Variables to export from this module
  # VariablesToExport = '*'

  # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
  # AliasesToExport = @()

  # DSC resources to export from this module
  # DscResourcesToExport = @()

  # List of all modules packaged with this module
    ModuleList = @(
        
        @{  ModuleName    = 'Connect-qbTorrent'                     ;   ModuleVersion = '1.0.2022.0821'  }
        @{  ModuleName    = 'Get-qbTorrent'                         ;   ModuleVersion = '1.0.2022.0821'  }
        @{  ModuleName    = 'Get-qbTorrentContent'                  ;   ModuleVersion = '1.0.2022.1230'  }
        @{  ModuleName    = 'Get-qbTorrentLog'                      ;   ModuleVersion = '1.0.2022.0821'  }
        @{  ModuleName    = 'Set-qbTorrent'                         ;   ModuleVersion = '1.0.2022.0821'  }
        @{  ModuleName    = 'Rename-qbTorrentContent'               ;   ModuleVersion = '1.0.2022.1230'  }
        @{  ModuleName    = 'Test-qbTorrent'                        ;   ModuleVersion = '1.0.2022.0821'  }
        @{  ModuleName    = 'Test-qbTorrentConnection'              ;   ModuleVersion = '1.0.2022.0821'  }
        @{  ModuleName    = 'Invoke-AsynchronousTask'               ;   ModuleVersion = '1.0.2022.0821'  }
        @{  ModuleName    = 'Stop-qbTorrent'                        ;   ModuleVersion = '1.0.2022.0821'  }
    )

  # List of all files packaged with this module
  # FileList = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        psData = @{

          # Tags applied to this module. These help with module discovery in online galleries.
          # Tags = @()

          # A URL to the license for this module.
          # LicenseUri = ''

          # A URL to the main website for this project.
            ProjectUri = 'https://pronichkin.com/'

          # A URL to an icon representing this module.
          # IconUri = ''

          # ReleaseNotes of this module
          # ReleaseNotes = ''

          # Prerelease string of this module
          # Prerelease = ''

          # Flag to indicate whether the module requires explicit user acceptance for install/update/save
          # RequireLicenseAcceptance = $false

          # External dependent modules of this module
          # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''
}