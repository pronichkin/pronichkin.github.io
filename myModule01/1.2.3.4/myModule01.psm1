##Requires -Modules Get-myB

Function
Get-myNothing
{
    [CmdletBinding()]
    param()

    process
    {
        Get-myA
        Get-myB
    }
}