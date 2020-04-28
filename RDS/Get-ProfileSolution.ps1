
<#
This script will identify which profile solution is applied to a computer.

Standard windows profiles will yield a blank output.

The script will also detect if multiple profile solutions are enabled and throw an error

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

$ProfileSolution = @()
#Will be used to find how many profile solutions have been enabled (ideally the final number should be just 1)
$ProfileSolutionCount = 0

if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles' -Name 'Enabled' -ValueData '1') {
    #FSL Profiles
    if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\FSLogix\ODFC' -Name 'Enabled' -ValueData '1') {
        $ProfileSolution += 'FSL Profiles + ODFC'
    }
    else{
        $ProfileSolution += 'FSL Profiles'
    }
    $ProfileSolutionCount++
}

if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'WFProfilePath') {
    #Roaming Profiles
    $ProfileSolution += "RDS Roaming Profiles"
    $ProfileSolutionCount++
}

if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'MachineProfilePath') {
    #Roaming Profiles
    $ProfileSolution += "Roaming Profiles"
    $ProfileSolutionCount++
}

if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Terminal Server\ClusterSettings' -Name 'UvhdEnabled' -ValueData '1') {
    #UPD
    if (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\FSLogix\ODFC' -Name 'Enabled' -ValueData '1') {
        $ProfileSolution += 'UPD + FSL ODFC'
    }
    else{
        $ProfileSolution += 'UPD'
    }

    $ProfileSolutionCount++
}

if($ProfileSolutionCount -gt 1){
    #If there is more than one profile solution in place something is wrong. Append ERROR to the output.
    $ProfileSolution = 'ERROR: ' + ($ProfileSolution -join ' ')
}

#Return all profile solutions found. If nothing was found return a blank value to clear the field in the RMM.
Return $ProfileSolution