##Requires -Modules Get-myB

# Import-Module -Name "$psScriptRoot\Get-myA.psm1" -Verbose:$False -Scope 'Local'  # default, does not work
# Import-Module -Name "$psScriptRoot\Get-myA.psm1" -Verbose:$False -Scope 'Global' # works, exposes the function

# . "$psScriptRoot\Get-myA.ps1"
# . "$psScriptRoot\Get-myE.ps1"

# Invoke-Command -ScriptBlock { "$psScriptRoot\Get-myE.ps1" } -NoNewScope

Function
Get-myModule
{
    [CmdletBinding()]
    param()

    Begin
    {
        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"

        Get-myA
        Get-myB
    }
}

Function
Get-myModulePrivate
{
    [CmdletBinding()]
    param()

    Begin
    {
        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"

        Get-myA
        Get-myB
    }
}