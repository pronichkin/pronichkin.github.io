Using Module '.\ObjectType.psm1'
Using Module '.\ElementType.psm1'

<#
    Formats one or more BCD Objects for meaningful display
    
    Note

    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdObject” provides raw output which
    is more suitable for these scenarios
#>

Function
Show-bcdObject
{
    [CmdletBinding()]

    Param(

        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Object
    )

    Begin
    {}

    Process
    {
        $Return = $Object | ForEach-Object -Process {

            $TypeName = [ObjectType].GetEnumName( $psItem.Type )

            $Element = Get-bcdObjectElement -Object $psItem -Type Description
            
            If
            (
                $Element
            )
            {
                $Description = $Element.String
            }
            Else
            {
                $Description = [System.String]::Empty
            }

         <# Return @{

                'Id'          = $psItem.Id
                'Type'        = $psItem.Type
                'TypeName'    = $TypeName
                'Description' = $Description
            }  #>

         <# $Return = [System.Collections.Generic.Dictionary[System.String, System.String]]::new()
            $Return.Add( 'Id',          $psItem.Id   )
            $Return.Add( 'Type',        $psItem.Type )
            $Return.Add( 'TypeName',    $TypeName    )
            $Return.Add( 'Description', $Description )

            Return $Return  #>

            [System.Tuple[
                System.Guid, System.UInt32, System.String, System.String
            ]]::new( $psItem.Id, $psItem.Type, $TypeName, $Description )
        }
    }

    End
    {
         Return $Return | Select-Object -Property @(
        
            @{ n = 'ID'           ; e = { $psItem.Item1 } }
            @{ n = 'Type'         ; e = { $psitem.Item2 } }
            @{ n = 'Type Name'    ; e = { $psItem.Item3 } }
            @{ n = 'Description'  ; e = { $psItem.Item4 } }
        )
    }
}