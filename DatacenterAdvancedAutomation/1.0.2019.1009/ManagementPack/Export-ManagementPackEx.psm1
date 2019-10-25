<#
    This one parses Management Pack XML and extracts resources from modules of
    known types, such as scripts
#>

Function
Export-ManagementPackEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Xml.XmlDocument]
        $ManagementPack
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Path
    )

    Process
    {
        If
        (
            $ManagementPack.ManagementPack[ 'TypeDefinitions' ] -and
            $ManagementPack.ManagementPack.TypeDefinitions[ 'ModuleTypes' ]
        )
        {
            $ManagementPack.ManagementPack.TypeDefinitions.ModuleTypes.ChildNodes | ForEach-Object -Process {

                $ModuleType = $psItem

                $Message = "  $( $ModuleType.ID )"
                Write-Verbose -Message $Message

                If
                (
                    $psItem.ModuleImplementation[ 'Composite' ]
                )
                {
                    $psItem.ModuleImplementation.Composite.MemberModules.ChildNodes | ForEach-Object -Process {

                            $Module = $psItem
       
                            If
                            (
                                $Module -is [System.Xml.XmlComment]
                            )
                            {
                                $Message = '    This is a comment and it does not contain any code'
                                Write-Verbose -Message $Message
                            }
                            Else
                            {
                                $Message = "    $( $Module.TypeID )"
                                Write-Verbose -Message $Message

                                $PathType = Join-Path -Path $Path.FullName -ChildPath $ModuleType.ID

                                $ContentParam = @{
                            
                                    Path     = $PathType
                                    Name     = [System.String]::Empty
                                    Value    = [System.String]::Empty
                                    Encoding = [System.Text.Encoding]::Unicode
                                }

                                $ModuleTypeResource = $ManagementPack.ManagementPack.TypeDefinitions.ModuleTypes.ChildNodes | Where-Object -FilterScript {

                                    $psItem.ID -eq $Module.TypeID
                                }

                                If
                                (
                                    $Module[ 'Files' ] -and
                                    $Module[ 'Files' ].HasChildNodes
                                )
                                {
                                    If
                                    (
                                        $Module.Files.ChildNodes.Name     -like '*$Config/*' -or
                                        ( $Module.Files.ChildNodes | Where-Object -FilterScript { $psItem.Name -notlike '*.txt' } ).Contents -like '*$Config/*'
                                    )
                                    {
                                        $Message = '    Module contains variables and likely a resource for another module'
                                        Write-Verbose -Message $Message
                                    }
                                    Else
                                    {
                                            $PathType = New-Item -Path $PathType -ItemType 'Directory'

                                            $Module.Files.ChildNodes | ForEach-Object -Process {
                                            
                                                $File = $psItem

                                                $ContentParam.Name  = $File.Name
                                                $ContentParam.Value = $File.Contents
                                            
                                              # The Unicode property is not always
                                              # present and is False by default

                                                If
                                                (
                                                    $File[ 'Unicode' ] -and $File.Unicode -eq 'False'
                                                )
                                                {
                                                    $ContentParam.Encoding = [System.Text.Encoding]::ASCII
                                                }
                                                Else
                                                {
                                                    $ContentParam.Encoding = [System.Text.Encoding]::Unicode
                                                }

                                                Set-ContentEx @ContentParam
                                            }
                                    }
                                }
                                ElseIf
                                (
                                    $Module.TypeID -like '*.PowerShell*'
                                )
                                {
                                    If
                                    (
                                        $Module.ScriptName -like '*$Config/*' -or
                                        $Module.ScriptBody -like '*$Config/*'
                                    )
                                    {
                                        $Message = '    Module contains variables and likely a resource for another module'
                                        Write-Verbose -Message $Message
                                    }
                                    Else
                                    {
                                        $PathType = New-Item -Path $PathType -ItemType 'Directory'

                                        If
                                        (
                                            $ModuleTypeResource
                                        )
                                        {
                                            $ModuleResource = $ModuleTypeResource.ModuleImplementation.Composite.MemberModules.ChildNodes[0]

                                            $ContentParam.Name  = Get-ManagementPackModulePropertyValue -Module $Module -ModuleResource $ModuleResource -PropertyName 'ScriptName'
                                            $ContentParam.Value = Get-ManagementPackModulePropertyValue -Module $Module -ModuleResource $ModuleResource -PropertyName 'ScriptBody'
                                        }
                                        Else
                                        {
                                            $ContentParam.Name     = $Module.ScriptName
                                            $ContentParam.Value    = $Module.ScriptBody
                                        }

                                        Set-ContentEx @ContentParam
                                    }
                                }
                                ElseIf
                                (
                                    $ModuleTypeResource -and
                                    $ModuleTypeResource.ModuleImplementation[ 'Composite' ] -and
                                    $ModuleTypeResource.ModuleImplementation.Composite.MemberModules[ 'DataSource' ] -and
                                    $ModuleTypeResource.ModuleImplementation.Composite.MemberModules.DataSource[ 'Files' ]
                                )
                                {
                                        $PathType = New-Item -Path $PathType -ItemType 'Directory'
                                    
                                        $ModuleTypeResource.ModuleImplementation.Composite.MemberModules.DataSource.Files.ChildNodes | ForEach-Object -Process {
                                            
                                            $File = $psItem

                                            $ContentParam.Name  = Get-ManagementPackModulePropertyValue -Module $Module -ModuleResource $File -PropertyName 'Name'
                                            $ContentParam.Value = Get-ManagementPackModulePropertyValue -Module $Module -ModuleResource $File -PropertyName 'Contents'

                                          # The Unicode property is not always
                                          # present and is False by default

                                            If
                                            (
                                                $File[ 'Unicode' ] -and $File.Unicode -eq 'False'
                                            )
                                            {
                                                $ContentParam.Encoding = [System.Text.Encoding]::ASCII
                                            }
                                            Else
                                            {
                                                $ContentParam.Encoding = [System.Text.Encoding]::Unicode
                                            }

                                            Set-ContentEx @ContentParam
                                        }                                    
                                }
                                Else
                                {
                                        $Message = '      No scripts were found based on knonw patterns'
                                        Write-Verbose -Message $Message
                                }
                            }
                    }
                }
                Else
                {
                    $Message = '    This is a Native module and it does not contain any code'
                    Write-Verbose -Message $Message
                }
            }
        }
        Else
        {
            $Message = "  There are no modules"
            Write-Verbose -Message $Message
        }
    }
}