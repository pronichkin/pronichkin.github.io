Function
Start-Dism
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [System.Collections.Generic.List[System.String]]
        $Argument
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.IO.DirectoryInfo]
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
        $FilePath = Join-Path -Path $( [System.Environment]::SystemDirectory ) -ChildPath 'Dism.exe'

      # Generic DISM arguments

        $Argument.Add( '/English'                                   )
        $Argument.Add( '/Format:List'                               )
      # $Argument.Add( '/Quiet'                                     )  # Cannot be used with "/Get-"

        If
        (
            $Scratch
        )
        {
            $Argument.Add( "/ScratchDir:""$( $Scratch.FullName )""" )
        }
        
      # Invoke DISM

      # Write-Debug -Message $FilePath
      # Write-Debug -Message $( $Argument -Join ' ' )

        $ProcessParam = @{

            FilePath            = $FilePath            
            InformationVariable = 'Dism'
        }

        If
        (
            $Log
        )
        {
            $ProcessParam.Add( 'Log', $Log )

            $TimeStamp = Get-Date -Format 'FileDateTime'

            $LogPath = Join-Path -Path $Log -ChildPath "Dism—$TimeStamp.txt"

            $Argument.Add( '/LogLevel:4'                  )  # Errors, warnings, and informational, plus debug output
            $Argument.Add( "/LogPath:""$LogPath"""        )
        }        

        $ProcessParam.Add( 'ArgumentList', $Argument )

        $Return = Start-ProcessEx @ProcessParam
        $Output = $Dism[0].MessageData -Split "`r`n"

        If
        (   
            $Return -eq 0 -and
            $Output[ -2 ] -eq 'The operation completed successfully.'
        )
        {
            Return $Output
        }
        Else
        {
            $Message = "Dism exited with return code $Return"
            Write-Warning -Message $Message

            Write-Warning -Message $Dism[0].MessageData
        }
    }
}