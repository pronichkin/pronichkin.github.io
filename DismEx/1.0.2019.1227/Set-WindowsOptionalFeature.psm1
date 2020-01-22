Function
Set-WindowsOptionalFeature
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.psSession[]]
        $Session
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $FeatureNameDisable
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $FeatureNameEnable
    )

    Process
    {
        $ScriptBlock = {

            $Message = "Disabling optional features on $( $env:ComputerName )"
            Write-Verbose -Message $Message

            $OptionalFeatureParam = @{
    
                Online        = $True
                FeatureName   = $Using:FeatureNameDisable
                NoRestart     = $True
                WarningAction = 'SilentlyContinue'
            }
            Disable-WindowsOptionalFeature @OptionalFeatureParam

            $Message = "Enabling optional features on $( $env:ComputerName )"
            Write-Verbose -Message $Message

            $OptionalFeatureParam.FeatureName = $Using:FeatureNameEnable
          # $OptionalFeatureParam.Add( 'All', $True )

            Enable-WindowsOptionalFeature @OptionalFeatureParam
        }

        $CommandParam = @{

            Session      = $Session
            ScriptBlock  = $ScriptBlock
        }
        $OptionalFeature = Invoke-Command @CommandParam
    }
}