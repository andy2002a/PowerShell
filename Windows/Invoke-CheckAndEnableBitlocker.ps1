#The script sometimes has an issue where it cannot activate the TPM as a startup script. Some troubleshooting needs to be done. 

$CdriveStatus = Get-BitLockerVolume -MountPoint 'c:'

if ($CdriveStatus.volumeStatus -eq 'FullyDecrypted') {
    if ((Get-Tpm -ErrorAction SilentlyContinue).TpmPresent) {
	C:\Windows\System32\manage-bde.exe -on c: -recoverypassword -skiphardwaretest
	#The line below might work better but it has not been tested yet
        #C:\Windows\sysnative\manage-bde.exe -on c: -recoverypassword -skiphardwaretest
    }
}