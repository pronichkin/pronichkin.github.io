<#
    This script is inteneded to execute as “Pre-Update Script” in Cluster-
    Aware Updating (CAU.) All logic is offloaded to the “Datacenter Advanced 
    Automation” (DCAA) module.
    
    CAU only accepts “*.ps1” paths for Pre and Post-Update Scripts. Hence, the 
    only purpose of this script is to load the module and run command from it. 
    If you're not CAU, please use the module directly instead of running this 
    script.

    Please note that CAU does not run script “as an actual script.” Instead, it
    copies script contents to a script block and then executes the script block
    in a remote session. Hence we cannot use variables such as “PS Module Path”
    or “My Invocation” to determine actual script location. Instead, to load 
    the modules from a non-default path, we rely on a special “PowerShell 
    Session Configuration” (aka “Endpoint”) to be created by master CAU script
    in advance.
#>

$VerbosePreference     = 'Continue'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'
    
[System.Void]( Start-Transcript )

<#

We cannot use automatic variables when code runs as a script block remotely
Hence instead of setting the path here, we do it in advance.

$Script = Get-Item -Path $myInvocation.myCommand.Path
$env:psModulePath += ";$( $Script.Directory.Parent.Parent.Parent.FullName )"

#>

<#

Cannot use “System.Collections.Generic.List” type in Constrained Language Mode
(“Only core types are supported in this language mode.”)

$ModuleName = [System.Collections.Generic.List[System.String]]::new()
$ModuleName.Add( 'DatacenterAdvancedAutomation.Utility' )
$ModuleName.Add( 'DatacenterAdvancedAutomation' )

#>

[System.String[]]$ModuleName = @(
    'DatacenterAdvancedAutomation.Utility'
    'DatacenterAdvancedAutomation'
)

Import-Module -Name $ModuleName -Verbose:$False
[System.Void]( Import-ModuleEx -Name 'Storage' )

Resume-ClusterNodeEx

[System.Void]( Stop-Transcript )