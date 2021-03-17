Function
Get-myB
{
    [CmdletBinding()]
    param()

    process
    {
        Get-myA

        return 'b'
    }
}