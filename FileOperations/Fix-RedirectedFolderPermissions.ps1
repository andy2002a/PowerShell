$RootFolder = Get-ChildItem -Path 'L:\User Folders'

$Errors = @()

foreach ($folder in $RootFolder){
        #Clear all Explicit Permissions on the folder
        ICACLS ("$($folder.FullName)") /reset /T /q

        #Give the user Full Control over the folder
        ICACLS ("$($folder.FullName)") /grant ("$($folder.BaseName)" + ':(OI)(CI)F') /q
    

        if($LASTEXITCODE -ne 0){
            $Errors += "Error Setting Full Control for $($folder.FullName)"
        }

        #Make user Owner
        ICACLS $folder.FullName /setowner $folder.BaseName /T /q

        if($LASTEXITCODE -ne 0){
            $Errors += "Error Setting Owner permissions for $($folder.FullName)"
        }
}

$errors
