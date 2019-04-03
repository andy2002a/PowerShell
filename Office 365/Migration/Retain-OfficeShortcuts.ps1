#This script requires that all of the new shortcuts be located in 'C:\temp\Office Shortcuts'

$TaskbarDirectories = Get-ChildItem 'c:\users\*\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\Taskbar'
$StartMenuDirectories = Get-ChildItem 'c:\users\*\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu'

$ShortcutDirectories = $TaskbarDirectories + $StartMenuDirectories

foreach ($directory in $ShortcutDirectories){

    #Office 2007
    if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Office\12.0'){
        Copy-Item -Path 'C:\temp\Office Shortcuts\*' -Destination $directory.FullName -include '*2007.lnk'
    }
    #Office 2010
    if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Office\14.0'){
        Copy-Item -Path 'C:\temp\Office Shortcuts\*' -Destination $directory.FullName -include '*2010.lnk'
    }
    #Office 2013
    if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Office\15.0'){
        Copy-Item -Path 'C:\temp\Office Shortcuts\*' -Destination $directory.FullName -include '*2013.lnk'
    }
    #All Verisons with no year
    Copy-Item -Path 'C:\temp\Office Shortcuts\*' -Destination $directory.FullName -Exclude '*20*'

}
