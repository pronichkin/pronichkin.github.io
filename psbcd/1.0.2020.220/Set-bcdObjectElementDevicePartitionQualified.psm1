using module '.\ElementType.psm1'
using module '.\Flag.psm1'

Function
Set-bcdObjectElementDevicePartitionQualified
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
        [Microsoft.Windows.Storage.PartitionStyle]
        $PartitionStyle
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.Guid]
        $DiskSignature
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.Guid]
        $PartitionIdentifier
    )

    Process
    {
        $Argument = @{

            'Type'                = $Type
            'PartitionStyle'      = $PartitionStyle
            'DiskSignature'       = '{' + $DiskSignature       + '}'
            'PartitionIdentifier' = '{' + $PartitionIdentifier + '}'
        }

        $MethodParam = @{

            InputObject = $Object
            MethodName  = 'SetQualifiedPartitionDeviceElement'
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
                Flag   = [Flag]::Qualified
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