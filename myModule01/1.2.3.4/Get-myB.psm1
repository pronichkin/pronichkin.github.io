Function
Get-myB
{
    [CmdletBinding()]
    param()

    process
    {
        Import-LocalizedData -BindingVariable 'String'

        return $String.bbb
    }
}