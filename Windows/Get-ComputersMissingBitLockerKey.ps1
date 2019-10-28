#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

$AllComputers = Get-ADComputer -filter * | Where-Object {$_.Enabled -eq $true}

$ComputersMissingKey = @()

Foreach ($Computer in $AllComputers){
    Remove-Variable RecoveryKey -ErrorAction SilentlyContinue
    $RecoveryKey = Get-ADObject -Filter 'ObjectClass -eq "msFVE-RecoveryInformation"' -SearchBase (Get-AdComputer $Computer)
    if ($RecoveryKey -eq $null){
        $ComputersMissingKey += $Computer
    }
}

Return $ComputersMissingKey