<#
This script will remove proxyaddresses that are no longer required or not compatible with Office 365 Hybrid.

Andy Morales
#>
$DomainToRemove = 'example.local'

$AllUsers = get-aduser -filter * -Properties *

Foreach ($user in $AllUsers){
    foreach ($address in $user.proxyAddresses){
        if ($address -like "*$DomainToRemove"){
            $user | Set-ADUser -Remove @{proxyAddresses = $address}
            Write-Output "removed address $($address)"
        }
    }
}
