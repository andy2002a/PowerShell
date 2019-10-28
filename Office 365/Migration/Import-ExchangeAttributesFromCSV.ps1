<#

.SYNOPSIS
This script imports the Exchnage attributes that were exported by the Export-ADExchangeAttrbiutesToCSV.ps1 script

.EXAMPLE
Import-ExchangeAttributesFromCSV.ps1 -UserCSVPath C:\UserAttributes.csv -GroupCSVPath C:\GroupAttributes.csv

Adds the Exchange Attributes from the file attributes.csv

.PARAMETER CSVPath
This is the path of the CSV file

Andy Morales
#>

[cmdletbinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$UserCSVPath,
	
	[Parameter(Mandatory = $true)]
    [string]$GroupCSVPath
	

)#End cmdletbinding

Remove-Variable ADuserParams -ErrorAction Ignore

$UsersCSV = Import-Csv -Path $UserCSVPath

ForEach ($user in $UsersCSV) {
    Clear-Variable proxyaddresses, ADuserParams -ErrorAction Ignore

    $proxyaddresses = ($user.proxyaddresses).split('|')

    $ADuserParams = @{
        'Identity'     = $user.samaccountName;
        'EmailAddress' = $user.mail;
        'Add'          = @{legacyexchangeDN = $user.legacyexchangeDN; mailNickName = $user.mailnickname; proxyaddresses = $proxyaddresses}
    }#End $ADuserParams

    Try {
        Set-ADuser @ADuserParams -ErrorAction stop
        Write-Output "Information for user $($user.samaccountname) has been added"
    }#End Try
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Output "Could not find user $($user.samaccountname)"
    }#End Catch
    catch {
        Write-Output "Unknown Error adding user $($user.samaccountname) One of the values might be empty"
        Write-output $_
    }#End Catch
}


Remove-Variable ADGroupParams -ErrorAction Ignore

$GroupsCSV = Import-Csv -Path $GroupCSVPath

ForEach ($Group in $GroupsCSV) {
    Clear-Variable proxyaddresses, ADuserParams -ErrorAction Ignore

    $proxyaddresses = ($Group.proxyaddresses).split('|')

    $ADGroupParams = @{
        'Add'          = @{mail = $Group.mail; legacyexchangeDN = $Group.legacyexchangeDN; mailNickName = $Group.mailnickname; proxyaddresses = $proxyaddresses}
    }#End $ADuserParams

    Try {
        Get-ADGroup $Group.samaccountName | Set-ADGroup @ADGroupParams -ErrorAction stop
        Write-Output "Information for group $($Group.samaccountname) has been added"
    }#End Try
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Output "Could not find group $($Group.samaccountname)"
    }#End Catch
    catch {
        Write-Output "Unknown Error adding group $($Group.samaccountname) One of the values might be empty"
        Write-output $_
    }#End Catch
}
