Function
Get-myC
{
    [CmdletBinding()]
    param()

    process
    {
        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"

      # This would rely on ScriptsToProcess and hence leave the functions
      # in user's scope. Note that it's currently broken unless you uncomment 
      # ScriptsToProcess in the module definition

        Get-myA
        Get-myB

        return 'c'
    }
}