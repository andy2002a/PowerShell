<#

.SYNOPSIS
This script exports several exchange attributes to a CSV. Those attrbiutes can alter be added back on using Import-ExchangeAttributesFromCSV.ps1

.EXAMPLE
Export-ADExchangeAttrbiutesToCSV.ps1 -UsersCSVPath C:\UserAttributes.csv -GroupsCSVPath C:\GroupAttributes.csv

Exports the Exchange Attributes to the file attributes.csv

.PARAMETER CSVPath
This is the path of the CSV file

Andy Morales
#>

[cmdletbinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$UsersCSVPath,

    [Parameter(Mandatory = $true)]
    [string]$GroupsCSVPath

)#End cmdletbinding

Import-module activedirectory

$AllUsersAttributes = @()

$users = Get-ADUser -Filter * -Properties mail, proxyaddresses, mailnickname, legacyexchangeDN

ForEach ($user in $users) {
    Clear-Variable UserProxyAddresses, CurrentUserAttributes -ErrorAction silentlycontinue

    $UserProxyAddresses = $user.proxyaddresses -join '|'

    $CurrentUserAttributes = [PSCustomObject]@{
        SamAccountName    = $user.SamAccountName
        mail              = $user.mail
        userprincipalname = $user.UserPrincipalName
        mailnickname      = $user.mailnickname
        legacyexchangeDN  = $user.legacyexchangeDN
        proxyaddresses    = $UserProxyAddresses
    }#End [PSCustomObject]

    $AllUsersAttributes += $CurrentUserAttributes
}#End ForEach

$AllUsersAttributes | Export-Csv -Path $UsersCSVPath -NoTypeInformation



$AllGroupsAttributes = @()

$Groups = Get-ADGroup -Filter * -Properties mail, proxyaddresses, mailnickname, legacyexchangeDN

ForEach ($user in $Groups) {
    Clear-Variable UserProxyAddresses, CurrentUserAttributes -ErrorAction silentlycontinue

    $UserProxyAddresses = $user.proxyaddresses -join '|'

    $CurrentGroupAttributes = [PSCustomObject]@{
        SamAccountName    = $user.SamAccountName
        mail              = $user.mail
        userprincipalname = $user.UserPrincipalName
        mailnickname      = $user.mailnickname
        legacyexchangeDN  = $user.legacyexchangeDN
        proxyaddresses    = $UserProxyAddresses
    }#End [PSCustomObject]

    $AllGroupsAttributes += $CurrentGroupAttributes
}#End ForEach

$AllGroupsAttributes | Export-Csv -Path $GroupsCSVPath -NoTypeInformation
