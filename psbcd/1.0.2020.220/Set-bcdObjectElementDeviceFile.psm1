using module '.\ElementType.psm1'
using module '.\Flag.psm1'
using module '.\DeviceType.psm1'

Function
Set-bcdObjectElementDeviceFile
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
        [DeviceType]
        $DeviceType
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Guid]
        $AdditionalOptions
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.String]
        $Path
    ,
        [Parameter(
            Mandatory = $True
        )]
        [DeviceType]
        $ParentDeviceType
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Guid]
        $ParentAdditionalOptions
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.String]
        $ParentPath
    )

    Process
    {
        $Argument = @{

            'Type'              = $Type
            'DeviceType'        = $DeviceType
            'Path'              = $Path
            'ParentDeviceType'  = $ParentDeviceType
            'ParentPath'        = $ParentPath
        }

        If
        (
            $AdditionalOptions
        )
        {
            $Argument.Add( 'AdditionalOptions', '{' + $AdditionalOptions + '}' )
        }
        Else
        {
            $Argument.Add( 'AdditionalOptions', [System.String]::Empty )
        }

        If
        (
            $ParentAdditionalOptions
        )
        {
            $Argument.Add( 'ParentAdditionalOptions', '{' + $ParentAdditionalOptions + '}' )
        }
        Else
        {
            $Argument.Add( 'ParentAdditionalOptions', [System.String]::Empty )
        }    
    
        $MethodParam = @{

            InputObject = $Object
            MethodName  = 'SetFileDeviceElement'
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