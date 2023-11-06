<#
    Import module silently
#>

Set-StrictMode -Version 'Latest'

Function
Import-ModuleEx
{

   #region Data

        [cmdletBinding()]

        Param(

            [parameter(
                ParameterSetName = 'Name',
                Mandatory        =  $True
            )]
            [System.String[]]
            $Name
        ,
            [parameter(
                ParameterSetName = 'ModuleInfo',
                Mandatory        =  $True
            )]
            [System.Management.Automation.PSModuleInfo]
            $ModuleInfo
        )

   #endregion Data

   #region Code

      # When we have $VerbosePreference defined as "Continue" and import
      # a module (either implicitly, by firt use, or explictily, calling
      # “Import-Module”), there's a lot of Verbose output listing every cmdlet
      # and every function. This output provides no value, thus we need
      # to suppress it. Unfortunately, even if we pass “-Verobse:$False”
      # to “Import-Module”, it only helps to swallow the list of cmdlets.
      # The list of functions is still thrown to output. (This is probably
      # a bug). Thus, we need to temporary change $VerbosePreference.

        $VerbosePreferenceCurrent = $VerbosePreference
        $Global:VerbosePreference = "SilentlyContinue"

        $DebugPreferenceCurrent   = $DebugPreference
        $Global:DebugPreference   = "SilentlyContinue"

        If
        (
            Test-Path -Path "Variable:\ModuleInternal"
        )
        {
          # $Item = Remove-Item -Path "Variable:\ModuleInternal" -Confirm:$false

          # Remove-Variable -Name "Module" -scope "Global"
          # Remove-Variable -Name "Module" -scope "Local"
            Remove-Variable -Name "Module" -scope "Script"
        }

        $ModuleParam = @{
        
            PassThru      = $True
            Global        = $True
          # WarningAction = 'Ignore'
        }

        Switch
        (
            $psCmdlet.ParameterSetName
        ) 
        { 
            'Name'
            {
                Switch
                (
                    $Name
                )
                {
                    'VirtualMachineManager'
                    {
                        If
                        (
                            Get-Module -ListAvailable -Verbose:$False | Where-Object {
                                $psItem.name -eq $Name
                            }
                        )
                        {
                          # Name was resolved successfully. Nothing to do
                        }
                        Else
                        {
                            $ProductAll  = Get-ChildItem -Path $env:ProgramFiles -Filter "Microsoft System Center*"  
                            $Product     = $ProductAll | Sort-Object -Property 'Name' | Select-Object -Last 1

                            $PathParam = @{

                                Path      = $Product.FullName
                                ChildPath = "Virtual Machine Manager\bin\psModules\VirtualMachineManager\VirtualMachineManager.psd1"
                            }
                            $Name = Join-Path @PathParam

                            If
                            (
                                Test-Path -Path $Name
                            )
                            {
                              # Path was resolved successfully
                            }
                            Else
                            {
                                $Message = 'Module “VirtualMachineManager” could not be located'
                                Write-Warning -Message $Message
                            }
                        }
                    }

                    'Hyper-V'
                    {
                        $ModuleParam.Add( 'MinimumVersion', '2.0.0.0' )
                    }

                    Default
                    {
                        If
                        (
                            Get-Module -Name $Name -ListAvailable
                        )
                        {
                          # $ModuleInternal = Import-Module -Name $Name -PassThru -WarningAction Ignore
                        }
                        ElseIf
                        (
                            Test-Path  -Path $Name
                        )
                        {
                            $Name = ( Resolve-Path -Path $Name ).ProviderPath
                        }
                        Else
                        {
                            $Message = "Module `“$Name`” was not found"
                            Write-Warning -Message $Message
                        }
                    }
                }

                $ModuleParam.Add( 'Name', $Name )
            } 

            "ModuleInfo"
            {
                $ModuleParam.Add( 'ModuleInfo', $ModuleInfo )
            } 
        }

        $ModuleInternal = Import-Module @ModuleParam

        $Global:VerbosePreference = $VerbosePreferenceCurrent
        $Global:DebugPreference   = $DebugPreferenceCurrent

        If
        (
            Test-Path -Path "Variable:\ModuleInternal"
        )
        {
            Return $ModuleInternal
        }

   #endregion Code

}