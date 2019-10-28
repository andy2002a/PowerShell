<#

This script deletes local profile data on an RDS server that has UPDs or FSL Profiles. When UPDs are enabled user files will sometimes be left behind. This can cause some unexpected resuults with applications.

The script has a failsafe that does not run if UPDs or FSL Profiles become disabled at any point.

Andy Morales
#>
function Test-RegistryValue {
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
            Get-ItemProperty -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty $Name -ErrorAction Stop | Out-Null
            return $true
        }
    }
    catch {
        return $false
    }
}

if ((Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Terminal Server\ClusterSettings' -Name UvhdEnabled -Value 1) -or (Test-RegistryValue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Profiles' -Name 'Enabled' -ValueData 1)) {
    #Exclude local_ since FSL Profiles create some local items
    #UvhdCleanupBin is also excluded since it is unknown what deleting it will do
    & C:\BIN\DelProf2\DelProf2.exe /u /ed:local_* /ed:UvhdCleanupBin
}
else {
    Write-Output "UPDs are not enabled. The script will not run"
}
