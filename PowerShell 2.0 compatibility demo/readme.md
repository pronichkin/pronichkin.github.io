This is a simple demo that shows how legacy code may behavie differently in PowerShell 2.0 vs. later versions.

Guidance
1. Copy the `Script` contents to the target machine.
1. Build the solution.
1. Place the resulting `PowerShell 2.0 compatibility demo.dll` alongside with the scripts.
1. Launch multiple different versions of PowerShell on the target machine.
1. Run `My Legacy Script 01.ps1`..`My Legacy Script 03.ps1` in different versions of PowerShell to observe the differences in behavior.

Additional considerations
Here's one option to launch multiple different versions of PowerShell. This will open multiple console windows (or tabs in Windows Terminal.)
```PowerShell
Start-Process -FilePath "$env:systemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-noExit' )
Start-Process -FilePath "$env:systemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-version 2.0 -noExit' )
Start-Process -FilePath "$env:systemRoot\SysWoW64\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-noExit' )
Start-Process -FilePath "$env:systemRoot\SysWoW64\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-version 2.0 -noExit' )
```
Here's another option to launch them one one after another. Each line below will open a new instance of PowerShell inline. (I.e. you will have to type `exit` to go back to the parent PowerShell instance.)
```PowerShell
Start-Process -noNewWindow -Wait -FilePath "$env:systemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-noExit' )
Start-Process -noNewWindow -Wait -FilePath "$env:systemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-version 2.0', '-noExit' )
Start-Process -noNewWindow -Wait -FilePath "$env:systemRoot\SysWoW64\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-noExit' )
Start-Process -noNewWindow -Wait -FilePath "$env:systemRoot\SysWoW64\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @( '-version 2.0', '-noExit' )
```
