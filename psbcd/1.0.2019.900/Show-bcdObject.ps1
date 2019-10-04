Function
Show-bcdObject
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Object
    )

    $ElementType = @{

        Description = 0x12000004
    }

    $Object | ForEach-Object -Process {

        $EnumerateElement = Invoke-CimMethod -CimInstance $PSItem -MethodName "EnumerateElements" -Verbose:$False
        Return $EnumerateElement.Elements | Where-Object -FilterScript { $PSItem.Type -eq $ElementType.Description } | Select-Object -Property @( "ObjectId", "String" )
    }
}