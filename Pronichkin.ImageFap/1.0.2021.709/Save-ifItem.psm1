Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Save images from a gallery
#>

Function
Save-ifItem
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.IO.FileInfo]
    )]

    param(
    
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [OpenQA.Selenium.Edge.EdgeDriver]
      # Selenium WebDriver
        $Driver
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'Interactive'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # File name to optionally check if file already exists, for interactive
      # use with explicit parameter name
        $Name
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'Interactive'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # File address, for interactive use with explicit parameter name
        $Address
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ValueFromPipeline               = $True,
            ParameterSetName                = 'Pipeline'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.KeyValuePair[    # file
            System.String,                           #   name
            System.Collections.Generic.List[
                System.Uri                           #   address
            ]                                        
        ]]
      # Value pair for use in pipeline inside “Save-ifGallrey”
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.DirectoryInfo]
      # Destination folder, default to current location
        $Path = ( Get-Item -Path '.' )
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Overwrite existing files
        $Force
    )

    begin
    {
        $httpClient = [System.Net.Http.HttpClient]::new()
    }

    process
    {
        switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            'Pipeline'
            {
                $name    = $InputObject.Key
                $address = $InputObject.Value[0]
            }

            'Interactive'
            {
              # All parameters are already assigned
            }

            default
            {
                throw 'Unknown parameter set'
            }
        }
        
        $pathCurrent = Join-Path -Path $Path.FullName -ChildPath $name

        if
        (
           -not $force -and
            ( Test-Path -LiteralPath $pathCurrent )
        )
        {
            Write-Message -Channel 'Debug' -Message "`“$name`” already exists, skipping"
        }
        else
        {
         <# Invoke-WebRequest has a couple of issues which prevent us from
            using it here.

             1. It only generates terminating errors, regarless of ErrorAction
                https://github.com/PowerShell/PowerShell/issues/4534

             2. It treats -OutFile parameter as 'Path' instead of a 'Literal
                Path' and hence makes it impossible to use paths with
                characters like `[ or `]
                https://github.com/PowerShell/PowerShell/issues/3174
    
         <# $response = $null
            $count    = 0
              
            $pathCurrent = [System.Management.Automation.WildcardPattern]::Escape( $pathCurrent )

            while
            (
               -not $Response
            )
            {
                if
                (
                    $count
                )
                {
                    Write-Message -Channel 'Warning' -Message "`“$name`” attempt $count" -Indent 1
                    Start-Sleep -Seconds 1
                }

                try
                {
                    $Response = Invoke-WebRequest -Uri $address.AbsoluteUri -OutFile $pathCurrent -UseBasicParsing -PassThru -Verbose:$false
                }
                catch
                {
                    if
                    (
                        $psItem.Exception -is [System.Net.WebException]
                    )
                    {
                        $Response = $psItem.Exception.Response
                    }
                    else
                    {
                        Write-Message -Channel 'Warning' -Message $psItem.Exception.GetType().FullName
                    }
                }
            }

         <# In case of success, Invoke-WebRequest returns an object of
            [Microsoft.PowerShell.Commands.WebResponseObject] which contains
           “StatusCode” as [System.Int32]. In case of failure, the
            Exception.Response is [System.Net.HttpWebResponse] where
           “StatusCode” is [System.Net.HttpStatusCode]. Hence we need to
            convert them to the same type before extracting value  #>

            $count    = 0
            $response = $false

            while
            (
              -not ( $response -and $response.IsSuccessStatusCode ) -and
               $count -le 5
            )
            {
                if
                (
                    $count
                )
                {
                    Write-Message -Channel 'Warning' -Message "`“$name`” download retry $count" -Indent 1
                    Start-Sleep -Seconds 3
                }

                $response = $httpClient.GetAsync( $address ).Result

                $count++
            }

            if
            (
                $response.IsSuccessStatusCode
            )
            {
                Write-Message -Channel 'Debug'   -Message "`“$name`” $($response.ReasonPhrase)"

                $streamParam = @(
                  # https://docs.microsoft.com/dotnet/api/system.io.filestream.-ctor?view=netframework-4.8#System_IO_FileStream__ctor_System_String_System_IO_FileMode_System_IO_FileAccess_
                    $pathCurrent,                   # path
                    [System.IO.FileMode]::Create,   # mode
                    [System.IO.FileAccess]::Write   # access
                )
                $file     = [System.IO.FileStream]::new.Invoke( $streamParam )

                $download = $response.Content.ReadAsStreamAsync().Result
                $download.CopyTo( $file )
                
                $download.Close()
                $file.Close()
            }
            else
            {
                Write-Message -Channel 'Warning' -Message "`“$name`” $($response.ReasonPhrase)" -Indent 1
            }
        }

        if
        (
            Test-Path -LiteralPath $pathCurrent
        )
        {
            return Get-Item -LiteralPath $pathCurrent
        }
    }

    end
    {
        $httpClient.Dispose()
    }
}