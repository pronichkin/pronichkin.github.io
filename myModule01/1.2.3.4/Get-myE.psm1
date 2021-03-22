Function
Get-myE
{
    [CmdletBinding()]
    param()

    Begin
    {
        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"

      # This tricks loads the internal functions from the current module

        & ( Get-Module | Where-Object -FilterScript { $ExecutionContext.SessionState.Module -in $psItem.NestedModules } ) { Get-myA }
        & ( Get-Module | Where-Object -FilterScript { $ExecutionContext.SessionState.Module -in $psItem.NestedModules } ) { Get-myB }

        return 'e'
    }
}