#https://gallery.technet.microsoft.com/Users-Profiles-Disks-c445dd22
#Using the UNC path instead of the local path ensures that the UPDs are compacted even in the event that the local disk is changed.
#Andy Morales

$VHDXPaths = @(
    '\\SERVER\FSLogix',
    '\\SERVER\ProfileDisks'
)

$VHDXExclusions = @(
    'UVHD-template.vhdx'
)

Foreach ($Path in $VHDXPaths){
    $AllUPDs = Get-ChildItem $Path -Recurse -Filter *.vhdx | Where-Object {$VHDXExclusions -NotContains $_.name} | Select-Object -ExpandProperty fullname

    foreach ($UPD in $AllUPDs){
        Write-Output "select vdisk file= $UPD" "compact vdisk" | DISKPART
    }
}
