Set-StrictMode -Version 'Latest'

 <#
   .Synopsis
    Add type based on a definition from a c# source file

   .Description
    Add type based on a definition from a c# source file. The typical use case is
    internal for DCAA functions. By default, this command will search for the
    source file based on an DCAA naming convention:
      * the class name is the same as specified file base name;
      * the namespace name is the same as calling module name;
      * the file is located in the same directory as calling module.

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
      # [System.String]
     <# Namespace. Default to the name of the calling module  #>
      # $Namespace = (Get-psCallStack)[1].InvocationInfo.MyCommand.Module.Name
        $Namespace = (Get-psCallStack)[0].InvocationInfo.MyCommand.Module.Name
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]
      # [System.IO.DirectoryInfo]
     <# Source path. Default to the path of the calling module  #>
      # $Path = (Get-psCallStack)[1].InvocationInfo.MyCommand.Module.ModuleBase
        $Path = (Get-psCallStack)[0].InvocationInfo.MyCommand.Module.ModuleBase
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
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]        
        [System.Management.Automation.SwitchParameter]
     <# Dependency assembly file(s) (.dll)  #>
        $InstallCompiler
    )

    begin    
    {
        Write-Message -Channel Debug -Message 'Enter Add-TypeEx'

     <# Write-Debug -Message "myInvocation myCommand Name:          $($MyInvocation.MyCommand.Name)"
        Write-Debug -Message "myInvocation myCommand Module:        $($myInvocation.myCommand.Module.Name)"
        Write-Debug -Message "ExecutionContext SessionState Module: $($ExecutionContext.SessionState.Module.Name)"
        Write-Debug -Message "myInvocation InvocationName:          $($myInvocation.InvocationName)"
        Write-Debug -Message "psScriptRoot:                         $($psScriptRoot)"
        Write-Debug -Message "psCommandPath:                        $($psCommandPath)"

        Write-Debug -Message "Stack[1] Module Mame:                 $($(Get-psCallStack)[1].InvocationInfo.MyCommand.Module.Name)"
        Write-Debug -Message "Stack[1] Module Base:                 $($(Get-psCallStack)[1].InvocationInfo.MyCommand.Module.ModuleBase)"  #>

        if
        (
            $InstallCompiler
        )
        {
            $resource = Import-psResource -InputObject 'Microsoft.CodeDom.Providers.DotNetCompilerPlatform' -Type None
          # $type = Add-Type -Path $resource.Location -PassThru

            $libPath      = Split-Path -Path $resource.Location
            $compilerPath = Join-Path  -Path $libPath -ChildPath '..\..' -Resolve
            $compiler     = Get-ChildItem -Path $compilerPath  -Recurse -Filter 'csc.exe'

            $providerOptionParam = @(
                $compiler.FullName  # Compiler FullPath
                10                  # Compiler Server Time To Live
            )
            $providerOption = [Microsoft.CodeDom.Providers.DotNetCompilerPlatform.ProviderOptions]::new.Invoke( $providerOptionParam )

            $provider = [Microsoft.CodeDom.Providers.DotNetCompilerPlatform.CSharpCodeProvider]::new( $providerOption )

          # $type = Add-Type -TypeDefinition $code -PassThru -CodeDomProvider $provider
        }            
    }

    process{

        $PathParam = @{
            Path      = $Path
            ChildPath = "$InputObject.cs"
        }
        $SourcePath = Join-Path @PathParam

        $TypeParam = @{            
            Debug                = $false
            PassThru             = $true
        }
        
        if
        (        
            $OutputAssemblyPath
        )
        {
            $Message = "Will generate assembly file (.dll) at `“$OutputAssemblyPath`”"

            $TypeParam.Add( 'OutputAssembly', $OutputAssemblyPath )
        }
        elseIf
        (
            $OutputAssembly
        )
        {
         <#
            This *has to* have a '.dll' extension, otherwise `Add-Type` with
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

            $TypeParam.Add( 'OutputAssembly', $OutputAssemblyPath )
        }
        else
        {
            $Message = 'Will only generate assembly in memory'
        }

        if
        (
            $InstallCompiler
        )
        {
            $code = Get-Content -Path $SourcePath -Raw

            $TypeParam.Add( 'CodeDomProvider', $provider )
            $TypeParam.Add( 'TypeDefinition',  $code     )
        }
        else
        {
            $TypeParam.Add( 'Path', $SourcePath )
        }

        if
        (
            $ReferencedAssembly
        )
        {
            $TypeParam.Add( 'ReferencedAssemblies', $ReferencedAssembly.FullName )
        }

        Write-Message -Channel Debug -Message $Message

        $name = "$Namespace.$InputObject"

        $Message = "Looking for [$name]"

        Write-Message -Channel Debug -Message $Message
        
        $Assembly = [System.AppDomain]::CurrentDomain.GetAssemblies()

        if
        (
            $Assembly | Where-Object -FilterScript {
                $psItem.DefinedTypes | Where-Object -FilterScript {
                    $psItem.Name -eq $InputObject
                }
            }
        )
        {
            $Message = 'Existing type found'
            
            $type = $name -as [System.Type]
        }
        else
        {
            $Message = 'Generating type'

            $type = Add-Type @TypeParam
        }

        Write-Message -Channel Debug -Message $Message

        Write-Message -Channel Debug -Message $type[0].FullName

        return $type
    }

    end
    {
        Write-Message -Channel Debug -Message 'Exit  Add-TypeEx'    
    }
}