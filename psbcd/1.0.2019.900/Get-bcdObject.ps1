Function
Get-bcdObject
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Store
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateSet(
            'Firmware boot manager',
            'Windows boot manager', 
            'Windows boot loader',  
            'Windows resume application',
            'Memory test',
            'Legacy NtLdr',
            'Legacy SetupLdr',
            'Boot Sector',
            'Startup module',
            'Generic application',
            'Device'
        )]
        [String]
        $Type
    )

    $ObjectType = @{

        'Firmware boot manager'      = 0x10100001
        'Windows boot manager'       = 0x10100002
        'Windows boot loader'        = 0x10200003
        'Windows resume application' = 0x10200004
        'Memory test'                = 0x10200005
        'Legacy NtLdr'               = 0x10300006
        'Legacy SetupLdr'            = 0x10300007
        'Boot Sector'                = 0x10300008
        'Startup module'             = 0x10400009
        'Generic application'        = 0x1040000a
        'Device'                     = 0x30000000
    }

    # Query

    $Argument         = @{ "Type" = $ObjectType.$Type }

    $EnumerateObjects = Invoke-CimMethod -CimInstance $Store -MethodName "EnumerateObjects" -Arguments $Argument -Verbose:$False

    $EnumerateObjects.Objects | ForEach-Object -Process {

        $Argument = @{ "Id" = $PSItem.Id }

        $OpenObject = Invoke-CimMethod -CimInstance $Store -MethodName "OpenObject" -Arguments $Argument -Verbose:$False
        Return $OpenObject.Object
    }
}