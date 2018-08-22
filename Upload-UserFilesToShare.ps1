<#

.SYNOPSIS
This script copies all of the folders under $LocationsToCopy to a network location. Those files will later be moved into the user's profile using another script.

Network paths(in the case of redirected AppData) can also be copied over to a share.

Various regsitry keys are also copied over to a share.

.NOTES
This should be set as a user login script with deny GPO read permission applied to the new RDS servers. See: https://i.imgur.com/X6gtv7v.png

You must create a shared folder with Redirected Folder permissions. https://blogs.technet.microsoft.com/migreene/2008/03/24/ntfs-permissions-for-redirected-folders-or-home-directories/
This will allow users to create their own folder while keeping their files secure.

Additional reg keys can be copied over by adding items to the $UserRegKeys array.

.PARAMETER RootShare
This is the path of the network share that will host the files.

Andy Morales
#>

$RootShare = '\\SERVER\RDSProfileMigration'


#Create user folder on the share
$UserShare = $RootShare + '\' + $env:UserName
New-item -Path $UserShare -ItemType Directory -Force

$PowerShellLogPath = "$usershare\powerShellExportLog.txt"

#region CopyFiles
$LocationsToCopy = @(
    "AppData\Roaming\Microsoft\Signatures",
    "AppData\Roaming\Microsoft\Templates",
    "AppData\Roaming\Mozilla\Firefox",
    "AppData\Local\Google\Chrome\User Data",
    "AppData\Local\Microsoft\office",
    "AppData\Roaming\Microsoft\UProof",
    "AppData\Roaming\Microsoft\Office",
    "AppData\Roaming\Microsoft\Windows\Themes",
    "AppData\Roaming\Microsoft\Windows\Recent"

)

foreach ($Location in $LocationsToCopy) {
    try {
        ROBOCOPY "$env:userprofile\$Location" "$Rootshare\$env:UserName\$Location" /R:0 /W:0 /E /xo /COPY:DATSO /dcopy:t /XD 'System Volume Information' '*cache*' '$RECYCLE.BIN' 'IndexedDB' /XF '*.TMP' '*.temp' '*.localstorage' /np /purge /log+:"$usershare\roboCopyExportLog.txt"
        #IndexedDB, '*cache*', and '*.localstorage'are intended to reduce the amount of chrome data
    }
    catch {
        Add-Content -Path "$PowerShellLogPath" -Value "Errory copying C:\Users\$Location to $Rootshare\$Location"
        Add-Content -Path "$PowerShellLogPath" -Value $Error[0]
    }

    Clear-Variable Location -ErrorAction SilentlyContinue
}

<#
$NetworkLocations =@(
	"AppData\Roaming\Microsoft\Signatures",
    "AppData\Roaming\Microsoft\Templates",
    "AppData\Roaming\Mozilla\Firefox",
    "AppData\Roaming\Microsoft\UProof"
    "AppData\Roaming\Microsoft\Office"
    "AppData\Roaming\Microsoft\Windows\Themes"
)

foreach ($location in $NetworkLocations){
	try {
        ROBOCOPY "\\FileServer\rprofiles$\$env:UserName\$Location" "$Rootshare\$env:UserName\$Location" /R:0 /W:0 /E /xo /COPY:DATSO /dcopy:t /XD 'System Volume Information' '*cache*' '$RECYCLE.BIN' 'IndexedDB' /XF '*.TMP' '*.temp' /np /purge /log+:"$usershare\roboCopyExportLog.txt"
        #IndexedDB, '*cache*' are intended to reduce the amount of chrome data
    }
    catch {
        Add-Content -Path "$PowerShellLogPath" -Value "Errory copying C:\Users\$Location to $Rootshare\$Location"
        Add-Content -Path "$PowerShellLogPath" -Value $Error[0]
    }

    Clear-Variable Location -ErrorAction SilentlyContinue

}
#>

#endregion CopyFiles

function Export-HKCURegKeys {
    param([string]$RegKeyPath)

    if (Test-Path "HKCU:\$RegKeyPath") {
        $exportPath = $UserShare + '\' + ($RegKeyPath.replace('\', '')).replace(':', '') + '.reg'
        reg export "HKEY_CURRENT_USER\$RegKeyPath" "$exportPath" /y
    }
}

#region OfficeKeys
$OfficeRegKeysToExport = @(
    #Outlook Profiles
    #'\Outlook\profiles', #Disabled due to possible profile issues
    #Outlook Settings (fonts)
    '\Common\MailSettings',
    #Excel Recent Items(does not work on upgrades)
    '\Excel\User MRU',
    #Word Recent Items(does not work on upgrades)
    '\Word\User MRU'
)

