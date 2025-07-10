Set-StrictMode -Version 'Latest'

function
Import-Package
{
    [System.Management.Automation.CmdletBindingAttribute()]

 <# [OutputType(
        [System.Reflection.RuntimeAssembly]
    )]  #>

    Param
    (
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true, 
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.AliasAttribute(
            'Name'
        )]
        [System.String]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false 
        )]
        [System.Management.Automation.ValidateNotNullAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Version]
        $Version
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [System.Management.Automation.ValidateNotNullAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [Microsoft.PowerShell.psResourceGet.UtilClasses.ResourceType]
        $Type = [Microsoft.PowerShell.psResourceGet.UtilClasses.ResourceType]::Module
    )

    begin
    {
        if
        (
            $InputObject -eq 'Microsoft.PowerShell.psResourceGet'
        )
        {
          # we're already installing psResourceGet, need to avoid infinte loop
        }
        else
        {
            $resource = Import-Package -InputObject 'Microsoft.PowerShell.psResourceGet'
        }

        switch
        (
            $type
        )
        {
            'PowerShell'
            {
                $name = 'psGallery'
                $uri  = [System.Uri]::new( 'https://www.powershellgallery.com/api/v2' )
            }

            'Package'
            {
                $name = 'nuGet'
                $uri  = [System.Uri]::new( 'https://api.nuget.org/v3/index.json' )
            }
        }

        $repository = Get-psResourceRepository | Where-Object -FilterScript {
            $psItem.Name -eq $name
        }

        if
        (
            $repository
        )
        {}
        else
        {
            $repositoryParam = @{
                Name            = $name
                Uri             = $uri.ToString()
                Trusted         = $true
                PassThru        = $true
            }
            $repository = Register-psResourceRepository @repositoryParam
        }    
    }
    
    process
    {
     <# $findParam = @{

            Name                    = $name
            AllowPrereleaseVersions = $True
            Verbose                 = $false
        }  #>

        $resourceParam = @{
            Name                = $InputObject
            Prerelease          = $true
            Repository          = $repository.Name
            IncludeDependencies = $true
        }

     <# if
        (
            $Version
        )
        {
            $findParam.Add( 'RequiredVersion', $Version.ToString() ) 
        }  #>

        if
        (
            $Version
        )
        {
            $resourceParam.Add( 'Version', $Version.ToString() ) 
        }

     <# $packageFind     = Find-Package    @findParam  #>

        $resourceFind    = Find-psResource @resourceParam
            
     <# $packageLatest  = $packageFind  | Sort-Object -Property 'Version' | Select-Object -Last 1  #>

        $resourceLatest = $resourceFind | Sort-Object -Property 'Version' | Select-Object -Last 1
 
     <# $packageInstall = Get-Package -AllVersions | Where-Object -FilterScript {
    
            $psItem.Name    -eq $name -and
            $psItem.Version -eq $packageLatest.Version
        }  #>

        $resourceInstall = Get-psResource -Verbose:$false | Where-Object -FilterScript {
            $psItem.Name    -eq $resourceLatest.Name -and
            $psItem.Version -eq $resourceLatest.Version
        }

     <# if
        (
            $packageInstall
        )
        {}
        else
        {
            $packageInstall = Install-Package -InputObject $packageLatest -Scope 'CurrentUser' -SkipDependencies -Verbose:$False

            $packageInstall = Get-Package -Name $packageInstall.Name -RequiredVersion $packageInstall.Version
        }  #>

        if
        (
            $resourceInstall
        )
        {}
        else
        {
            $resourceParam = @{
                Name            = $resourceLatest.Name
                Version         = $resourceLatest.Version
                Prerelease      = $true
                Repository      = $repository.Name
                Scope           = [Microsoft.PowerShell.psResourceGet.UtilClasses.ScopeType]::CurrentUser
                TrustRepository = $true
                PassThru        = $true
            }
            $resourceInstall = Install-psResource @resourceParam
        }

        switch
        (
            $type
        )
        {
            'PowerShell'
            {
                $resourceParam = @{
                    Name                = $resourceInstall.Name
                    Verbose             = $false
                }
                Remove-Module @resourceParam

                $resourceParam = @{
                    Name                = $resourceLatest.Name
                    MinimumVersion      = $resourceLatest.Version
                    PassThru            = $true
                    Verbose             = $false
                }
                $moduleImport = Import-Module @resourceParam
            }

            'Package'
            {
             <# $pathParent = Split-Path -Path $packageInstall.Source  #>

                $pathParam = @(
                    $resourceInstall.InstalledLocation
                    $resourceInstall.Name
                    $resourceInstall.Version
                    'lib'
                )
                $libDirectory = [System.IO.Path]::Combine.Invoke( $pathParam )

                $assemblyDirectory = Get-ChildItem -Path $libDirectory | Where-Object -FilterScript {
                  # $psItem.Name -notLike 'netStandard*'  -and
                    $psItem.Name -notlike 'net5*'
                } | Sort-Object -Property 'Name' | Select-Object -Last 1

             <# $pathChild  = 'lib\net5.0\QBittorrent.Client.dll'
                $pathChild  = "lib\netstandard2.0\$name.dll"
              # $pathChild  = 'lib\netstandard2.1\QBittorrent.Client.dll'

                $path       = Join-Path -Path $pathParent -ChildPath $pathChild  #>

                $assemblyPath = Get-ChildItem -Path $assemblyDirectory.FullName -Filter '*.dll'
        
             <# $assembly   = [System.Reflection.Assembly]::LoadFile( $path )

                return $assembly  #>

                return [System.Reflection.Assembly]::LoadFile( $assemblyPath )
            }
        }
    }
    
    end
    {}
}