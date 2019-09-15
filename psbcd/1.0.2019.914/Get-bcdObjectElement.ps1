Function
Get-bcdObjectElement
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Object
    )

    $EnumerateElement = Invoke-CimMethod -CimInstance $Object -MethodName "EnumerateElements"
    Return $EnumerateElement.Elements
}