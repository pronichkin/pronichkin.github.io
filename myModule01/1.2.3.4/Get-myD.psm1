Function
Get-myD
{
    [CmdletBinding()]
    param()

    process
    {
      # Importing required modules explicitly

        Import-Module -name "$psScriptRoot\Get-myA.psm1"
        Import-Module -name "$psScriptRoot\Get-myB.psm1"
        
        Get-myA
        Get-myB

        return 'd'
    }
}