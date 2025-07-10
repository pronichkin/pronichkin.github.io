Set-StrictMode -Version 'Latest'

Function
Get-FileHashEx
{
    [System.Management.Automation.CmdletBindingAttribute()]

    Param
    (
        [System.Management.Automation.ParameterAttribute(
            mandatory         = $true,
            valueFromPipeline = $true
        )]
        [System.Management.Automation.AliasAttribute(
            'Path'
        )]
        [System.IO.FileInfo]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.SwitchParameter]
        $Remove
    )

    Begin
    {
        $terminal  = @(
            0x80070143   # ERROR_DATA_CHECKSUM_ERROR  A data integrity checksum error occurred. Data in the file stream is corrupt
        )

        $transient = @(
            0x8007019F   # ERROR_FT_READ_FAILURE      The specified data could not be read from any of the copies
            0x80070003   # ERROR_PATH_NOT_FOUND       Could not find a part of the path
            0x800701B1   # ERROR_NO_SUCH_DEVICE       A device which does not exist was specified
            0x80070057   # ERROR_INVALID_PARAMETER	  The parameter is incorrect
        )
    }

    Process
    {
        $hash = $null

        Write-Message -Channel Debug -Message $InputObject.FullName

       :loop while
        (
           -not $hash
        )
        {
            try
            {
                $hash = Get-FileHash -LiteralPath $InputObject.FullName -ErrorAction Stop
            }
            catch [System.IO.FileNotFoundException]  # might be missing if we moved it in the above catch block
            {
                $message = "$($psItem.Exception.HResult.toString( 'x' ))`t$($psItem.Exception.Message)"
                Write-Message -Channel Warning -Message $message

                $hash = $null

                break loop
            }
            catch [System.IO.IOException]
            {
                $message = "$($psItem.Exception.HResult.toString( 'x' ))`t$($psItem.Exception.Message)"
                Write-Message -Channel Warning -Message $message
            
                Switch
                (
                    $psItem.Exception.HResult
                )
                {
                    {
                        $psItem -in $terminal
                    }
                    {
                        if
                        (
                            $remove
                        )
                        {
                            Remove-Item -Verbose -LiteralPath $InputObject.FullName -Force
                        }
                        else
                        {
                            Write-Message -Channel Warning -Message "Won't remove left file with checksum error: `“$($InputObject.FullName)`”"
                        }

                        $hash = $null

                        break loop
                    }

                    {
                        $psItem -in $transient
                    }
                    {
                        Write-Message -Channel Debug -Message 'retrying...'
                        Start-Sleep -Seconds 60
                    }

                    default
                    {
                        throw 'Unknown IO Exception!'
                    }
                }            
            }
            catch
            {
                $message = "$($psItem.Exception.HResult.toString( 'x' ))`t$($psItem.Exception.Message)"
                Write-Message -Channel Warning -Message $message

                throw 'Unknown issue with Left!'
            }
        }

        return $hash
    }
}