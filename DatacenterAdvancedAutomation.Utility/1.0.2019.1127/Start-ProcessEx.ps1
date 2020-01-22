Function
Start-ProcessEx
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [System.String]
        $FilePath
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Collections.Generic.List[System.String]]
        $ArgumentList
    )

    Process
    {
      # https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo
        $ProcessStartInfo = [System.Diagnostics.ProcessStartInfo]::new( $FilePath )

        Write-Debug -Message $ProcessStartInfo.FileName

        $ProcessStartInfo.RedirectStandardError  = $True
        $ProcessStartInfo.RedirectStandardOutput = $True
        $ProcessStartInfo.UseShellExecute        = $False
        $ProcessStartInfo.WindowStyle            = 'Hidden'
        $ProcessStartInfo.CreateNoWindow         = $True

        If
        (
            $ArgumentList
        )
        {
            $ProcessStartInfo.Arguments = $ArgumentList -join ' '

            Write-Debug -Message $ProcessStartInfo.Arguments
        }

      # https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.process.start
        $Process = [System.Diagnostics.Process]::Start( $ProcessStartInfo )

        $StandardError  = $Process.StandardError.ReadToEnd()
        $StandardOutput = $Process.StandardOutput.ReadToEnd()

        $Process.WaitForExit()

        If
        (
            $StandardError
        )
        {
            Write-Warning -Message $StandardError -Split "`r`n"
        }

        Return $StandardOutput -Split "`r`n"
    }
}