<#
.SYNOPSIS
This script copies all of the folders from $rootShare to the user's local profile.

***IMPORTANT*** if you are using this script to migrate profiles from one forest/domain to another you will need to remove the "COPY:DATSO" on the robocopy command. Replace it with "COPY:DAT". Failure to do so will break the Windows 10 settings application.

The script should only be used on new profiles. Using it on existing profiles will not move over all data.

The script has a kill switch that will only allow it to run once. If you would like to have the script run again delete the file $env:userprofile\BlockImportScript

.NOTES
This should be set as a user login script with deny GPO read permission applied to the old RDS servers.

If you would like to run the script again delete the file "BlockImportScript" under the user's profile.

The robocopy command is set to use 127 threads. This causes incorrect logging, and in some cases can saturate the network link. Remove /MT:127 to resolve this.

.PARAMETER RootShare
This is where the uploaded files are stored

Andy Morales
#>
$RootShare = '\\SERVER\RDSProfileMigration'
$PowerShellLogPath = "$env:userprofile\powerShellImportLog.txt"

function Invoke-Popup {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,
        [Parameter(Mandatory = $false, Position = 1)]
        [string]$MessageHeader = "",
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$MessageLevel = "64",
        [Parameter(Mandatory = $false, Position = 3)]
        [string]$Days = "0",
        [Parameter(Mandatory = $false, Position = 4)]
        [string]$Hours = "0",
        [Parameter(Mandatory = $false, Position = 5)]
        [string]$Minutes = "10"
    )

    switch ($MessageLevel) {
        "Error" {
            $MessageLevel = "16"
        }
        "Warning" {
            $MessageLevel = "48"
        }
        "Informational" {
            $MessageLevel = "64"
        }
        default {
            $MessageLevel = "64"
        }
    }

    $a = New-Object -comobject wscript.shell
    $b = $a.popup($Message, $ConvertedTime, $MessageHeader, $MessageLevel)
}

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

    #User folder on the share
    $UserShare = $RootShare + '\' + $env:UserName

    if (Test-Path -Path $UserShare) {

        Show-BalloonTip –Text 'Your profile data is being moved' -Title 'DO NOT OPEN ANY PROGRAMS' -Icon 'Warning' -Timeout 5000

        try {
            #IndexedDB, '*cache*' are intended to reduce the amount of chrome data
            ROBOCOPY "$UserShare" "$env:userprofile" /R:0 /W:0 /E /xo /COPY:DATSO /MT:127 /dcopy:t /XD "System Volume Information" "*cache*" "$RECYCLE.BIN" "IndexedDB" /XF '*.TMP' /np /log+:"$usershare\roboCopyImportLog.txt"

            #Hide the AppData Folder since robocopy sets it to show
            attrib +h "$env:USERPROFILE\AppData"
        }
        catch {
            Add-Content -Path "$PowerShellLogPath" -Value "Errory copying $UserShare to $env:userprofile"
            Add-Content -Path "$PowerShellLogPath" -Value $Error[0]
        }

        #Find and import any reg items found in the user's profile root.
        #Delete reg key after it has been imported
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
            Remove-Item -Path $env:userprofile\Signatures.csv -force
        }

        #Restart Explorer to make sure any reg changes take effect
        Stop-Process -ProcessName Explorer
        Start-Process -FilePath Explorer.exe

        #Move Chrome Data into Outlook folder (FSLogix Only)
        <#
        robocopy "$env:LOCALAPPDATA\Google\Chrome\User Data" "$env:LOCALAPPDATA\Microsoft\Outlook\ChromeData" /MOVE /R:0 /W:0 /E /xo /COPY:DATSO /dcopy:t /XD "System Volume Information" "*cache*" "$RECYCLE.BIN" "IndexedDB" /XF '*.TMP' '*.temp' /np /purge /log+:"$usershare\roboCopyChromeLog.txt"
        Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data" –recurse -force
        #>


        #Move Chrome Data Out of the FSL ODFC Container
        <#
        if (Test-Path -Path "$env:userprofile\AppData\Local\Microsoft\Outlook\ChromeData"){
                ROBOCOPY "$env:userprofile\AppData\Local\Microsoft\Outlook\ChromeData" "$env:userprofile\AppData\Local\Google\Chrome\User Data" /MOVE /R:0 /W:0 /E /xo /COPY:DATSO /MT:127 /dcopy:t /XD "System Volume Information" "*cache*" "$RECYCLE.BIN" "IndexedDB" /XF '*.TMP' /np /log+:"$usershare\roboCopyImportLog.txt"
                Remove-Item -Path "$env:userprofile\AppData\Local\Microsoft\Outlook\ChromeData" –recurse -force
        }
        #>

        #Create a kill switch that will prevent the script from running again.
        New-Item -Path "$env:userprofile/BlockImportScript" -ItemType File

        #Notify User
        Invoke-popup -message "Files Migrated to Remote."
    }
    else {
        Add-Content -Path "$PowerShellLogPath" -Value "Could not find User's share under $UserShare"

        Invoke-popup -message "Could not find share under $UserShare."
    }
}
else {
    Add-Content -Path "$PowerShellLogPath" -Value "Script did not run because the file $env:userprofile\BlockImportScript exists"
}