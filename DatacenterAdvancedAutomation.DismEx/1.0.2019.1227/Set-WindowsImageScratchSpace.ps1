Function
Set-WindowsImageScratchSpace
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
            Mandatory = $True
        )]
        [System.Int32]
        $ScratchSpace
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
        $ImageParam = @{ WindowsImage = $WindowsImage }

        If
        (
            $Log
        )
        {
            $ImageParam.Add( 'Log', $Log )
        }

        If
        (
            $Scratch
        )
        {
            $ImageParam.Add( 'Scratch', $Scratch )
        }
        $ScratchSpaceCurrent = Get-WindowsImageScratchSpace @ImageParam

        If
        (
            $ScratchSpaceCurrent -eq $ScratchSpace
        )
        {
            Write-Verbose -Message "Scratch Space is already $( $ScratchSpace/1mb ) MB"
        }
        Else
        {
            $Argument = [System.Collections.Generic.List[System.String]]::new()

          # Command-specific DISM arguments

            $Argument.Add( "/Set-ScratchSpace:$( $ScratchSpace/1mb )"   )
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

            $ScratchSpace = Invoke-Expression -Command $Dism[6].Replace( 'Scratch Space : ', [System.String]::Empty )

            Write-Verbose -Message "Scratch Space was set to $( $ScratchSpace/1mb ) MB"
        }
    }
}