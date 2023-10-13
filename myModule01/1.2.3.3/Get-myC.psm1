Function
Get-myC
{
    [CmdletBinding()]
    param()

    process
    {
      # This would rely on ScriptsToProcess and hence leave the functions
      # in user's scope. Note that it's currently broken unless you uncomment 
      # ScriptsToProcess in the module definition

        Get-myA
        Get-myB

        return 'c'
    }
}