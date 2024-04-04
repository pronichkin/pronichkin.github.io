Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Create a subdirectory with a random name under the default temp path

   .DESCRIPTION
    This is similar to `Path.GetTempFileName()`
    (https://docs.microsoft.com/dotnet/api/system.io.path.gettempfilename)
    and `New-TemporaryFile` cmdlet
    (https://docs.microsoft.com/powershell/module/Microsoft.PowerShell.Utility/New-TemporaryFile)
    in the sense that it *does* create the target object (unlike
    `Path.GetRandomFileName()`)
#>

function
New-TemporaryDirectory
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.IO.DirectoryInfo]
    )]

    param
    ()

    begin
    {}

    process
    {
        $pathParam = @{
          # https://docs.microsoft.com/dotnet/api/system.io.path.gettemppath
            Path     = [System.IO.Path]::GetTempPath()
          # https://docs.microsoft.com/dotnet/api/system.io.path.getrandomfilename
            Name     = [System.IO.Path]::GetRandomFileName()
            ItemType = 'Directory'
        }
        New-Item @pathParam
    }

    end
    {}
}