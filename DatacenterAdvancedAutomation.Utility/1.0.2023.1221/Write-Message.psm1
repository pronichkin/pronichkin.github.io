Set-StrictMode -Version 'Latest'

Function
Write-Message
{
 <#
       .Synopsis
        Emit message to a specified channel with a timestamp and indentation
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [OutputType(
        [System.Void]
    )]

    Param
    (
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateSetAttribute(
            'Error'        ,
            'Information'  ,
            'Verbose'      ,
            'Debug'        ,
            'Warning'
        )]
        [System.String]
        $Channel
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.String]
        $Message
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Int16]
        $Indent  = 0
    )

    End
    {
      # Base offset to visually distinguish timestamp from the message
        $Indent++
        
        Switch
        (
            $Channel
        )
        {
           'Information'
            {
                $Length = 20
            }

           'Verbose'
            {
                $Length = 11
            }

           'Warning'
            {
                $Length = 11
            }

           'Debug'
            {
                $Length = 13
                $Indent++
            }

            'Error'
            {
                $Length = 13
            }
        }

        switch
        (
            $psVersionTable.psEdition
        )
        {
            'Core'
            {
              # PowerShell 7 won't find `[Microsoft.PowerShell.Commands.DisplayHintType]`
              # without importing the assmebly first
                $path = Join-Path -Path $psHome -ChildPath 'Microsoft.PowerShell.Commands.Utility.dll'
                $assembly = [System.Reflection.Assembly]::LoadFrom( $path )
            }

            'Desktop'
            {
              # no workarounds are required
            }
        }

        $DisplayHint = [Microsoft.PowerShell.Commands.DisplayHintType]::Time
        $TimeStamp   = ( Get-Date -DisplayHint $DisplayHint ).DateTime

        $MessageEx   = [System.String]::Empty
        $MessageEx  += $TimeStamp.PadLeft(  $Length )
        $MessageEx   = $MessageEx.PadRight( $Length + 2 * $Indent )
        $MessageEx  += $Message

        $Command     = "Write-$Channel"

      & $Command -Message $MessageEx
    }
}