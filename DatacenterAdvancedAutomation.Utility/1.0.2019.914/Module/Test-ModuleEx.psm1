Set-StrictMode -Version 'Latest'

Function
Test-ModuleEx
{
    [cmdletBinding()]

    Param()
    
    Process
    {
        [System.Void]( Import-ModuleEx -Name 'Hyper-V' )

        Switch
        (
            [Microsoft.HyperV.PowerShell.vmSwitch].Assembly.ManifestModule.Name
        )
        {
            'Microsoft.HyperV.PowerShell.dll'
            {
                $Message = 'Old Hyper-V assembly was loaded. Please try re-running the script in a new PowerShell window (not a new tab!)'
                Write-Error -Message $Message
            }

            'Microsoft.HyperV.PowerShell.Objects.dll'
            {
                $Message = 'The new Hyper-V assembly was detected. Processing'
                Write-Debug -Message $Message
            }

            Default
            {
                $Message = 'An unknown version of Hyper-V assembly was loaded. Results may be unpredictable'
                Write-Warning -Message $Message
            }
        }
    }
}
