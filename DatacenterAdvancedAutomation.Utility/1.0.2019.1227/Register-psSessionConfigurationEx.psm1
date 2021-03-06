﻿Set-StrictMode -Version 'Latest'

Function
Register-psSessionConfigurationEx
{
    [cmdletBinding()]

    Param(

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
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.Management.Automation.Runspaces.psSession]]
        $Session
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    Process
    {
        $Session | ForEach-Object -Process {

           #region Check if the Session Configuration already exists

                [System.Management.Automation.ScriptBlock]$ScriptBlock = {

                    [cmdletBinding()]

                    Param(

                        [Parameter(
                            Mandatory = $True
                        )]
                        [ValidateNotNullOrEmpty()]
                        [System.String]
                        $Name
                    )

                    Process
                    {
                        Set-StrictMode -Version 'Latest'
                      # $VerbosePreference     = 'Continue'
                        $ErrorActionPreference = 'Stop'

                        Get-psSessionConfiguration -Verbose:$False | 
                            Where-Object -FilterScript { $psItem.Name -eq $Name }
                    }
                }

                $Argument = [System.Collections.Generic.List[System.Object]]::new()
                $Argument.Add( $Name )

                $CommandParam = @{

                    Session      = $psItem
                    ScriptBlock  = $ScriptBlock
                    ArgumentList = $Argument
                }
                $SessionConfiguration = Invoke-Command @CommandParam
                
                $Argument.Add( $Force )                               

           #endregion Check if the Session Configuration already exists

            If
            (
                $SessionConfiguration -and ( -not $Force )
            )
            {
                $Message = '    DCAA session configuration is already registered'    
                Write-Debug -Message $Message
            }
            Else
            {
                If
                (
                    $SessionConfiguration
                )
                {
                   #region Clean Up existing session configuration

                        $Message = '    Removing existing DCAA session configuration'
                        Write-Debug -Message $Message

                        [System.Management.Automation.ScriptBlock]$ScriptBlock = {

                            [cmdletBinding()]

                            Param(

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
                                [ValidateNotNullOrEmpty()]
                              # [System.Management.Automation.SwitchParameter]
                                [System.Boolean]
                                $Force
                            )

                            Process
                            {
                                Set-StrictMode -Version 'Latest'
                              # $VerbosePreference     = 'Continue'
                                $ErrorActionPreference = 'Stop'

                                $SessionConfigurationParam = @{
                            
                                    Name    = $Name
                                    Verbose = $False
                                    Force   = $Force
                                }
                                Unregister-psSessionConfiguration @SessionConfigurationParam
                            }
                        }

                        $CommandParam.ScriptBlock  = $ScriptBlock
                        $CommandParam.ArgumentList = $Argument

                        $SessionConfiguration = Invoke-Command @CommandParam
                        
                   #endregion Clean Up existing session configuration
                }

               #region Create new Session Configuration

                    $Message = '    Creating DCAA session configuration'
                    Write-Debug -Message $Message

                    $ModulePath = ( Get-Item -Path $psScriptRoot ).Parent.Parent

                  # We cannot send an argument as an actual “System.IO.DirectoryInfo”
                  # object to a remote session. It gets converted to
                  # “Deserialized.System.IO.DirectoryInfo” somewhere in flihgt
                  # and then canot be casted back to “System.IO.DirectoryInfo”
                  # in the remote session. However, sending it as a string works.
                  # $Argument.Add( $ModulePath )
                    $Argument.Add( $ModulePath.FullName )
    
                  # We cannot specify Module Name in Session Configuration 
                  # because apparently “Modules To Import” directive is 
                  # processed *before* the “Environment Variables” one. We need
                  # “PS Module Path” Environmental Variable to be populated 
                  # *before* we can import the module. Hence we skip modules 
                  # here, they will have to be explicitly imported when running 
                  # scripts.

                 <# $ModuleName = [System.Collections.Generic.List[System.String]]::new()
                    $ModuleName.Add( $Location.Parent.Parent.Name )
                    $ModuleName.Add( 'Storage' )

                    $Argument.Add( $ModuleName          )  #>

                  # $Argument | ForEach-Object -Process { Write-Debug -Message $psItem }

                    [System.Management.Automation.ScriptBlock]$ScriptBlock = {

                        [cmdletBinding()]

                        Param(

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
                            [ValidateNotNullOrEmpty()]
                          # [System.Management.Automation.SwitchParameter]
                            [System.Boolean]
                            $Force
                        ,
                            [Parameter(
                                Mandatory = $True
                            )]
                            [ValidateNotNullOrEmpty()]

                          # Cannot use this type because it's not allowed in 
                          # Constrained Language Mode (“Only core types are 
                          # supported in this language mode.”)
                          # [System.IO.DirectoryInfo]
                            [System.String]
                            $ModulePath
                         <# ,
                            [Parameter(
                                Mandatory = $True
                            )]
                            [ValidateNotNullOrEmpty()]
                            [System.Collections.Generic.List[System.String]]
                            $ModuleName  #>
                        )

                        Process
                        {
                            Set-StrictMode -Version 'Latest'
                          # $VerbosePreference     = 'Continue'
                            $ErrorActionPreference = 'Stop'

                            $Path = ".\$Name.pssc"

                            $Description =
                                'Running CAU pre- and post-update scripts using DCAA modules'

                            $EnvironmentVariable = @{

                              # 'psModulePath' = $env:psModulePath + ';' + $ModulePath.FullName
                                'psModulePath' = $env:psModulePath + ';' + $ModulePath
                            }

                            $SessionConfigurationParam = @{

                                Path                 = $Path
                                Description          = $Description
                              # LanguageMode         = 'ConstrainedLanguage'
                                ExecutionPolicy      = 'Unrestricted'
                              # ModulesToImport      = $ModuleName
                                EnvironmentVariables = $EnvironmentVariable
                            }
                            New-psSessionConfigurationFile @SessionConfigurationParam

                            $SessionConfigurationParam = @{
                    
                                Name    = $Name
                                Path    = $Path
                                Verbose = $False
                                Force   = $Force
                            }
                            Register-psSessionConfiguration @SessionConfigurationParam

                            Remove-Item -Path $Path
                        }
                    }

                    $CommandParam.ScriptBlock  = $ScriptBlock
                    $CommandParam.ArgumentList = $Argument

                    Invoke-Command @CommandParam

               #endregion Create new Session Configuration
            }
        }
    }
}