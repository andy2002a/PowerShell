<#

This script is intended to be a standalone and universal script that queries all collections and identifies if UPDs are low on space.

The script is currently configured to send emails directly through email. However, it can be easily modified to output raw HTML or objects/tables.

The script must be run as Administrator

Andy Morales
#>

$SMTPServerAddress = 'example.mail.protection.outlook.com'
$TOAddress = 'Admin@example.com'
$FROMAddress = 'PowerShellNotifications@example.com'

$UPDLowDiskSpaceThresholdGB = 5
$FslProfileLowDiskSpaceThresholdGB = 5
$FslOdfcLowDiskSpaceThresholdGB = 5

#The paths below will not be checked for low disk space
$ExcludedPaths = @(
    '\\EXAMPLE\ProfileDisks\Data\UVHD-S-1-5-25-9658-309485160-2151-88454.vhdx'
)


#You should not have to modify anything below this line

function Test-RegistryValue {
    #https://www.jonathanmedd.net/2014/02/testing-for-the-presence-of-a-registry-key-and-value.html
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true,
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [parameter(Mandatory = $true,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Position = 3)]
        [ValidateNotNullOrEmpty()]$ValueData
    )
    try {
        if ($ValueData) {
            if ((Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Name -ErrorAction Stop) -eq $ValueData) {
                return $true
            }
            else {
                return $false
            }
        }
        else {
            Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Name -ErrorAction Stop | Out-Null
            return $true
        }
    }
    catch {
        return $false
    }
}

#Exit the script if the computer is not a server
if ((Get-WmiObject Win32_ComputerSystem).domainrole -lt 3) {
    Write-Verbose 'Computer is not a server. Script will exit'
    Exit
}

#Region UPDs
#Check to see if the Computer is an RD Gateway
if ((Get-WindowsFeature -Name 'RDS-Gateway').Installed) {
    Import-Module remotedesktop

    #Used to identify if UPDs are enabled
    $UPDsEnabled = $false
    $FslProfilesEnabled = $false
    $FslOdfcEnabled = $false

    #Used to Identify if at least one UPD is low on space
    $LowSpaceUPDsFound = $false

    $UPDsLowOnSpace = @()

    try {
        $AllCollections = Get-RDSessionCollection -ErrorAction stop

        Foreach ($Collection in $AllCollections) {

            $CurrentCollectionSettings = $collection | Get-RDSessionCollectionConfiguration -UserProfileDisk

            if ($CurrentCollectionSettings.EnableUserProfileDisk) {
                $UPDsEnabled = $true
                $UPDsLowOnSpace = @()

                #Convert the UPD max size to bytes
                $UPDMaxSafeSize = ($CurrentCollectionSettings.MaxUserProfileDiskSizeGB - $UPDLowDiskSpaceThresholdGB) * 1000000000

                $UPDsLowOnSpace += Get-ChildItem -Path $CurrentCollectionSettings.DiskPath -Recurse | Where-Object { $ExcludedPaths -notcontains $_.FullName } | Where-Object { $_.Length -gt $UPDMaxSafeSize }

                if ($UPDsLowOnSpace.Count -gt 0) {
                    $LowSpaceUPDsFound = $true
                }
                else {
                    $LowSpaceUPDsFound = $false
                }
            }
        }
    }
    catch {
        Write-Verbose 'RD Session Collection not found'
    }
}
else {
    Write-Verbose 'Computer is not an RD Gateway'
}
#endregion UPDs

#Region FSL ODFC
if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Fslogix\Odfc' -Name Enabled -ValueData 1) {
    $FslOdfcEnabled = $true

    #Find the max size of the Odfcs. If it is not found default to 30GB.
    if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Fslogix\Odfc' -Name SizeInMBs) {
        $FslOdfcMaxSize = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Fslogix\Odfc' -Name SizeInMBs -ErrorAction stop).SizeInMBs
    }
    else {
        $FslOdfcMaxSize = 30000
    }

    #Create array to store found disks
    $FslOdfcsLowOnSpace = @()

    $FslOdfcMaxSafeSize = ($FslOdfcMaxSize / 1000 - $FslOdfcLowDiskSpaceThresholdGB) * 1000000000

    $FslOdfcVHDLocation = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Fslogix\Odfc' -Name VHDLocations).VHDLocations

    $FslOdfcsLowOnSpace += Get-ChildItem -Path $FslOdfcVHDLocation -Recurse | Where-Object { $ExcludedPaths -notcontains $_.FullName } | Where-Object { $_.Length -gt $FslOdfcMaxSafeSize }

    if ($FslOdfcsLowOnSpace.Count -gt 0) {
        $LowSpaceFslOdfcFound = $true
    }
    else {
        $LowSpaceFslOdfcFound = $false
    }
}
else {
    Write-Verbose 'FSL Odfc is likely not enabled'
}
#Endregion FSL ODFC

