<#

**This script might cause the computer to reboot**

This script updates VMware tools to the latest avalible version.

The script might need to be run several times for fresh installs since VC redist needs to be installed which requires a reboot.

Andy Morales
#>
function Test-RegistryValue {
    <#
    Checks if a reg key/value exists

    #Modified version of the function below
    #https://www.jonathanmedd.net/2014/02/testing-for-the-presence-of-a-registry-key-and-value.html

    Andy Morales
    #>

    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true,
            Position = 1,
            HelpMessage = 'HKEY_LOCAL_MACHINE\SYSTEM')]
        [ValidatePattern('Registry::.*|HKEY_')]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [parameter(Mandatory = $true,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Position = 3)]
        $ValueData
    )

    Set-StrictMode -Version 2.0

    #Add Regdrive if it is not present
    if ($Path -notmatch 'Registry::.*') {
        $Path = 'Registry::' + $Path
    }

    try {
        #Reg key with value
        if ($ValueData) {
            if ((Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Name -ErrorAction Stop) -eq $ValueData) {
                return $true
            }
            else {
                return $false
            }
        }
        #Key key without value
        else {
            $RegKeyCheck = Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Name -ErrorAction Stop
            if ($null -eq $RegKeyCheck) {
                #if the Key Check returns null then it probably means that the key does not exist.
                return $false
            }
            else {
                return $true
            }
        }
    }
    catch {
        return $false
    }
}
function Write-Log {
    <#
    .Synopsis
    Write-Log writes a message to a specified log file with the current time stamp.
    .DESCRIPTION
    The Write-Log function is designed to add logging capability to other scripts.
    In addition to writing output and/or verbose you can write to a log file for
    later debugging.
    .NOTES
    Created by: Jason Wasser @wasserja
    Modified: 11/24/2015 09:30:19 AM

    Changelog:
        * Code simplification and clarification - thanks to @juneb_get_help
        * Added documentation.
        * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks
        * Revised the Force switch to work as it should - thanks to @JeffHicks

    To Do:
        * Add error handling if trying to create a log file in a inaccessible location.
        * Add ability to write $Message to $Verbose or $Error pipelines to eliminate
        duplicates.
    .PARAMETER Message
    Message is the content that you wish to add to the log file.
    .PARAMETER Path
    The path to the log file to which you would like to write. By default the function will
    create the path and file if it does not exist.
    .PARAMETER Level
    Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
    .PARAMETER NoClobber
    Use NoClobber if you do not wish to overwrite an existing file.
    .EXAMPLE
    Write-Log -Message 'Log message'
    Writes the message to c:\Logs\PowerShellLog.log.
    .EXAMPLE
    Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
    Writes the content to the specified log file and creates the path and file specified.
    .EXAMPLE
    Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
    Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
    .LINK
    https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [Alias('LogPath')]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warn", "Info")]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false)]
        [switch]$NoClobber,

        [Parameter(Mandatory = $false)]
        [switch]$DailyMode
    )

    Begin {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
        if ($DailyMode) {
            $Path = $Path.Replace('.', "-$(Get-Date -UFormat "%Y%m%d").")
        }
    }
    Process {
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
        }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            New-Item $Path -Force -ItemType File
        }

        else {
            # Nothing to see here yet.
        }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
            }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
            }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
            }
        }

        # Write log entry to $Path
        #try to write to the log file. Rety if it is locked
        $StopWriteLogloop = $false
        [int]$WriteLogRetrycount = "0"
        do {
            try {
                "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append -ErrorAction Stop
                $StopWriteLogloop = $true
            }
            catch {
                if ($WriteLogRetrycount -gt 5) {
                    $StopWriteLogloop = $true
                }
                else {
                    Start-Sleep -Milliseconds 500
                    $WriteLogRetrycount++
                }
            }
        }While ($StopWriteLogloop -eq $false)
    }
    End {
    }
}

$LogPath = 'C:\Windows\Temp\VMwareUpdateScript.log'

#Check if the computer is a VMware VM
if (( Get-CimInstance -ClassName win32_computersystem).Manufacturer -ne 'VMware, Inc.') {
    Write-Log -Level Info -Path $LogPath -Message 'Computer is not a VMware VM. Script will exit'
    Exit
}

