Function
Set-WindowsImageTargetPath
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
        [System.String]
        $TargetPath
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
        $TargetPathCurrent = Get-WindowsImageTargetPath @ImageParam

        If
        (
            $TargetPathCurrent.TrimEnd( '\ ' ) -eq $TargetPath
        )
        {
            Write-Verbose -Message "Target Path is already ""$TargetPath"""
        }
        Else
        {
            $Argument = [System.Collections.Generic.List[System.String]]::new()

          # Command-specific DISM arguments

            $Argument.Add( "/Set-TargetPath:$TargetPath"                )
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

            $TargetPath = $Dism[6].Replace( 'Target Path : ', [System.String]::Empty )

            Write-Verbose -Message "Target Path was set to ""$TargetPath"""
        }
    }
}