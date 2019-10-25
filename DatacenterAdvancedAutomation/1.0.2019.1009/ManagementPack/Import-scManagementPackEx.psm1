Set-StrictMode -Version 'Latest'

Function
Import-scManagementPackEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.Core.Connection.Connection]
        $Connection
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.IO.FileInfo]]
        $FullName
    <#,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[Microsoft.EnterpriseManagement.Configuration.ManagementPack]]
        $ManagementPack  #>
    )

    Begin
    {
        [System.Collections.Generic.List[
            Microsoft.EnterpriseManagement.Configuration.ManagementPack
        ]]$ManagementPackCurrent = Get-scManagementPack -scSession $Connection

        $ManagementPackImport = [System.Collections.Generic.Dictionary[
            System.IO.FileInfo,
            Microsoft.EnterpriseManagement.Configuration.ManagementPack
        ]]::new()

        $FullName | ForEach-Object -Process {

            $FileInfo = $psItem

            Switch
            (
                $psItem.Extension
            )
            {
                '.mp'
                {
                    $ManagementPack = Get-scManagementPack -ManagementPackFile $FileInfo.FullName
                }

                '.mpb'
                {
                    $ManagementPack = Get-scManagementPack -BundleFile $FileInfo.FullName
                }

                Default
                {
                    Write-Warning -Message "Unexpected file extension `“$psItem`”"
                }
            }

            $ManagementPackString = "`“$( $ManagementPack.Name )`”, $( $ManagementPack.Version )"

            If
            (
                $ManagementPackCurrent | Where-Object -FilterScript {

                    $psItem.Name          -eq $ManagementPack.Name    -And
                    $psItem.Version       -ge $ManagementPack.Version
                }
            )
            {
                $Message = "    Same or newer Management Pack $ManagementPackString is already imported"
                Write-Verbose -Message $Message            
            }
            Else
            {
                $Message = "    Will import   Management Pack $ManagementPackString"
                Write-Verbose -Message $Message            
                
                $ManagementPackImport.Add(

                    $FileInfo,
                    $ManagementPack
                )
            }
        }

        $ManagementPack = [System.Collections.Generic.List[
            Microsoft.EnterpriseManagement.Configuration.ManagementPack
        ]]::new()
    }

    Process
    {
        $ManagementPackImport.GetEnumerator() | ForEach-Object -Process {

            $ManagementPackString = "`“$( $psItem.Value.Name )`”, $( $psItem.Value.Version )"

            Write-Verbose -Message '***'
            $Message = "Processing $ManagementPackString"
            Write-Verbose -Message $Message            

            $psItem.Value.References.GetEnumerator() | ForEach-Object -Process {

                $Reference = $psItem.Value

                $Message = "  Evaluating dependency `“$( $Reference.Name )`”, $( $Reference.Version )"
                Write-Verbose -Message $Message

                $Current = $ManagementPackCurrent | Where-Object -FilterScript {

                    $psItem.Name          -eq $Reference.Name    -And
                    $psItem.Version       -ge $Reference.Version
                }

                $Import  = $ManagementPackImport.GetEnumerator() | Where-Object -FilterScript {

                    $psItem.Value.Name    -eq $Reference.Name    -And
                    $psItem.Value.Version -ge $Reference.Version
                }

                If
                (
                    $Current
                )
                {
                    $Message = '    Already exists'
                    Write-Verbose -Message $Message
                }
                ElseIf
                (
                    $Import
                )
                {
                    $Message = '    Found'
                    Write-Verbose -Message $Message            

                  # Import-scManagementPackEx -ManagementPack $Dependency

                  # Import-scManagementPackEx -Fullname $Dependency.Key -ManagementPack $Dependency.Value

                    Import-scManagementPackEx -Connection $Connection -FullName $Import.Key

                    $Message = "Processing $ManagementPackString"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $Message = '    Could not satisfy. Import will fail'
                    Write-Warning -Message $Message            
                }
            }

            $Message = "Importing  $ManagementPackString"
            Write-Verbose -Message $Message

          # Import-scManagementPack -scSession $Connection -ManagementPack $psItem -PassThru

            $ManagementPackParam = @{

                scSession = $Connection
                Fullname  = $psItem.Key.FullName
                PassThru  = $True
            }
            $ManagementPack.Add( ( Import-scManagementPack @ManagementPackParam ) )

            $Message = "Imported   $ManagementPackString"
            Write-Verbose -Message $Message
        }
    }

    End
    {
        Return $ManagementPack
    }
}