Set-StrictMode -Version 'Latest'

function
Import-Package
{
    [CmdletBinding()]

 <# [OutputType(
        [System.Reflection.RuntimeAssembly]
    )]  #>

    Param
    (
        [Parameter(
            Mandatory         = $true, 
            ValueFromPipeline = $true
        )]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory         = $false 
        )]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [System.Version]
        $Version
    )

    Begin
    {}
    
    Process
    {
        $findParam = @{

            Name                    = $name
            AllowPrereleaseVersions = $True
            Verbose                 = $false
        }

        if
        (
            $Version
        )
        {
            $findParam.Add( 'RequiredVersion', $Version.ToString() ) 
        }

        $packageFind    = Find-Package @findParam
    
        $packageLatest  = $packageFind | Sort-Object -Property 'Version' | Select-Object -Last 1
    
        $packageInstall = Get-Package -AllVersions | Where-Object -FilterScript {
    
            $psItem.Name    -eq $name -and
            $psItem.Version -eq $packageLatest.Version
        }

        if
        (
            $packageInstall
        )
        {}
        else
        {
            $packageInstall = Install-Package -InputObject $packageLatest -Scope 'CurrentUser' -SkipDependencies -Verbose:$False

            $packageInstall = Get-Package -Name $packageInstall.Name -RequiredVersion $packageInstall.Version
        }

        $pathParent = Split-Path -Path $packageInstall.Source

      # $pathChild  = 'lib\net5.0\QBittorrent.Client.dll'
        $pathChild  = "lib\netstandard2.0\$name.dll"
      # $pathChild  = 'lib\netstandard2.1\QBittorrent.Client.dll'

        $path       = Join-Path -Path $pathParent -ChildPath $pathChild
        $assembly   = [System.Reflection.Assembly]::LoadFile( $path )

        return $assembly
    }
    
    End
    {}
}