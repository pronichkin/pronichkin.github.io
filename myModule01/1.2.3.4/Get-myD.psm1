Function
Get-myD
{
    [CmdletBinding()]
    param()

    Begin
    {
        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"

      # Importing required modules explicitly

        Import-Module -name "$psScriptRoot\Get-myA.psm1" -Verbose:$False
        Import-Module -name "$psScriptRoot\Get-myB.psm1" -Verbose:$False
        
        Get-myA
        Get-myB

        return 'd'
    }
}