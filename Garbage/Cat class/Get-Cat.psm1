using module '.\Cat.psm1'

Function
Get-Cat
{
    [cmdletBinding()]
    
    Param
    (
        [Parameter()]
        [System.String]
        $Name
    )

    Process
    {
        [cat]::new( $Name )
    }
}