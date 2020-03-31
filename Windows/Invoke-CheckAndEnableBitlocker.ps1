#https://adameyob.com/2016/12/08/zero-touch-bitlocker-deployments/
#Script has been modified
<#

This script enables BitLocker for computers.

It will also make sure that the computer is not a VM.

Andy Morales
#>

#Check Status of System Drive
$SystemDriveStatus = Get-BitLockerVolume -MountPoint $env:SystemDrive

#Check to see if the Drive is an SSD
#Using foreach loop to improve reliability of pipeline
$SystemDriveType = Get-Partition -DriveLetter ($env:SystemDrive).Substring(0, 1) | Get-Disk | ForEach-Object { Get-PhysicalDisk -FriendlyName $_.FriendlyName }

#Check to see if the Computer is a VM
$ComputerType = Get-WmiObject -Class Win32_ComputerSystem

$VmModels = @(
    'Virtual Machine',
    'VMware Virtual Platform',
    'VirtualBox'
)

Function Backup-KeyProtectors {
    #Getting Recovery Key GUID
    [array]$RecoveryKeyGUID = (Get-BitLockerVolume -MountPoint $env:SystemDrive).keyprotector | Where-Object { $_.Keyprotectortype -eq 'RecoveryPassword' } | Select-Object -ExpandProperty KeyProtectorID

    #Backing up all protectors to AD
    foreach ($GUID in $RecoveryKeyGUID) {
        manage-bde.exe  -protectors $env:SystemDrive -adbackup -id $GUID
    }
}

if ($VmModels -match $ComputerType.Model) {
    $isPhysical = $false
}
else {
    $isPhysical = $true
}

#Check requirements and start BitLocker process
if ($SystemDriveStatus.volumeStatus -eq 'FullyEncrypted') {

    if ($SystemDriveStatus.ProtectionStatus -eq 'off') {

        [array]$RecoveryKeyGUID = (Get-BitLockerVolume -MountPoint $env:SystemDrive).keyprotector | Where-Object { $_.Keyprotectortype -eq 'RecoveryPassword' } | Select-Object -ExpandProperty KeyProtectorID

        if ($RecoveryKeyGUID.count -eq 0) {
            Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector | Out-Null
        }

        Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector | Out-Null
        Start-Sleep -Seconds 15 #This is to give sufficient time for the protectors to fully take effect.

        #Try encrypting the drive with manage-bde
        Start-Process 'manage-bde.exe' -ArgumentList " -on $env:SystemDrive" -Verb runas -Wait

        Backup-KeyProtectors

        Restart-Computer -Force
    }
    else {
        Write-Output 'Drive is already encrypted'
        exit 0
    }
}
elseif ($SystemDriveStatus.volumeStatus -eq 'EncryptionInProgress') {
    Write-Output 'Drive is currently encrypting'
    exit 109
}
elseif ($SystemDriveStatus.volumeStatus -eq 'FullyDecrypted' -and $SystemDriveType.MediaType -eq 'SSD' -and $isPhysical) {

    $TPM = Get-WmiObject win32_tpm -Namespace root\cimv2\security\microsofttpm | Where-Object { $_.IsEnabled().Isenabled -eq 'True' } -ErrorAction SilentlyContinue
    $WindowsVer = Get-WmiObject -Query 'select * from Win32_OperatingSystem where (Version like "6.2%" or Version like "6.3%" or Version like "10.0%") and ProductType = "1"' -ErrorAction SilentlyContinue
    $SystemDriveBitLockerRDY = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue

    if ($WindowsVer -and $tpm -and !$SystemDriveBitLockerRDY) {
        Get-Service -Name defragsvc -ErrorAction SilentlyContinue | Set-Service -Status Running -ErrorAction SilentlyContinue
        BdeHdCfg -target $env:SystemDrive shrink -quiet
        Restart-Computer -Force
    }

    $BitLockerReadyDrive = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue

    #If all of the above pre-requisites are met, then create the key protectors, then enable BitLocker and backup the Recovery key to AD.
    if ($WindowsVer -and $TPM -and $BitLockerReadyDrive) {

        #Creating the recovery key
        #This is not required when using the Enable-BitLocker cmdlet
        #Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector | Out-Null

        #Adding TPM key
        Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -TpmProtector | Out-Null
        Start-Sleep -Seconds 15 #This is to give sufficient time for the protectors to fully take effect.

        #Enabling Encryption
        #Start-Process 'manage-bde.exe' -ArgumentList " -on $env:SystemDrive" -Verb runas -Wait
        Enable-BitLocker -Mountpoint $env:SystemDrive -RecoveryPasswordProtector

        Backup-KeyProtectors

        Restart-Computer -Force
    }
}
else {
    Write-Output 'Computer did not meet requirements for Bitlocker encryption'
    exit 1
}
