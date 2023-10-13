Function
Read-WindowsInstallerPackage
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [System.IO.FileInfo]
        $Package
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Collections.Generic.List[System.String]]
        $Property = @(
            'ProductName',
            'ProductVersion'
        )
    )

    Process
    {
        $Value = [System.Collections.Generic.Dictionary[System.String, System.String]]::new()

        $Installer = New-Object -ComObject 'WindowsInstaller.Installer'

        $Database = $Installer.OpenDatabase( $Package.FullName, 0 )  # Read-only

        $Property | ForEach-Object -Process {

            $Query  = "Select Value from Property where Property = '$psItem'"
            $View   = $Database.OpenView( $Query )
            [System.Void]( $View.Execute() )
            $Record = $View.Fetch()
            [System.Void]( $View.Close() )
    
            $Value.Add( $psItem, $Record.StringData( 1 ) )
        }

        Remove-Variable -Name @( 'Database', 'View', 'Record' )

        [System.Void]( [System.Runtime.InteropServices.Marshal]::ReleaseComObject( $Installer ) )
        [System.Void]( [System.GC]::Collect() )

        Return $Value
    }
}