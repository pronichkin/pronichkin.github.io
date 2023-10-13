Function
Select-bcdObject
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Object
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.String]
        $Description
    )

    $ElementType = @{

        Description = 0x12000004
    }

    Return $Object | Where-Object -FilterScript {

        $EnumerateElement   = Invoke-CimMethod -CimInstance $PSItem -MethodName "EnumerateElements" -Verbose:$False
        $ElementDescription = $EnumerateElement.Elements | Where-Object -FilterScript { $PSItem.Type -eq $ElementType.Description }    
        $ElementDescription.String -in $Description
    }
}