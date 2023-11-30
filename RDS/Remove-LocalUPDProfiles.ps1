<#

This script deletes local profile data on an RDS server that has UPDs or FSL Profiles. When UPDs are enabled user files will sometimes be left behind. This can cause some unexpected results with applications.

The script has a fail safe that does not run if UPDs or FSL Profiles become disabled at any point.

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
    if ($Path -notmatch 'Registry::.*'){
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
Function Get-RDSActiveSessions {
    <#
    .SYNOPSIS
        Returns open sessions of a local workstation
    .DESCRIPTION
        Get-ActiveSessions uses the command line tool qwinsta to retrieve all open user sessions on a computer regardless of how they are connected.
    .OUTPUTS
        A custom object with the following members:
            UserName: [string]
            SessionName: [string]
            ID: [string]
            Type: [string]
            State: [string]
    .NOTES
        Author: Anthony Howell
    .LINK
        qwinsta
        http://stackoverflow.com/questions/22155943/qwinsta-error-5-access-is-denied
        https://theposhwolf.com
    #>
    Begin {
        $Name = $env:COMPUTERNAME
        $ActiveUsers = @()
    }
    Process {
        $result = qwinsta /server:$Name
        If ($result) {
            ForEach ($line in $result[1..$result.count]) {
                #avoiding the line 0, don't want the headers
                $tmp = $line.split(" ") | Where-Object { $_.length -gt 0 }
                If (($line[19] -ne " ")) {
                    #username starts at char 19
                    If ($line[48] -eq "A") {
                        #means the session is active ("A" for active)
                        $ActiveUsers += New-Object PSObject -Property @{
                            "ComputerName" = $Name
                            "SessionName"  = $tmp[0]
                            "UserName"     = $tmp[1]
                            "ID"           = $tmp[2]
                            "State"        = $tmp[3]
                            "Type"         = $tmp[4]
                        }
                    }
                    Else {
                        $ActiveUsers += New-Object PSObject -Property @{
                            "ComputerName" = $Name
                            "SessionName"  = $null
                            "UserName"     = $tmp[0]
                            "ID"           = $tmp[1]
                            "State"        = $tmp[2]
                            "Type"         = $null
                        }
                    }
                }
            }
        }
        Else {
            Write-Error "Unknown error, cannot retrieve logged on users"
        }
    }
    End {
        Return $ActiveUsers
    }
}

#Array that will store the command and all parameters
$CommandToExecute = @()

#The basic command
$CommandToExecute += 'C:\BIN\DelProf2\DelProf2.exe /u'

$diskSolutionRunning = $False

#UPDs
if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Terminal Server\ClusterSettings' -Name UvhdEnabled -Value 1) {
    #UvhdCleanupBin is also excluded since it is unknown what deleting it will do
    $CommandToExecute += '/ed:UvhdCleanupBin'

    #Exclude logged in users
    $CommandToExecute += "/ed:$((Get-RDSActiveSessions).username -join ' /ed:')"
    
    $diskSolutionRunning = $True
}

#FSL Profiles
if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles' -Name 'Enabled' -ValueData 1) {
    #Exclude Currently logged in users
    $CommandToExecute += "/ed:$((Get-RDSActiveSessions).username -join ' /ed:')"

    #Exclude local_ folder of logged in users
    $CommandToExecute += "/ed:local_$((Get-RDSActiveSessions).username -join ' /ed:Local_')"
    
    $diskSolutionRunning = $True
}

if($diskSolutionRunning){
    $profilesToExclude = @(
        '.NET*',
        'DefaultAppPool*'
    )
    
    $CommandToExecute += "/ed:$($profilesToExclude -join ' /ed:')"
    
    Invoke-Expression -Command ($CommandToExecute -join ' ')
}
else{
    Write-Output "No disk profile application found"
}
