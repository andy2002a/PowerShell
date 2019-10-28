$GPORootFolder = 'C:\GPOsToImport'
$ErrorLogLocation = "$GPORootFolder\errors.txt"

try{
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function Unzip
    {
        param([string]$zipfile, [string]$outpath)

        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
    }


    $AllZipFiles = Get-ChildItem $GPORootFolder -Filter *.zip

    foreach ($zip in $AllZipFiles){
        Unzip -zipfile $zip.FullName -outpath $zip.FullName.Replace('.zip','')
    }

    try {

        Import-Module activedirectory

        $GPORoot = Get-ChildItem -Path $GPORootFolder -attributes Directory

        $SucessfullyImportedGPOs = @()

        foreach ($folder in $GPORoot) {

            try {
                Remove-Variable GPOFolder, GPOReportPath, GPOReportXML, GPOBackupName -ErrorAction SilentlyContinue

                $GPOFolder = (Get-ChildItem $folder.fullname).FullName
                $GPOReportPath = Get-ChildItem $folder.FullName -Recurse | Where-Object name -eq gpreport.xml

                #Get the Name of the GPO from the content of the XML
                [XML]$GPOReportXML = Get-Content -path $GPOReportPath.FullName
                [string]$GPOBackupName = $GPOReportXML.GPO.Name
                $GPOPrefixedName = "_$GPOBackupName"

                New-GPO -Name $GPOPrefixedName -ErrorAction SilentlyContinue
                Import-GPO -Path $GPOFolder -TargetName $GPOPrefixedName -backupGPOname $GPOBackupName -ErrorAction Stop

                "Sucessfully imported GPO $GPOPrefixedName" | Out-File $ErrorLogLocation -Append
                $SucessfullyImportedGPOs += $GPOPrefixedName

            }
            catch {
                "Error with GPO folder $folder" | Out-File $ErrorLogLocation -Append
                $_ | Out-File $ErrorLogLocation -Append
            }
        }
    }
    Catch {
        $_ | Out-File $ErrorLogLocation -Append
    }

    Write-Output "The following GPOs have been imported sucessfully:"
    $SucessfullyImportedGPOs
}
catch{
    Write-Output 'Ran into error unzipping files. Error has been written to file'
    $_ | Out-File $ErrorLogLocation -Append
}


