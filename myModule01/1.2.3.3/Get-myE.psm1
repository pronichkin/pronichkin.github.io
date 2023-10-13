Function
Get-myE
{
    [CmdletBinding()]
    param()

    process
    {
      # This tricks loads the internal functions from the current module

      # & $myInvocation.myCommand.Module { Get-myA }
      # & $myInvocation.myCommand.Module { Get-myB }

        return 'e'
    }
}