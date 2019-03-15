#https://gallery.technet.microsoft.com/Users-Profiles-Disks-c445dd22
#Using the UNC path instead of the local path ensures that the UPDs are compacted even in the event that the local disk is changed.
#Andy Morales

$AllUPDs = Get-ChildItem \\SERVER\FSLogix -Recurse -Filter *.vhdx |where name -ne UVHD-template.vhdx | Select-Object -ExpandProperty fullname

foreach ($UPD in $AllUPDs){
    NEW-ITEM -Name compact.txt -ItemType file -force | OUT-NULL
    ADD-CONTENT -Path compact.txt "select vdisk file= $UPD"
    ADD-CONTENT -Path compact.txt "compact vdisk"
    DISKPART /S compact.TXT
}
