Function
Get-WindowsImageTargetPath
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [Microsoft.Dism.Commands.ImageObject]
        $WindowsImage
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.IO.FileInfo]
        $Log
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.IO.DirectoryInfo]
        $Scratch
    )

    Process
    {
        $Argument = [System.Collections.Generic.List[System.String]]::new()

      # Command-specific DISM arguments

        $Argument.Add( '/Get-TargetPath'                            )
        $Argument.Add( "/Image:""$( $WindowsImageMount.Path )"""    )

        $DismParam = @{ Argument = $Argument }

        If
        (
            $Log
        )
        {
            $DismParam.Add( 'Log', $Log )
        }

        If
        (
            $Scratch
        )
        {
            $DismParam.Add( 'Scratch', $Scratch )
        }

      # Invoke DISM

        $Dism = Start-Dism @DismParam
      
        Return $Dism[8].Replace( 'Target Path : ', [System.String]::Empty )
    }
}