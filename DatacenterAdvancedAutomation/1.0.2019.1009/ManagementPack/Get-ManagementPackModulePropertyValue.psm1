Function
Get-ManagementPackModulePropertyValue
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [System.Xml.XmlElement]
        $Module
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.String]
        $PropertyName
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Xml.XmlElement]
        $ModuleResource
    )

    Process
    {
        If
        (
            $ModuleResource
        )
        {
            $Value = $ModuleResource.$PropertyName

          # Build the replacement table

            $ValueSplit = $Value -split( "`n" )

            $Replace = @{}

            $ValueSplit | Where-Object -FilterScript { $psItem -like '*$Config/*' } | ForEach-Object -Process {

                $ParameterName = $psItem.Split( '/' )[1].Replace( '$', [System.String]::Empty )

                $Replace.Add(
                                                    
                    $psItem.Substring( $psItem.IndexOf( '$Config' ) ).Trim(),
                    $Module.$ParameterName
                )
            }

           # Replace variables                                                

            $Replace.GetEnumerator() | ForEach-Object -Process {

                $Value = $Value.Replace( $psItem.Key, $psItem.Value )
            }
        }
        Else
        {
            $Value = $Module.$PropertyName
        }

        Return $Value
    }
}