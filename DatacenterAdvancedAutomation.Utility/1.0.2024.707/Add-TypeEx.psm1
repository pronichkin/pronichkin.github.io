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
        [System.IO.DirectoryInfo]
     <# Source path. Default to the path of the calling module, or current
        direcotry when used interactively                                     #>
        $Path      = $(
            $callStackFrame = Get-psCallStack | Select-Object -First 1

            if
            (
                $callStackFrame.InvocationInfo.MyCommand.Module
            )
            {
             <# this is typical behavior for a nested module. Because `Add-TypeEx`
                is not running yet, the topmost call stack frame is the calling
                module. In case it's a nested module (referred from a manifest of
                another module), the parent module is regonized by Invocation Info.
                We default the parameter value to the full path to the root 
                directory of that module, e.g.
               `C:\<username>\artemp\Documents\WindowsPowerShell\Modules\<name>\<version`.
                This is where we expect to find the *.cs files that define types.  #>

                $callStackFrame.InvocationInfo.MyCommand.Module.ModuleBase
             }
             else
             {
                switch
                (
                    $callStackFrame.InvocationInfo.CommandOrigin
                )
                {
                    ([System.Management.Automation.CommandOrigin]::Internal)
                    {
                     <# this is typical behavior for the root module. When
                        initialization runs, the module is not loaded yet, hence
                        Infocation Info does not reflect the module yet. However,
                        the Command Origin is already set to `Internal`.  #>

                        $FileInfo = Get-Item -Path $callStackFrame.InvocationInfo.MyCommand.Definition
                        $FileInfo.Directory
                    }

                    ([System.Management.Automation.CommandOrigin]::Runspace)
                    {
                     <# This is typical behavior for running `Add-TypeEx` 
                        interactively, e.g. during module development. In this
                        case, we're not running inside a module, also there
                        Command Origin is `Runspace`. In this case, we mostly
                        expect user to specify path explicitly. But if that's
                        not the case, default to the current location.  #>

                        [System.IO.DirectoryInfo]( Get-Location ).Path
                    }

                    default
                    {
                        throw 'unknown command origin!'
                    }
                }
            }           
        )
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]
        [System.String]
     <# Namespace. This is required to look for the requested type in case it's
        already loaded in the current app domain. Default to the name of the
        calling module, or name of the  parent folder if when used interactively.  #>
        $Namespace = $(
            $callStackFrame = Get-psCallStack | Select-Object -First 1

            if
            (
                $callStackFrame.InvocationInfo.MyCommand.Module
            )
            {
             <# this is typical behavior for a nested module. Because `Add-TypeEx`
                is not running yet, the topmost call stack frame is the calling
                module. In case it's a nested module (referred from a manifest of
                another module), the parent module is regonized by Invocation Info.
                We default the parameter value to the name of that module.  #>

                $callStackFrame.InvocationInfo.MyCommand.Module.Name
             }
             else
             {
              # Write-Debug -Message "Stack[$stackCount] my command module:      *none*"

                switch
                (
                    $callStackFrame.InvocationInfo.CommandOrigin
                )
                {
                    ([System.Management.Automation.CommandOrigin]::Internal)
                    {
                     <# this is typical behavior for the root module. When
                        initialization runs, the module is not loaded yet, hence
                        Infocation Info does not reflect the module yet. However,
                        the Command Origin is already set to `Internal`.  #>

                        $FileInfo = Get-Item -Path $callStackFrame.InvocationInfo.MyCommand.Definition
                        $FileInfo.BaseName
                    }

                    ([System.Management.Automation.CommandOrigin]::Runspace)
                    {
                     <# This is typical behavior for running `Add-TypeEx` 
                        interactively, e.g. during module development. In this
                        case, we're not running inside a module, also there
                        Command Origin is `Runspace`. In this case, we mostly
                        expect user to specify path explicitly. But if that's
                        not the case, default to the name of the parent directory
                        specified earlier as path.  #>

                        $path.Parent.BaseName
                    }

                    default
                    {
                        throw 'unknown command origin!'
                    }
                }
            }
        )
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

        Write-Debug -Message "Stack length:                         $(@(Get-psCallStack).Count)"
        Write-Debug -Message ([System.String]::Empty)

        $stackCount = 0

        Get-psCallStack | ForEach-Object -Process {
            
            $callStackFrame = $psItem

            Write-Debug -Message "Stack[$stackCount] command:                $($callStackFrame.Command)"
            Write-Debug -Message "Stack[$stackCount] command origin:         $($callStackFrame.InvocationInfo.CommandOrigin)"
            Write-Debug -Message "Stack[$stackCount] my command:             $($callStackFrame.InvocationInfo.MyCommand)"            
            Write-Debug -Message "Stack[$stackCount] my command definition:  $($callStackFrame.InvocationInfo.MyCommand.Definition)"

            if
            (
                $callStackFrame.InvocationInfo.MyCommand.Module
            )
            {
                Write-Debug -Message "Stack[$stackCount] my command module:      $($callStackFrame.InvocationInfo.MyCommand.Module)"
                Write-Debug -Message "Stack[$stackCount] my command module name: $($callStackFrame.InvocationInfo.MyCommand.Module.Name)"
                Write-Debug -Message "Stack[$stackCount] my command module base: $($callStackFrame.InvocationInfo.MyCommand.Module.ModuleBase)"
             }
             else
             {
                Write-Debug -Message "Stack[$stackCount] my command module:      *none*"

                switch
                (
                    $callStackFrame.InvocationInfo.CommandOrigin
                )
                {
                    ([System.Management.Automation.CommandOrigin]::Internal)
                    {
                        $FileInfo = Get-Item -Path $callStackFrame.InvocationInfo.MyCommand.Definition

                        Write-Debug -Message "Stack[$stackCount] file base name:         $($FileInfo.BaseName)"
                        Write-Debug -Message "Stack[$stackCount] directory full name:    $($FileInfo.Directory.FullName)"
                    }

                    ([System.Management.Automation.CommandOrigin]::Runspace)
                    {
                        Write-Debug -Message 'this is a runspace and no module, nothing more to show here'
                    }

                    default
                    {
                        throw 'unknown command origin!'
                    }
                }
            }

            Write-Debug -Message ([System.String]::Empty)

            $stackCount++
        }
        
      #>

        Write-Message -Channel Debug -Message "  * Namespace: $Namespace"
        Write-Message -Channel Debug -Message "  * Path:      $Path"

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
                  # $psItem.Name -eq $InputObject -and
                    $psItem.FullName -eq $name
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

        $type | ForEach-Object -Process {
            Write-Message -Channel Debug -Message "  * $($psItem.FullName)"
        }

        return $type
    }

    end
    {
        Write-Message -Channel Debug -Message 'Exit  Add-TypeEx'    
    }
}