<#

This script returns the FSL ODFC path that is configured on a server.

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

#Check to see if FSL ODFC is enabled
if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles' -Name 'Enabled' -ValueData '1') {
    if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles' -Name VHDLocations) {
        Return (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles' -Name VHDLocations).VHDLocations
    }
    else {
        Return ''
    }
}
else {
    Return ''
}