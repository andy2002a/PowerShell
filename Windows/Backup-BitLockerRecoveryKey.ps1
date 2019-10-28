<#
This script is intended to backup a computer's BitLocker recovery keys.

They keys will first be backed up into AD.
All of the keys will be put in a text file under C:\Windows\Temp. Only Administrators will have access to the file.
The first protector for the C drive will be returned as the output of this script.

Out-Null is used a lot to avoid incorrect output from going into the RMM tool.
#>

Try {
    $AllBitLockerVolumes = Get-BitLockerVolume -ErrorAction Stop | Where-Object { $_.ProtectionStatus -eq 'on' }
}
Catch [Microsoft.Management.Infrastructure.CimException ] {
    Write-Verbose 'Could not run Get-BitLockerVolume command. Bitlocker Feature is probably not enabled'
}
Catch [System.Runtime.InteropServices.COMException] {
    Write-Verbose 'Could not run Get-BitLockerVolume command. Bitlocker Feature is probably not enabled'
}
Catch {
    Write-Verbose 'Unknown error occured running Get-BitLockerVolume command'
}

$BitLockerVolumesForExport = @()

Foreach ($Volume in $AllBitLockerVolumes) {

    $PasswordKeyProtectors = $volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

    Foreach ($Protector in $PasswordKeyProtectors) {
        #Backup the bitlocker key to AD. Out-Null so we don't get any output
        try {
            Backup-BitLockerKeyProtector -MountPoint $volume.MountPoint -KeyProtectorId $Protector.KeyProtectorId -ErrorAction Stop | Out-Null
        }
        Catch {
            Write-Verbose "Key for Drive $($volume.MountPoint) with ID $($Protector.KeyProtectorId) could not be backed up to AD."
        }

        #Add items to an Array that will exported to a file later
        $BitLockerVolumesForExport += [PSCustomObject]@{
            ComputerName     = $env:COMPUTERNAME
            Drive            = $volume.MountPoint;
            ProtectorID      = $Protector.KeyProtectorId;
            RecoveryPassword = $Protector.RecoveryPassword
        }
    }

    If ($Volume.MountPoint -eq 'C:') {
        #Output the first key protector found for the C drive
        Write-Output $PasswordKeyProtectors[0].RecoveryPassword
    }

}

if ($BitLockerVolumesForExport.Count -gt 0 ) {

    #region CreateFolder
    $FolderDirectory = 'C:\Windows\Temp\BLK'

    New-Item -Path $FolderDirectory -ItemType Directory -Force | Out-Null

    ICACLS ("$FolderDirectory") /reset | Out-Null

    #Add SYSTEM permission
    ICACLS ("$FolderDirectory") /grant ("SYSTEM" + ':(OI)(CI)F') | Out-Null

    #Give Administrators Full Control
    ICACLS ("$FolderDirectory") /grant ("Administrators" + ':(OI)(CI)F') | Out-Null

    #Disable Inheritance on the Folder. This is done last to avoid permission errors.
    ICACLS ("$FolderDirectory") /inheritance:r | Out-Null
    #endregion CreateFolder

    $BitLockerVolumesForExport | Export-Csv -NoTypeInformation -Path "$FolderDirectory\BitLockerRecoveryKeys.csv"
}
