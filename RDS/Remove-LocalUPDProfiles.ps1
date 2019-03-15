<#

This script deletes local profile data on an RDS server that has UPDs. When UPDs are enabled user files will sometimes be left behind. This can cause some unexpected resuults with applications.

The script has a failsafe that does not run if UPDs become disabled at any point.
#>

if((Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Terminal Server\ClusterSettings').UvhdEnabled -eq 1){
    & C:\BIN\DelProf2\DelProf2.exe /u /ed:UvhdCleanupBin
}
else {
    Write-Output "UPDs are not enabled. The script will not run"
}
