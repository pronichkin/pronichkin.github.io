Function
Get-myC
{
    [CmdletBinding()]
    param()

    process
    {
        Get-myA        
        Get-myB

        return 'c'
    }
}