Set-StrictMode -Version 'Latest'

Function
Get-PackageSourceEx
{
 <#
       .Synopsis
        Register package source if needed
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
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
        $Name
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
        $Location
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [Microsoft.PackageManagement.Implementation.PackageProvider]
        $Provider
    )

    End
    {
        $SourceParam = @{
        
          # Name         = $Name
            ProviderName = $Provider.Name
          # Force        = $True
        }
        $Source = Get-PackageSource @SourceParam | Where-Object -FilterScript { $psItem.Name -eq $Name }
        
        If
        (
           $Source
        )
        {
            $Message = "Package Source `“$Name`” is already added"
            Write-Message -Channel Debug -Message $Message
        }
        Else
        {
            $SourceParam.Add( 'Location'  ,   $Location.AbsoluteUri )
            $SourceParam.Add( 'Name'      ,   $Name )

            $Source = Register-PackageSource @SourceParam
        }

        If
        (
            $Source.IsTrusted
        )
        {
            $Message = "Package Source `“$Name`” is already trusted"
            Write-Message -Channel Debug -Message $Message
        }
        Else
        {
            $SourceParam = @{

                InputObject = $Source
                Trusted     = $True
            }
            $Source = Set-PackageSource @SourceParam
        }

        Return $Source
    }
}