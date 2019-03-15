<#

.SYNOPSIS
This script deletes local profile data on an RDS server that has UPDs. When UPDs are enabled user files will sometimes be left behind. This can cause some unexpected resuults with applications.

The script has a failsafe that does not create the task if UPDs become disabled at any point.

The script needs Remove-LocalUPDProfiles.ps1 to work correctly.

.PARAMETER ScheduledTaskName
This is the name that will be given to the ScheduledTask

#>


$ScheduledTaskName = 'Delete UPD Local Files'

Write-Output "Check if the computer is an RDS Server"

$TSMode = $string = Get-WmiObject -Namespace "root\CIMV2\TerminalServices" -Class "Win32_TerminalServiceSetting"  | select -ExpandProperty TerminalServerMode

if ($TSMode -eq '1') {
    #Check to make sure UPDs are enabled
    if((Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Terminal Server\ClusterSettings').UvhdEnabled -eq 1){
        schtasks /create /RU SYSTEM /ST 04:00 /SC DAILY /TN "$ScheduledTaskName" /TR "powershell.exe -ExecutionPolicy Bypass C:\BIN\DelProf2\Remove-LocalUPDProfiles.ps1" /F
        Write-Host 'Make sure that C:\BIN\DelProf2\Remove-LocalUPDProfiles.ps1 and C:\BIN\DelProf2\DelProf2.exe exist' -BackgroundColor Yellow -ForegroundColor Black
    }
    else {
        Write-Output "UPDs are not enabled. The script will not run"
    }
}
else {
    Write-Output "The computer is not an RDS Server. The script will not run"
}



