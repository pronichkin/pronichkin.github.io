<#
    Fill in standard Description placeholder for an object
#>

Set-StrictMode -Version 'Latest'

Function
Set-dcaaDescription
{
        [cmdletBinding()]

        Param(

            [parameter(
                Mandatory = $True
            )]
          # [System.Collections.Hashtable]
            $Define
        )

    Process
    {
      # Write-Verbose -Message "Entering Set-DCAADescription for ""$( $Define[ 'Name' ] )"""
        
        $Description = $Define[ "Description" ]

        If
        (
            [System.String]::IsNullOrWhiteSpace( $Description )
        )
        {    
            $ScriptPath = $MyInvocation.ScriptName
            $ScriptName = Split-Path -Path $ScriptPath -Leaf

            $Description =
                "Set by " + $env:USERNAME +
                " with " + $ScriptName            
        }

      # Write-Verbose -Message "The object was defined as ""$Description"""

        If
        (
            $Define -is [System.Collections.Hashtable] -or
            $Define -is [System.Collections.Generic.Dictionary[System.String, System.String]]
        )
        {

            Write-Debug -Message "Set Description property on Hashtable ""$( $Define[ 'Name' ] )"" to ""$Description"""
            $Define.Description = $Description
        }
        Else
        {
            Write-Debug -Message "Return string for ""$Description"""
            Return $Description
        }
    }
}