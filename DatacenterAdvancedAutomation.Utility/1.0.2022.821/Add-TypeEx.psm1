Set-StrictMode -Version 'Latest'

<#
   .Synopsis
    Add type based on a definition from a c# source file

   .Description
    Add type based on a definition from a c# source file. This will search for
    the file based on an established naming convention.

   .Example
    ...

   .Link
    ...

   .Notes
    ...
#>


Function
Add-TypeEx
{
    [System.Management.Automation.CmdletBindingAttribute(
        PositionalBinding = $False
    )]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Void]
    )]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.AliasAttribute(
            'Name'
        )]
        [System.String]
     <# Name for the source file, and for the resulting type  #>
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]
        [System.String]
     <# Namespace. Default to the name of the calling module  #>
        $Namespace = (Get-psCallStack)[1].InvocationInfo.MyCommand.Module.Name
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]
        [System.IO.DirectoryInfo]
     <# Source path. Default to the path of the calling module  #>
        $Path = (Get-psCallStack)[1].InvocationInfo.MyCommand.Module.ModuleBase
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]        
        [System.Management.Automation.SwitchParameter]
     <# Generate assembly file (.dll) at random path  #>
        $OutputAssembly
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False,
            DontShow          = $True
        )]        
        [System.IO.FileInfo]
     <# Generate assembly file (.dll) at specified path  #>
        $OutputAssemblyPath
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]        
        [System.IO.FileInfo[]]
     <# Dependency assembly file(s) (.dll)  #>
        $ReferencedAssembly
    )

    begin    
    {
        Write-Message -Channel Debug -Message 'Enter Add-TypeEx'

        Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"
        Write-Debug -Message "myInvocation InvocationName:          $($myInvocation.InvocationName)"
        Write-Debug -Message "psScriptRoot:                         $($psScriptRoot)"
        Write-Debug -Message "psCommandPath:                        $($psCommandPath)"

        Write-Debug -Message "Stack[1] Module Mame:                 $($(Get-psCallStack)[1].InvocationInfo.MyCommand.Module.Name)"
        Write-Debug -Message "Stack[1] Moduke Base:                 $($(Get-psCallStack)[1].InvocationInfo.MyCommand.Module.ModuleBase)"
    }

    process{

        $PathParam = @{
            Path      = $Path
            ChildPath = "$InputObject.cs"
        }
        $SourcePath = Join-Path @PathParam

        $TypeParam = @{
            Path                 = $SourcePath
            Debug                = $False            
        }

        $Assembly = [System.AppDomain]::CurrentDomain.GetAssemblies()

        if
        (        
            $OutputAssemblyPath
        )
        {
            $Message = "Will generate assembly file (.dll) at `“$OutputAssemblyPath`”"
        }
        elseIf
        (
            $OutputAssembly
        )
        {
         <# This *has to* have a '.dll' extension, otherwise `Add-Type` with
          `-ReferencedAssemblies` fail with:
        
           “Could not load file or assembly '<path>' or one of its dependencies.
            The given assembly name or codebase was invalid.
            (Exception from HRESULT: 0x80131047)”
          #>            
            $PathParam = @{
                Path      = $env:Temp
                ChildPath = [System.IO.Path]::GetRandomFileName() + '.dll'
            }
            $OutputAssemblyPath = Join-Path @PathParam

            $Message = "Will generate assembly file (.dll) at `“$OutputAssemblyPath`”"
        }
        else
        {
            $Message = 'Will only generate assembly in memory'
        }

        Write-Message -Channel Debug -Message $Message
        



        

            if
            (
                $Assembly | Where-Object -FilterScript {
                    $psItem.DefinedTypes | Where-Object -FilterScript {
                        $psItem.Name -eq 'PrivilegeState'
                    }
                }
            )
            {
                $PrivilegeStateType =
                    [DatacenterAdvancedAutomation.Process.PrivilegeState]
            }
            else
            {
                $PrivilegeStateType = Add-Type @TypeParam
            }



    }

    end
    {
        Write-Message -Channel Debug -Message 'Exit  Add-TypeEx'    
    }
}
