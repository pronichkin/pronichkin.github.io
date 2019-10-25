Function
Get-bcdStore
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]
        $File
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession]
        $CimSession
    )

    If
    (
        $File
    )
    {
        $Path = $File.FullName
    }
    Else
    {
        $Path = [System.String]::Empty
    }

    $ClassParam = @{

        ClassName = 'BcdStore'
        Namespace = 'root\wmi'
        Verbose   = $False
    }

    If
    (
        $CimSession
    )
    {
        $ClassParam.Add( 'CimSession', $CimSession )
    }

    $BcdStore    = Get-CimClass @ClassParam

    $Argument = @{ "File" = $Path }

    # The CreateStore, OpenStore, and ImportStore methods are static methods; they can be called without an instance of the class. To do so, open a WMI object that represents the BcdStore class and call these methods.
    $OpenStore = Invoke-CimMethod -CimClass $BcdStore -MethodName "OpenStore" -Arguments $Argument -Verbose:$False 

    Return $OpenStore.Store
}