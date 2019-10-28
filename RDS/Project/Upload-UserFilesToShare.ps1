<#
.SYNOPSIS
This script copies all of the folders under $LocationsToCopy to a network location. Those files will later be moved into the user's profile using another script.

Network paths(in the case of redirected AppData) can also be copied over to a share.

Various regsitry keys are also copied over to a share.

The script will only copy data from one server. This is intended to reduce data corruption in the event that users are load balanced in non persistent environments(including Roaming profiles). To remove this comment out the CheckForPreviousRun region.

.NOTES
This should be set as a user login script with deny GPO read permission applied to the new RDS servers. See: https://i.imgur.com/X6gtv7v.png

You must create a shared folder with Redirected Folder permissions. https://blogs.technet.microsoft.com/migreene/2008/03/24/ntfs-permissions-for-redirected-folders-or-home-directories/
This will allow users to create their own folder while keeping their files secure.

Additional reg keys can be copied over by adding items to the $UserRegKeys array.

The robocopy command is set to use 127 threads. This causes incorrect logging, and in some cases can saturdate the network link. Remove /MT:127 to resolve this.

.PARAMETER RootShare
This is the path of the network share that will host the files.

Andy Morales
#>

$RootShare = '\\SERVER\RDSProfileMigration'

#Create user folder on the share
$UserShare = $RootShare + '\' + $env:UserName

#Comment the block below if you are moving users out of UPDs.

#Region CheckForPreviousRun
#Check to see if the script has ran before
if (Test-Path "$UserShare\hasran.txt") {
    #Exit the script if it is running from a computer other than the original
    if ((Get-Content -Path "$UserShare\hasran.txt") -ne $env:COMPUTERNAME) {
        exit
    }
}
#endregion CheckForPreviousRun

New-item -Path $UserShare -ItemType Directory -Force

$PowerShellLogPath = "$usershare\powerShellExportLog.txt"

#region CopyFiles
$LocationsToCopy = @(
    #'Desktop',
    #'Links',
    #'Favorites',
    #'Downloads',
    #'Pictures',
    #'Videos',
    '.vscode',
    'AppData\Local\Google\Chrome\User Data',
    'AppData\Local\Microsoft\office',
    'AppData\Roaming\Microsoft\Signatures',
    'AppData\Roaming\Microsoft\Templates',
    'AppData\Roaming\Mozilla\Firefox',
    'AppData\Roaming\Microsoft\Proof',
    'AppData\Roaming\Microsoft\UProof',
    'AppData\Roaming\Microsoft\Office',
    'AppData\Roaming\Microsoft\Outlook'
    'AppData\Roaming\Microsoft\Windows\Themes',
    'AppData\Roaming\Microsoft\Windows\Recent',
    'AppData\Roaming\Microsoft\Windows\Cookies',
    'AppData\Roaming\Microsoft\Windows\INetCookies',
    'AppData\Roaming\Corel',
    'AppData\Roaming\Notepad++',
    'AppData\Roaming\Visual Studio Code',
    'AppData\Roaming\Cisco\Unified Communications',
    'AppData\Roaming\VMware',
    'AppData\Roaming\Code',
    'AppData\Roaming\Greenshot',
    'AppData\Roaming\PowerShell Pro Tools',
    #If chrome data has been moved into FSL
    'AppData\Local\Microsoft\Outlook\ChromeData'
)

foreach ($Location in $LocationsToCopy) {
    try {
        ROBOCOPY "$env:userprofile\$Location" "$Rootshare\$env:UserName\$Location" /R:0 /W:0 /E /xo /COPY:DATSO /MT:127 /dcopy:t /XD 'System Volume Information' '*cache*' '$RECYCLE.BIN' 'IndexedDB' /XF '*.TMP' '*.temp' '*.localstorage' '*.OST' /np /purge /log+:"$usershare\roboCopyExportLog.txt"
        #IndexedDB, '*cache*', and '*.localstorage' are intended to reduce the amount of chrome data
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
        ROBOCOPY "\\SERVER\rprofiles$\$env:UserName\$Location" "$Rootshare\$env:UserName\$Location" /R:0 /W:0 /E /xo /COPY:DATSO /dcopy:t /XD 'System Volume Information' '*cache*' '$RECYCLE.BIN' 'IndexedDB' /XF '*.TMP' '*.temp' /np /purge /log+:"$usershare\roboCopyExportLog.txt"
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
    #Excel Recent Items(does not work on upgrades)
    '\Excel\User MRU',
    #Word Recent Items(does not work on upgrades)
    '\Word\User MRU',
    #Office Common Settings
    '\Common',
    '\User Settings'
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
    'Software\Microsoft\Internet Explorer\IntelliForms',
    #Workshare settings
    'SOFTWARE\Workshare\Options',
    #OpenText
    'Software\Hummingbird',
    #WinZip
    'Software\Nico Mak Computing\WinZip',
    #WordPerfect
    'SOFTWARE\Corel',
    #OfficeCommon Settings
    'Software\Microsoft\Office\Common',
    #Custom dictionaries
    'Software\Microsoft\Shared Tools\Proofing Tools'
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

    $ProfileKeys = Get-ChildItem "$OfficeVersionRegpath\Outlook\Profiles" -Recurse | Where-Object { $_.PSPath -like '*9375CFF0413111d3B88A00104B2A6676\00000*' }

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

    if ($Signatures -ne $null) {
        $Signatures | Export-CSV "$Rootshare\$env:UserName\Signatures.csv" -NoTypeInformation
    }
    else {
        Add-Content -Path "$PowerShellLogPath" -Value 'Signatures not found'
    }
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

#Create file indicating that the script has run
if (-not (Test-Path "$UserShare\hasran.txt")) {
    $env:COMPUTERNAME | Out-File "$UserShare\hasran.txt"
}