#Find the URL to the latest version
$LatestVersionExe = (Invoke-WebRequest -Uri 'https://packages.vmware.com/tools/releases/latest/windows/x64/' -UseBasicParsing).Links.href  | Where-Object { $_ -match 'VMware-tools-.*\.exe' }
$LatestVersionFullURL = "https://packages.vmware.com/tools/releases/latest/windows/x64/" + "$LatestVersionExe"

if (Test-Path "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe") {
    #Get the file version of the update package, and the installed package
    [version]$ToolsInstalledVersion = ('{0}.{1}.{2}' -f ((Get-Item -Path "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe").VersionInfo.fileversion).split('.') )
    #Check the x86 version so that the script works on x86 and x64
    [Version]$ToolsUpdateVersion = ('{0}.{1}.{2}' -f ([regex]::Match("$LatestVersionExe", '\d{1,2}\.\d{1,2}\.\d{1,2}').value).split('.') )

    #Check to see if the update is newer than the installed version
    If ($ToolsUpdateVersion -gt $ToolsInstalledVersion) {
        $VmToolsShouldBeUpdated = $true
        Write-Log -Level Info -Path $LogPath -Message 'A newer version of VMware Tools is avalible'
    }
    else {
        $VmToolsShouldBeUpdated = $false
    }
}
#If vmtoolsd.exe was not found then VM tools are probably not installed
else {
    $VmToolsShouldBeUpdated = $true
}

if ($VmToolsShouldBeUpdated) {
    Write-Log -Level Info -Path $LogPath -Message 'VMware Tools should be updated'

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    #Detect if VC Redist 2015 is installed
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
        if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -Name 'Major' ) {
            #VC x64 is already installed
            $InstallVCx64 = $false
        }
        else {
            #installVC x64
            $InstallVCx64 = $true
        }

        if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86' -Name 'Major') {
            #VC x86 is already installed
            $InstallVCx86 = $false
        }
        else {
            #installVC x86
            $InstallVCx86 = $true
        }
    }
    else {
        $InstallVCx64 = $false

        if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X86' -Name 'Major') {
            #VC x86 is already installed
            $InstallVCx86 = $false
        }
        else {
            #installVC x86
            $InstallVCx86 = $true
        }
    }

    #Download and Install VC Redist if required
    if ($InstallVCx64) {
        Write-Log -Level Info -Path $LogPath -Message 'Installing VC Redist x64'
        (New-Object System.Net.WebClient).DownloadFile('https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe', 'C:\Windows\Temp\vc_redist.x64.exe')
        $VCx64Proc = Start-Process -Wait -FilePath 'C:\Windows\Temp\vc_redist.x64.exe' -ArgumentList '/Q /restart' -PassThru
    }
    if ($InstallVCx86) {
        Write-Log -Level Info -Path $LogPath -Message 'Installing VC Redist x86'
        (New-Object System.Net.WebClient).DownloadFile('https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x86.exe', 'C:\Windows\Temp\vc_redist.x86.exe')
        $VCx86Proc = Start-Process -Wait -FilePath 'C:\Windows\Temp\VC_redist.x86.exe' -ArgumentList '/Q /restart' -PassThru

    }

    Write-Log -Level Info -Path $LogPath -Message 'Downloading VMware Tools'

    #Download VMware Tools
    (New-Object System.Net.WebClient).DownloadFile("$LatestVersionFullURL", 'C:\Windows\Temp\VMwareTools.exe')

    Write-Log -Level Info -Path $LogPath -Message 'Installing VMware Tools. Check C:\windows\temp\VMToolsInstall.log for more info'

    #Install VMware Tools
    $VMToolsInstallProc = Start-Process -Wait -FilePath 'C:\Windows\Temp\VMwareTools.exe' -ArgumentList '/s /v /qn /l c:\windows\temp\VMToolsInstall.log' -PassThru

    #Reboot if Required
    if ($VCx64Proc.ExitCode -eq '3010' -or $VCx86Proc.ExitCode -eq '3010' -or $VMToolsInstallProc.ExitCode -eq '3010') {
        Write-Log -Level Info -Path $LogPath -Message 'Rebooting Computer'
        Restart-Computer -Force
    }

    Write-Log -Level Info -Path $LogPath -Message 'Done updating VMware tools'
}
else {
    Write-Log -Level Info -Path $LogPath -Message 'There is no need to update VMware Tools'
}
