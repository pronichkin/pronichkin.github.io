# Import module silently

Function
Import-ModuleEx
{

   #region Data

        [cmdletbinding()]

        Param(

            [parameter(
                ParameterSetName = "Name",
                Mandatory        =  $True
            )]
            [System.String]
            $Name,
            [parameter(
                ParameterSetName = "ModuleInfo",
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

        If (Test-Path -Path "Variable:\ModuleInternal")
        {
          # $Item = Remove-Item -Path "Variable:\ModuleInternal" -Confirm:$false

          # Remove-Variable -Name "Module" -Scope "Global"
          # Remove-Variable -Name "Module" -Scope "Local"
            Remove-Variable -Name "Module" -Scope "Script"
        }

        Switch ($PsCmdlet.ParameterSetName)
        {
            "Name"
            {
                If (( Get-Module -Name $Name -ListAvailable ) -Or
                    ( Test-Path  -Path $Name ))
                {
                    $ModuleInternal = Import-Module -Name $Name -PassThru -WarningAction Ignore
                }
            }

            "ModuleInfo"
            {
                $ModuleInternal = Import-Module -ModuleInfo $ModuleInfo -PassThru -WarningAction Ignore
            }
        }

        $Global:VerbosePreference = $VerbosePreferenceCurrent

        If (Test-Path -Path "Variable:\ModuleInternal")
        {
            Return $ModuleInternal
        }

   #endregion Code

}