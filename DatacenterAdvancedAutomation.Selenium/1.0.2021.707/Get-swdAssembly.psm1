Set-StrictMode -Version 'Latest'

Function
Get-swdAssembly
{
 <#
       .Synopsis
        Update and load Selenium assembly
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [OutputType(
      # [System.Reflection.RuntimeAssembly]
        'System.Reflection.RuntimeAssembly'
    )]

    Param()

    End
    {
       #region Module

            $Repository = Get-psRepository -Name 'psGallery'

            if
            (
                $Repository.InstallationPolicy -eq 'Untrusted'
            )
            {
                Set-psRepository -Name $Repository.Name -InstallationPolicy 'Trusted'
            }

            $ModuleName = @(

                'PackageManagement'
                'PowerShellGet'
            )

            $Module = $ModuleName | ForEach-Object -Process {

                $ModuleFind      = Find-Module -Name $psItem -AllowPrerelease -Repository $Repository.Name
                $ModuleInstalled = Get-Module -Name $ModuleFind.Name -ListAvailable -Verbose:$False | Where-Object -FilterScript {
                    $psItem.Version -eq $ModuleFind.Version.Split( '-' )[0]
                }

                if
                (
                    $ModuleInstalled
                )
                {
                    Write-Message -Channel 'Debug' -Message "Module `“$($ModuleInstalled.Name)`”, version $($ModuleInstalled.Version) already installed"
                }
                else
                {
                  # “-Force” is required to install newer module side-by-side with System ones
                    $ModuleInstalled = Install-Module -InputObject $ModuleFind -Scope 'CurrentUser' -Force -PassThru # -AllowClobber -SkipPublisherCheck

                    $ModuleInstalled = Get-Module -Name $ModuleInstalled.Name -ListAvailable -Verbose:$False | Sort-Object -Property 'Version' | Select-Object -Last 1
                }

                Import-Module -PassThru -ModuleInfo $ModuleInstalled -Verbose:$False   # -Name $psItem.Name -RequiredVersion $psItem.Version
            }

       #endregion Module

       #region Source

          # $RepositoryName = 'psGallery'
            $ProviderName   = 'nuGet'
            $SourceName     = 'nuGet'
            $SourceLocation = 'https://www.nuget.org/api/v2'
            $PackageName    = 'Selenium.WebDriver'

          # $Repository = Get-psRepository -Name $RepositoryName

          # Without “-ForceBootstrap” it will inquery for provider installation if not found
            $Provider = Get-PackageProvider -Name $ProviderName -ForceBootstrap

            $SourceParam = @{
        
                Name     = $SourceName
                Location = $SourceLocation
                Provider = $Provider
            }
            $Source = Get-PackageSourceEx @SourceParam

       #endregion Source

        $PackageParam = @{
        
            Name                    = $PackageName            
            ProviderName            = $Provider.Name
            Source                  = $Source.Name
            AllowPrereleaseVersions = $True
          # ForceBootstrap          = $True
          # AllVersions             = $True
        }
        $PackageAvailable = Find-Package @PackageParam # -ForceBootstrap
      # $PackageAvailable = $PackageAvailable | Sort-Object -Property 'Version' | Select-Object -Last 1  
       
      # [System.Version]$RequiredVersion = $PackageAvailable.Version -split '-' | Select-Object -First 1

        $PackageParam = @{

            ProviderName   = $provider.Name
          # ForceBootstrap = $True
            Scope          = 'CurrentUser'
        }

        $PackageInstalled = Get-Package @PackageParam | Where-Object -FilterScript {

            $psItem.Name    -eq $PackageAvailable.Name
            $psItem.Version -eq $PackageAvailable.Version
        }

        If
        (
            $PackageInstalled
        )
        {
            $Message = "Package `“$($PackageInstalled.Name)`” is already up to date"
            Write-Message -Channel Debug -Message $Message
        }
        Else
        {
            $PackageParam = @{
            
                InputObject      = $PackageAvailable
                Scope            = 'CurrentUser'
                SkipDependencies = $True  # Needed for 4.0.0-beta4 to overcome dependency loop
              # ForceBootstrap   = $True
              # Force            = $True
              # Confirm          = $False
            }
            $PackageInstalled = Install-Package @PackageParam
          # $PackageInstalled = Get-Package -Name $PackageInstalled.Name
          # $PackageInstalled = Get-Package -ProviderName $PackageSourceName -Name $PackageName -RequiredVersion $PackageAvailable.Version -ForceBootstrap -Scope 'CurrentUser'

            $PackageParam = @{

                ProviderName   = $provider.Name
              # ForceBootstrap = $True
                Scope          = 'CurrentUser'
            }

            $PackageInstalled = Get-Package @PackageParam | Where-Object -FilterScript {

                $psItem.Name    -eq $PackageAvailable.Name
                $psItem.Version -eq $PackageAvailable.Version
            }
        }

        $Package = Get-Item -Path $PackageInstalled.Source

        $PathParam = @{

            Path      = $Package.Directory.FullName
            ChildPath = 'lib'
        }
        $Path = Join-Path @PathParam

        $Directory = Get-ChildItem -Path $Path | Where-Object -FilterScript {
            $psItem.Name -notLike 'netStandard*'  -and
            $psItem.Name -notlike 'net5*'
        } | Sort-Object -Property 'Name' | Select-Object -Last 1

        $PathParam = @{

            Path      = $Directory.FullName
            ChildPath = 'WebDriver.dll'
        }
        $Path = Join-Path @PathParam

      # $Type     = Add-Type -Path $LibPath -PassThru
        Return [System.Reflection.Assembly]::LoadFrom( $Path )
    }
}