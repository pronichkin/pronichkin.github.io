# Robocopy wrapper

Function
Copy-ItemEx
{
    [CmdletBinding()]

    Param (
        [Parameter()]
        [System.IO.FileSystemInfo]
        $Path
    ,
        [Parameter()]
        [System.Io.DirectoryInfo]
        $Destination
    ,
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Move
    ,
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Large
    )

    If ( $Move )
    {
        $Argument += "/Move"

        $Message = "Moving"
    }
    Else
    {
        $Message = "Copying"
    }

    If ( $Path.psIsContainer )
    {   
        $Source      = $Path.FullName     
        $Destination = Join-Path -Path $Destination.FullName -ChildPath $Path.Name        

        $Message += " directory `“$Source`” to `“$Destination`”"

        $Argument = @(

            $Source
            $Destination
            "/s"
        )
    }
    Else
    {
        $Source      = $Path.Directory
        $Destination = $Destination.FullName
        $Name        = $Path.Name

        $Message += " file `“$Name`” from `“$Source`” to `“$Destination`”"

        $Argument = @(

            $Source
            $Destination
            $Name
        )
    }

    If ( $Large )
    {
        $Message += " using large file optimization"

        $Argument += "/zb /j"
    }

    $Argument += "/np"

    $FilePath = Join-Path $env:SystemRoot -ChildPath "System32\RoboCopy.exe"

    $SuccessfulErrorCode = (0..8) + 16

    $StartProcessExParam = @{

        FilePath            = $FilePath
        ArgumentList        = $Argument
        SuccessfulErrorCode = $SuccessfulErrorCode
    }    
    
    Write-Verbose -Message $Message

    $Process = Start-ProcessEx @StartProcessExParam

    Switch( $Process )
    {
        0
        {
            $Message = "No files were copied. No failure was encountered. No files were mismatched. The files already exist in the destination directory; therefore, the copy operation was skipped."
            Write-Verbose -Message $Message
        }

        1
        {
            $Message = "All files were copied successfully."
            Write-Verbose -Message $Message
        }

        2
        {
            $Message = "There are some additional files in the destination directory that are not present in the source directory. No files were copied."
            Write-Verbose -Message $Message
        }

        3
        {
            $Message = "Some files were copied. Additional files were present. No failure was encountered."
            Write-Verbose -Message $Message
        }

        4
        {
            $Message = "Mismatched files or directories were detected.  Examine the log file for more information."
            Write-Verbose -Message $Message
        }

        5
        {
            $Message = "Some files were copied. Some files were mismatched. No failure was encountered."
            Write-Verbose -Message $Message
        }

        6
        {
            $Message = "Additional files and mismatched files exist. No files were copied and no failures were encountered. This means that the files already exist in the destination directory. "
            Write-Verbose -Message $Message
        }

        7
        {
            $Message = "Files were copied, a file mismatch was present, and additional files were present."
            Write-Verbose -Message $Message
        }

        8
        {
            $Message = "Some files or directories could not be copied and the retry limit was exceeded."
            Write-Error -Message $Message
        }

        16
        {
            $Message = "Robocopy did not copy any files.  Check the command line parameters and verify that Robocopy has enough rights to write to the destination folder."
            Write-Error -Message $Message
        }
    }

    $Item = Get-Item -Path $Destination.FullName

    Return $Item
}