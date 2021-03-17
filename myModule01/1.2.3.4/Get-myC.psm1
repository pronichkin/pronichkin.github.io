Function
Get-myC
{
    [CmdletBinding()]
    param()

    process
    {
        & $myInvocation.myCommand.Module { Get-myA }
        & $myInvocation.myCommand.Module { Get-myB }

        return 'c'
    }
}