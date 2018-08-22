<#

.SYNOPSIS
This script copies all of the folders from $rootShare to the user's local profile.

The script should only be used on new profiles. Using it on exsiting profiles will not move over all data.

The script has a killswitch that will only allow it to run once. If you would like to have the script run again delete the file $env:userprofile\BlockImportScript

.NOTES
This should be set as a user login script only on the new RDS servers OU.

If you would like to run the script again delete the file "BlockImportScript" under the user's profile.

.PARAMETER RootShare
This is the path of the CSV file

Andy Morales
#>
$RootShare = '\\SERVER\TSProfileMigration'
$PowerShellLogPath = "$env:userprofile\powerShellImportLog.txt"

function Show-BalloonTip {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        $Text,

        [Parameter(Mandatory = $true)]
        $Title,

        [ValidateSet('None', 'Info', 'Warning', 'Error')]
        $Icon = 'Info',
        $Timeout = 10000
    )

    Add-Type -AssemblyName System.Windows.Forms

    if ($script:balloon -eq $null) {
        $script:balloon = New-Object System.Windows.Forms.NotifyIcon
    }

    $path = Get-Process -id $pid | Select-Object -ExpandProperty Path
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
    $balloon.BalloonTipIcon = $Icon
    $balloon.BalloonTipText = $Text
    $balloon.BalloonTipTitle = $Title
    $balloon.Visible = $true

    $balloon.ShowBalloonTip($Timeout)
}#http://www.powertheshell.com/balloontip/

if (-not (Test-Path $env:userprofile\BlockImportScript)) {

    Show-BalloonTip –Text 'Your profile data is being moved' –Title 'DO NOT OPEN ANY PROGRAMS' –Icon 'Warning' –Timeout 5000

    #Create user folder on the share
    $UserShare = $RootShare + '\' + $env:UserName

    try {
        ROBOCOPY "$UserShare" "$env:userprofile" /R:0 /W:0 /E /xo /COPY:DATSO /dcopy:t /XD 'System Volume Information' '*cache*' '$RECYCLE.BIN' 'IndexedDB' /XF '*.TMP' /np /log+:"$usershare\roboCopyImportLog.txt"
        #IndexedDB, '*cache*' are intended to reduce the amount of chrome data
    }
    catch {
        Add-Content -Path "$PowerShellLogPath" -Value "Errory copying $UserShare to $env:userprofile"
        Add-Content -Path "$PowerShellLogPath" -Value $Error[0]
    }

    #Find and import any reg items found in the user's profile root.
    #Delete rege key after it has been imported
    $RegFilesToImport = Get-ChildItem $env:userprofile -Filter *.reg
    foreach ($reg in $RegFilesToImport) {
        REG IMPORT $reg.FullName

        Remove-Item -Path $reg.FullName -force
    }

    #Import Signatures registry
    if (Test-Path -Path $env:userprofile\Signatures.csv) {
        $Signatures = Import-Csv $env:userprofile\Signatures.csv
        New-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\MailSettings' -Name 'NewSignature' -Value $Signatures.NewSignature -PropertyType ExpandString
        New-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\MailSettings' -Name 'ReplySignature' -Value $Signatures.ReplySignature -PropertyType ExpandString
    }

    #Create a killswitch that will prevent the script from running again.
    New-item -Path "$env:userprofile/BlockImportScript" -ItemType File

    #Notify User
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Your files have been migrated to the remote profile.", 0, "Done", 0x0)
}
else {
    Add-Content -Path "$PowerShellLogPath" -Value "Script did not run because the file $env:userprofile\BlockImportScript exists"
}