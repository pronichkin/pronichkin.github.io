<#
    This is a wrapper around “Set-Content” which does some file name validation
#>

Function
Set-ContentEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Path
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory = $True
        )]
      # [Alias( 'Contents' )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Value
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Text.Encoding]
        $Encoding
    )

    Process
    {
        $Message = "      $Name"

        If
        (
            $Value -like '*$MPElement*'
        )
        {
            Write-Warning -Message $Message
        }
        Else
        {
            Write-Verbose -Message $Message
        }

      # $Name = $Name.Replace( '$', [System.String]::Empty ).Replace( '/', '-' )

        $PathName = Join-Path -Path $Path.FullName -ChildPath $Name

        If
        (
            Test-Path -Path $PathName
        )
        {
            $Message = "`“$PathName`” already exists"
            Write-Warning -Message $Message
        }
        Else
        {
            If
            (
                $Value -match( "`r" )
            )
            {
                $Value = $Value.Trim()
            }
            Else
            {        
                $Value = $Value.Trim() -replace( "`n", [System.Environment]::NewLine )
            }

            $ContentParam = @{

                Path      = $PathName
                Value     = $Value
                Encoding  = $Encoding.EncodingName.Replace( 'US-', [System.String]::Empty )
                NoNewline = $True
            }
            Set-Content @ContentParam
        }
    }
}