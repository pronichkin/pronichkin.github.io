﻿#
# Module manifest for module 'Pronichkin.ImageFap'
#
# Generated by: artem@pronichkin.com
#
# Generated on: 8/21/2019
#

@{

  # Script module or binary module file associated with this manifest.
  # RootModule = ''

  # Version number of this module.
    ModuleVersion = '1.0.2021.0709'

  # Supported psEditions
    CompatiblepsEditions = 'Desktop'

  # ID used to uniquely identify this module
    GUID = '36f72cfb-c195-42ac-a849-9e792c3c56fe'

  # Author of this module
    Author = 'artem@pronichkin.com'

  # Company or vendor of this module
    CompanyName = 'Artem Pronichkin'

  # Copyright statement for this module
    Copyright = 'Artem Pronichkin. All rights reserved.'

  # Description of the functionality provided by this module
    Description = 'Download images from ImageFap.com'

  # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1.0.0'

  # Name of the Windows PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the Windows PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # DotNetFrameworkVersion = ''

  # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # CLRVersion = ''

  # Processor architecture (None, X86, Amd64) required by this module
  # ProcessorArchitecture = ''

  # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        'DatacenterAdvancedAutomation.Utility'
        'DatacenterAdvancedAutomation.Selenium'
    )

  # Assemblies that must be loaded prior to importing this module
  # RequiredAssemblies = @()

  # Script files (.ps1) that are run in the caller's environment prior to importing this module.
  # ScriptsToProcess = @()

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
    
        'Show-ifPage.psm1'       # Open ImageFap page, check for captcha, retry if needed
      # 'Get-ifCollection.psm1'  # Retrieve list of collections from a profile with associated galleries
        'Save-ifCollection.psm1' # Save entire collection
      # 'Get-ifGallrey.psm1'     # Retrieve list of galleries from a collection with associated images
        'Save-ifGallrey.psm1'    # Save entire gallery
        'Get-ifItem.psm1'        # Retrieve metadata for a single gallery item
        'Save-ifItem.psm1'       # Save an item from a gallery
    )

  # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(

        'Show-ifPage'           # Open ImageFap page, check for captcha, retry if needed
      # 'Get-ifCollection'      # Retrieve list of collections from a profile with associated galleries
        'Save-ifCollection'     # Save entire collection
      # 'Get-ifGallrey'         # Retrieve list of galleries from a collection with associated images
        'Save-ifGallrey'        # Save entire gallery
        'Get-ifItem'            # Retrieve metadata for a single gallery item
        'Save-ifItem'           # Save an image from a gallery
    )

  # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

  # Variables to export from this module
    VariablesToExport = '*'

  # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

  # DSC resources to export from this module
  # DscResourcesToExport = @()

  # List of all modules packaged with this module
    ModuleList = @(

        @{  ModuleName    = 'Show-ifPage'                           ;   ModuleVersion = '1.0.2021.0707'  }
      # @{  ModuleName    = 'Get-ifCollection'                      ;   ModuleVersion = '1.0.2021.0707'  }
        @{  ModuleName    = 'Save-ifCollection'                     ;   ModuleVersion = '1.0.2021.0707'  }
      # @{  ModuleName    = 'Get-ifGallrey'                         ;   ModuleVersion = '1.0.2021.0707'  }
        @{  ModuleName    = 'Save-ifGallrey'                        ;   ModuleVersion = '1.0.2021.0708'  }
        @{  ModuleName    = 'Get-ifItem'                            ;   ModuleVersion = '1.0.2021.0709'  }
        @{  ModuleName    = 'Save-ifItem'                           ;   ModuleVersion = '1.0.2021.0708'  }
    )

  # List of all files packaged with this module
  # FileList = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a psData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        psData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

        } # End of psData hashtable

    } # End of PrivateData hashtable

  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''
}