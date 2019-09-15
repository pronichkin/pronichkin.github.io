Set-StrictMode -Version 'Latest'

Function
Get-scVirtualMachineName
{
    [cmdletBinding()]

    Param(

            [Parameter(
                ParameterSetName = 'Property',
                Mandatory        = $True                
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.Dictionary[System.String, System.String]]
            $Property
        ,
            [Parameter(
                ParameterSetName = 'Name',
                Mandatory        = $True
            )]
          # [ValidateNotNullOrEmpty()]
            [System.String]
            $Name
        ,
            [Parameter(
                Mandatory = $False
            )]
          # [ValidateNotNullOrEmpty()]
            [System.String]
            $DomainAddress
    )

    Process
    {
        If
        (
            $Property
        )
        {
            $Name = $Property.Name

            If
            (
                $Property[ 'DomainAddress' ]
            )
            {
                $DomainAddress = $Property.DomainAddress
            }
        }

        If
        (
            $DomainAddress
        )
        {
            $Name + '.' + $DomainAddress
        }
        Else
        {
            $Name
        }
    }
}