#Region FSL Profiles
if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Fslogix\Profiles' -Name Enabled -ValueData 1) {
    $FslProfilesEnabled = $true

    #Find the max size of the Odfcs. If it is not found default to 30GB.
    if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Fslogix\Profiles' -Name SizeInMBs) {
        $FslProfileMaxSize = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Fslogix\Profiles' -Name SizeInMBs -ErrorAction stop).SizeInMBs
    }
    else {
        $FslProfileMaxSize = 30000
    }

    #Create array to store found disks
    $FslProfilesLowOnSpace = @()

    $FslProfileMaxSafeSize = ($FslProfileMaxSize / 1000 - $FslProfileLowDiskSpaceThresholdGB) * 1000000000

    $FslProfileVHDLocation = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Fslogix\Profiles' -Name VHDLocations).VHDLocations

    $FslProfilesLowOnSpace += Get-ChildItem -Path $FslProfileVHDLocation -Recurse | Where-Object { $ExcludedPaths -notcontains $_.FullName } | Where-Object { $_.Length -gt $FslProfileMaxSafeSize }

    if ($FslProfilesLowOnSpace.Count -gt 0) {
        $LowSpaceFslProfileFound = $true
    }
    else {
        $LowSpaceFslProfileFound = $false
    }
}
else {
    Write-Verbose 'FSL Profiles are likely not enabled'
}
#Endregion FSL Profiles

if ($LowSpaceUPDsFound -or $LowSpaceFslOdfcFound -or $LowSpaceFslProfileFound) {
    #Convert the powershell data into HTML tables

    $AllHTMLTables = @()

    if ($LowSpaceUPDsFound) {
        $UPDTable1 = ConvertTo-Html -Body "The UPDs below are over the $UPDLowDiskSpaceThresholdGB GB Low Disk space threshold"
        $UPDTable2 = $UPDsLowOnSpace | Select-Object FullName, LastAccessTime, @{l = 'CurrentSize'; e = { [math]::round($_.length / 1gb, 2) } } | Sort-Object FullName | ConvertTo-Html -Title 'UPDs Low on Space' -PreContent '<h3>UPDs Low on Space</h3>'

    }
    if ($LowSpaceFslOdfcFound) {
        $OdfcTable1 = ConvertTo-Html -Body "The ODFC containers below are over the $FslOdfcLowDiskSpaceThresholdGB GB Low Disk space threshold"
        $OdfcTable2 = $FslOdfcsLowOnSpace | Select-Object FullName, LastAccessTime, @{l = 'CurrentSize'; e = { [math]::round($_.length / 1gb, 2) } } | Sort-Object FullName | ConvertTo-Html -Title 'FSL ODFC Low on Space' -PreContent '<h3>FSL ODFC Low on Space</h3>'
    }
    if ($LowSpaceFslProfileFound) {
        $FslProfileTable1 = ConvertTo-Html -Body "The FSL profiles below are over the $FslProfileLowDiskSpaceThresholdGB GB Low Disk space threshold"
        $FslProfileTable2 = $FslProfilesLowOnSpace | Select-Object FullName, LastAccessTime, @{l = 'CurrentSize'; e = { [math]::round($_.length / 1gb, 2) } } | Sort-Object FullName | ConvertTo-Html -Title 'FSL Profiles Low on Space' -PreContent '<h3>FSL Profiles Low on Space</h3>'
    }

    $ReportHTMLTables = ConvertTo-HTML -body "$UPDTable1<br>$UPDTable2<br>$OdfcTable1<br>$OdfcTable2<br>$FslProfileTable1<br>$FslProfileTable2"

    Send-MailMessage -To $TOAddress -From $FROMAddress -Subject 'Profile Containers Low on Disk Space' -BodyAsHtml "$ReportHTMLTables" -SmtpServer "$SMTPServerAddress"
    #Return $ReportHTMLTables
}