$Outlook2016Regpath = 'HKCU:\Software\Microsoft\Office\16.0'
$Outlook2013Regpath = 'HKCU:\Software\Microsoft\Office\15.0'
$Outlook2010Regpath = 'HKCU:\Software\Microsoft\Office\14.0'

if (Test-Path $Outlook2016Regpath) {
    foreach ($key in $OfficeRegKeysToExport) {
        $currentFullKeyPath = "Software\Microsoft\Office\16.0" + $key
        Export-HKCURegKeys -RegKeyPath $currentFullKeyPath
    }
}
else {
    Add-Content -Path "$PowerShellLogPath" -Value 'Office 2016 profile Reg path not found'
}
if (Test-Path $Outlook2013Regpath) {
    foreach ($key in $OfficeRegKeysToExport) {
        $currentFullKeyPath = "Software\Microsoft\Office\15.0" + $key
        Export-HKCURegKeys -RegKeyPath $currentFullKeyPath
    }
}
else {
    Add-Content -Path "$PowerShellLogPath" -Value 'Office 2013 profile Reg path not found'
}
if (Test-Path $Outlook2010Regpath) {
    foreach ($key in $OfficeRegKeysToExport) {
        $currentFullKeyPath = "Software\Microsoft\Office\14.0" + $key
        Export-HKCURegKeys -RegKeyPath $currentFullKeyPath
    }

    #ExportProfiles
	#Disabled due to possible issues
    #Export-HKCURegKeys -RegKeyPath 'Software\Microsoft\Windows NT\CurrentVersion\Windows Messaging Subsystem\Profiles'
}
else {
    Add-Content -Path "$PowerShellLogPath" -Value 'Office 2010 profile Reg path not found'
}
#endregion OfficeKeys

#region Wallpaper
$WallpaperPath = Get-ItemProperty 'hkcu:\Control Panel\Desktop' -Name WallPaper

if (-not ($WallpaperPath.WallPaper -like 'C:\Windows\web\wallpaper\Windows\*') -and ($WallpaperPath.WallPaper -like "$env:userprofile*") ) {
    $WallpaperDestinationPath = $WallpaperPath.WallPaper.Replace("$env:userprofile\", '')
    Copy-Item -Path $WallpaperPath.WallPaper -Destination "$Rootshare\$env:UserName\$WallpaperDestinationPath"

    $WallpaperRegSavePath = $UserShare + '\Wallpaper.reg'
    $Wallpaperfilepath = ($WallpaperPath.WallPaper).Replace('\', '\\')

    Remove-Item $WallpaperRegSavePath -ErrorAction SilentlyContinue

    Add-Content -Path $WallpaperRegSavePath -Value `
        "Windows Registry Editor Version 5.00`r`n
    [HKEY_CURRENT_USER\Control Panel\Desktop]`r`n
    `"Wallpaper`"=`"$Wallpaperfilepath`""
}
#endregion Wallpaper


#region LocalUserKeysToExport
$UserRegKeys = @(
    #IE AutoFill
    'Software\Microsoft\InternetExplorer\IntelliForms',
    #Workshare settings
    'SOFTWARE\Workshare\Options',
    #OpenText
    'Software\Hummingbird'
)

foreach ($key in $UserRegKeys) {
    Export-HKCURegKeys -RegKeyPath $key
}

#endregion LocalUserKeysToExport

#region Signature
#https://ifnotisnull.wordpress.com/automated-outlook-signatures-vbscript/configuring-outlook-for-the-signatures-within-the-users-registry/
#Save the signature data to a CSV. The import script will create the appriate keys on its side.
function Export-OutlookSignaturesReg {

    param([string]$OfficeVersionRegpath)

    $ProfileKeys = Get-ChildItem "$OfficeVersionRegpath\Outlook\Profiles" -Recurse | Where-Object {$_.PSPath -like '*9375CFF0413111d3B88A00104B2A6676\00000*'}

    foreach ($profile in $ProfileKeys) {
        $ProfileProperty = Get-ItemProperty -Path $profile.PSPath

        if ($ProfileProperty.'New Signature') {
            $Signatures = New-Object psobject -Property @{
                NewSignature   = $ProfileProperty.'New Signature';
                ReplySignature = $ProfileProperty.'Reply-Forward Signature';
            }
            break
        }
    }

    $Signatures | Export-CSV "$Rootshare\$env:UserName\Signatures.csv" -NoTypeInformation
}

if (Test-Path $Outlook2016Regpath) {
    Export-OutlookSignaturesReg -OfficeVersionRegpath $Outlook2016Regpath
}
elseif (Test-Path $Outlook2013Regpath) {
    Export-OutlookSignaturesReg -OfficeVersionRegpath $Outlook2013Regpath
}
elseif (Test-Path $Outlook2010Regpath) {
    Export-OutlookSignaturesReg -OfficeVersionRegpath $Outlook2010Regpath
}
#endregion Signature