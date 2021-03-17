Function
Get-myB
{
    [CmdletBinding()]
    param()

    process
    {
        Get-myA

        'b'
    }
}