Function
Get-myB
{
    [CmdletBinding()]
    param()

    Begin
    {
        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"

        Import-LocalizedData -BindingVariable 'String'

        return $String.bbb
    }
}