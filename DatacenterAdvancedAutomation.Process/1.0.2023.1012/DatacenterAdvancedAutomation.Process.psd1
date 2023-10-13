@{
 <# Script module or binary module file associated with this manifest  #>
  # RootModule = ''

 <# Version number of this module  #>
    ModuleVersion = '1.0.2023.1012'

 <# Supported psEditions  #>
    CompatiblePsEditions = @(
        'Desktop'
        'Core'
    )

 <# ID used to uniquely identify this module  #>
    GUID = '684f0a65-8164-40cf-9b3f-b992c4e8f657'

 <# Author of this module  #>
    Author = 'artem@pronichkin.com'

 <# Company or vendor of this module  #>
  # CompanyName = ''

 <# Copyright statement for this module  #>
  # Copyright = ''

 <# Description of the functionality provided by this module  #>
    Description = 'Datacenter Advanced Automation — Process'

 <# Minimum version of the Windows PowerShell engine required by this module  #>
    PowerShellVersion = '5.1.0.0'

 <# Name of the Windows PowerShell host required by this module  #>
  # PowerShellHostName = ''

 <# Minimum version of the Windows PowerShell host required by this module  #>
  # PowerShellHostVersion = ''

 <# Minimum version of Microsoft .NET Framework required by this module. This
    prerequisite is valid for the PowerShell Desktop edition only  #>
  # DotNetFrameworkVersion = ''

 <# Minimum version of the common language runtime (CLR) required by this module.
    This prerequisite is valid for the PowerShell Desktop edition only  #>
  # CLRVersion = ''

 <# Processor architecture (None, X86, Amd64) required by this module  #>
    ProcessorArchitecture = 'None'

 <# Modules that must be imported into the global environment prior to importing
    this module  #>
  # RequiredModules = @()

 <# Assemblies that must be loaded prior to importing this module  #>
  # RequiredAssemblies = @()

 <# Script files (.ps1) that are run in the caller's environment prior to
    importing this module  #>
  # ScriptsToProcess = @()

 <# Type files (.ps1xml) to be loaded when importing this module  #>
  # TypesToProcess = @()

 <# Format files (.ps1xml) to be loaded when importing this module  #>
  # FormatsToProcess = @()

 <# Modules to import as nested modules of the module specified in RootModule/
    ModuleToProcess  #>
    NestedModules = @(            
        'Get-Privilege.psm1'
        'Get-ProcessToken.psm1'
        'Set-TokenPrivilege.psm1'
    )

 <# Functions to export from this module, for best performance, do not use
    wildcards and do not delete the entry, use an empty array if there are no
    functions to export  #>
    FunctionsToExport = @(
        'Get-Privilege'
        'Get-ProcessToken'
        'Set-TokenPrivilege'
    )

 <# Cmdlets to export from this module, for best performance, do not use
    wildcards and do not delete the entry, use an empty array if there are no
    cmdlets to export  #>
    CmdletsToExport = @()

 <# Variables to export from this module  #>
    VariablesToExport = '*'

 <# Aliases to export from this module, for best performance, do not use
    wildcards and do not delete the entry, use an empty array if there are no
    aliases to export  #>
    AliasesToExport = @()

 <# DSC resources to export from this module  #>
  # DscResourcesToExport = @()

 <# List of all modules packaged with this module  #>
    ModuleList = @(
      # function
        @{ ModuleName = 'Get-Privilege'      ; ModuleVersion = '1.0.2023.1012' }
        @{ ModuleName = 'Get-ProcessToken'   ; ModuleVersion = '1.0.2023.1012' }
        @{ ModuleName = 'Set-TokenPrivilege' ; ModuleVersion = '1.0.2023.1012' }
      # enum
        @{ ModuleName = 'Privilege'          ; ModuleVersion = '1.0.2023.1012' }
        @{ ModuleName = 'PrivilegeAttribute' ; ModuleVersion = '1.0.2023.1012' }
    )

 <# List of all files packaged with this module  #>
    FileList = @(
        'ProcessThreadsApi.cs'  # OpenProcessToken
        'SecurityBaseApi.cs'    # AdjustTokenPrivileges
        'TokenPrivilege.cs'     # TokenPrivilege
        'WinBase.cs'            # LookupPrivilegeValueW
    )

 <# Private data to pass to the module specified in RootModule/ModuleToProcess.
    This may also contain a psData hashtable with additional module metadata used
    by PowerShell  #>
    PrivateData = @{
        psData  = @{

         <# Tags applied to this module. These help with module discovery in
            online galleries  #>
          # Tags = @()

         <# A URL to the license for this module  #>
          # LicenseUri = ''

         <# A URL to the main website for this project  #>
          # ProjectUri = ''

         <# A URL to an icon representing this module  #>
          # IconUri = ''

         <# ReleaseNotes of this module  #>
          # ReleaseNotes = ''

        }  # End of psData hashtable
    }  # End of PrivateData hashtable

 <# HelpInfo URI of this module  #>
  # HelpInfoURI = ''

 <# Default prefix for commands exported from this module. Override the default
  # prefix using Import-Module -Prefix  #>
  # DefaultCommandPrefix = ''
}