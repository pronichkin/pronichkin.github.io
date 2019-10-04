<#
    #Requires -RunAsAdministrator
#>

Set-StrictMode -Version 'Latest'

Function
Mount-RegistryKey
{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            Position          = 0
        )]
        [System.Io.FileInfo]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            { $psItem.Exists }
        )]
        $Key
    ,
        [Parameter(
            Mandatory         = $False,
            ValueFromPipeline = $False,
            Position          = 0
        )]
        [Microsoft.Win32.RegistryHive]
        [ValidateNotNullOrEmpty()]
        $Hive = [Microsoft.Win32.RegistryHive]::LocalMachine
    ,
        [Parameter(
            Mandatory         = $False,
            ValueFromPipeline = $False,
            Position          = 0
        )]
        [System.String]
        [ValidateNotNullOrEmpty()]
        $Name = $Key.Name
    ,
        [Parameter(
            Mandatory         = $False,
            ValueFromPipeline = $False,
            Position          = 0
        )]
        [System.Management.Automation.SwitchParameter]
        $ReadOnly
    )

    Process
    {
        $Message = "    Mounting registry key `“$( $Key.FullName )`”"
        Write-Debug -Message $Message

        If
        (
            $ReadOnly
        )
        {
            $Path = Join-Path -Path $env:Temp -ChildPath $Key.Name

            $CopyParam = @{

                Path        = $Key.FullName
                Destination = $Path
                PassThru    = $True
            }
            $Key = Copy-Item @CopyParam

            $Message = "    read-only from `“$( $Key.FullName )`”"
            Write-Debug -Message $Message
        }

        [System.Void]( Set-TokenPrivilege -Privilege 'SeBackupPrivilege'  )
        [System.Void]( Set-TokenPrivilege -Privilege 'SeRestorePrivilege' )

        $TypePath = Join-Path -Path $psScriptRoot -ChildPath 'Registry.cs'

        $TypeParam = @{

          # MemberDefinition = $Definition
          # Name             = 'ClassLoad'
          # Namespace        = 'Win32Functions'
            Path             = $TypePath
            PassThru         = $True
            Verbose          = $False
            Debug            = $False
        }
        $Registry = Add-Type @TypeParam

        $KeyParam = @(

            [System.UInt32] $Hive
            [System.String] $Name
            [System.String] $Key.FullName
        )

        $Registry::RegLoadKey.Invoke( $KeyParam )

        Get-RegistryKey -Hive $Hive -Name $Name
        
      # Set a global variable containing the name of the mounted registry key
      # so we can unmount it if there's an error.
      # $global:mountedHive = $mountKey

      # return $mountKey
    }
}