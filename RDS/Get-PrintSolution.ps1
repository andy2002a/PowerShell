<#
This script will identify which (if any) printing solution is installed on the machine.

The script will return a blank space if nothing is found. The goal of this is to set the computer property to blank in the event that the application is removed.

Andy Morales
#>

function Test-RegistryValue {
    #Modified version of the function below
    #https://www.jonathanmedd.net/2014/02/testing-for-the-presence-of-a-registry-key-and-value.html
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true,
            Position = 1,
            HelpMessage = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM')]
        [ValidatePattern('Registry::.*')]
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
            $RegKeyCheck = Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Name -ErrorAction Stop | Out-Null
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

$PrintSolution = @()

If (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Tricerat\Simplify Console\External Tools' -Name 'Menu0' -ValueData RegDiff) {
    #Simplify Print Console
    $PrintSolution += 'Simplify Print Console'
}

if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Tricerat\Simplify Printing\ScrewDrivers Print Server v6' -Name Port) {
    #Simplify Print Server
    $PrintSolution += 'Simplify Print Server'
}

if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Tricerat\Simplify Printing' -Name dwProviderAvailable -ValueData 1) {
    #Simplify Printing
    $PrintSolution += 'Simplify Printing'
}

if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Tricerat\Simplify Printing\ScrewDrivers Server v6' -Name StandAlone -ValueData 1) {
    #ScrewDrivers Redirection
    $PrintSolution += 'ScrewDrivers Redirection'
}

if (Test-Path "$env:ProgramFiles\PaperCut MF Client\pc-client.exe") {
    #Papercut
    $PrintSolution += 'PaperCut'
}

Return $PrintSolution -join ' '
