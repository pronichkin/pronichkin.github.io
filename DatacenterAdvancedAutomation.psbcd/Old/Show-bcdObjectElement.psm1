Using Module '.\ElementType.psm1'
Using Module '.\DeviceType.psm1'

<#
    Formats one or more BCD Object Elements for meaningful display
    
    Note

    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdObjectElement” provides raw output 
    which is more suitable for these scenarios
#>

Function
Show-bcdObjectElement
{
    [CmdletBinding()]

    Param(

        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Element
    )

    Begin
    {
        If
        (
            $Element[0].StoreFilePath
        )
        {
            $Item  = Get-Item -Path $Element.StoreFilePath
            $Store = Get-bcdStore -File $Item
        }
        Else
        {
            $Store = Get-bcdStore
        }

        $Return = @{}
    }

    Process
    {
        $Element | ForEach-Object -Process {
        
            $ElementCurrent = $psItem

            $Type = @{

                Name   = [ElementType].GetEnumName( $ElementCurrent.Type )
                Value  = $ElementCurrent.Type
                Format = $ElementCurrent.CimClass.CimClassName
            }

          # https://docs.microsoft.com/en-us/previous-versions/windows/desktop/bcd/bcd-classes

            Switch
            (
                $psItem.CimClass.CimClassName
            )
            {
                'BcdStringElement'
                {
                    $Value = $ElementCurrent.String
                }

                'BcdDeviceElement'
                {
                    $Value = Show-bcdObjectElementDevice -Element $ElementCurrent
                }

                'BcdObjectListElement'
                {
                    $Value = $ElementCurrent.Ids | ForEach-Object -Process {


                    }
                }

                'BcdBooleanElement'
                {
                    $Value = $ElementCurrent.Boolean
                }

                'BcdIntegerListElement'
                {
                    $Value = $ElementCurrent.Integers
                }

                'BcdIntegerElement'
                {
                    $Value = $ElementCurrent.Integer
                }

                'BcdObjectElement'
                {
                    $Object           =  Get-bcdObject -Store $Store -Id $ElementCurrent.Id
                    $ElementReference =  Get-bcdObjectElement -Object $Object                    
                    $Value            = Show-bcdObjectElement -Element $ElementReference
                }

                Default
                {
                    $Value = "(Unknown value type `“$psItem`”)"
                }
            }

            $Return.Add( $Type, $Value )

          # Return @{ $Type = $Value }
        }
    }

    End
    {
     <# Return $Return | Select-Object -Property @(
        
            @{ n = 'Format'       ; e = { $psitem.Item1 } }
            @{ n = 'Type'         ; e = { $psitem.Item2 } }
            @{ n = 'Value'        ; e = { $psItem.Item3 } }
        )  #>

     <# $ReturnO = @{}

        $Return | ForEach-Object -Process {

            $ReturnO.Add(

                $psItem.Item3, @{

                    'Format' = $psitem.Item1
                    'Type'   = $psitem.Item2
                    'Value'  = $psItem.Item3
                }
            )
        }  #>

        Return $Return.GetEnumerator()
    }
}