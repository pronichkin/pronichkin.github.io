using module '.\ElementType.psm1'
using module '.\Flag.psm1'
using module '.\DeviceType.psm1'

Function
Set-bcdObjectElementInteger
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Object
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ElementType]
        $Type
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.UInt64]
        $Value
    )

    Process
    {
        $Argument = @{

            'Type'           = $Type
            'Integer'        = $Value
        }

        $MethodParam = @{

            InputObject = $Object
            MethodName  = 'SetIntegerElement'
            Arguments   = $Argument
            Verbose     = $False
        }
        $Element = Invoke-CimMethod @MethodParam

        If
        (
            $Element.ReturnValue
        )
        {
            $ElementParam = @{
            
                Object = $Object
                Type   = $Type
            }
            $Element = Get-bcdObjectElement @ElementParam

            Return $Element
        }
        Else
        {
            Throw
        }
    }
}