Function
Get-WindowsImageScratchSpace
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

        $Argument.Add( '/Get-ScratchSpace'                          )
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
      
      # Parse output and convert to size in bytes

        Return Invoke-Expression -Command $Dism[8].Replace( 'Scratch Space : ', [System.String]::Empty )
    }
}