Set-StrictMode -Version 'Latest'

Function
Set-vmSecurityPolicyEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory        = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.HyperV.PowerShell.VirtualMachine]
        $VirtualMachine
    ,
        [Parameter(
            Mandatory        = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Byte[]]
        $PolicyData
    )

    Process
    {
        $Serializer           = [Microsoft.Management.Infrastructure.Serialization.CimSerializer]::Create()
        $SerializationOptions = [Microsoft.Management.Infrastructure.Serialization.InstanceSerializationOptions]::None
        $Unicode              = [System.Text.Encoding]::Unicode

        $CommonParam = @{
            
            Namespace  = 'root/Virtualization/v2'
            cimSession = $VirtualMachine.CimSession
            Verbose    = $False
        }

        $ComputerSystem        = Get-CimInstance @CommonParam -ClassName 'msvm_ComputerSystem' -Filter "name = '$($VirtualMachine.vmid)'"        
        $SecurityService       = Get-cimAssociatedInstance @CommonParam -InputObject $ComputerSystem -ResultClassName 'msvm_SecurityService'
        $VirtualSystemSetting  = Get-cimAssociatedInstance @CommonParam -InputObject $ComputerSystem -ResultClassName 'msvm_VirtualSystemSettingData'
        $SecuritySetting       = Get-cimAssociatedInstance @CommonParam -InputObject $VirtualSystemSetting -ResultClassName 'msvm_SecuritySettingData'

        $SecuritySettingByte   = $Serializer.Serialize( $SecuritySetting, $SerializationOptions )
        $SecuritySettingString = $Unicode.GetString( $SecuritySettingByte )

        $Argument = @{
            SecuritySettingData = $SecuritySettingString
            SecurityPolicy      = $PolicyData
        }

        Invoke-cimMethod -InputObject $SecurityService -MethodName 'SetSecurityPolicy' -Arguments $Argument -Verbose:$False
    }
}