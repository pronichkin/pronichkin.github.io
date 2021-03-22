Function
Get-myA
# Script:Get-myA
# Global:Get-myA
{
    [CmdletBinding()]
    param()

    begin
    {
        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"

        return 'a'
    }
}