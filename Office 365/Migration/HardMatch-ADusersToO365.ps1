<#

.SYNOPSIS
This is intended to help when hard matching AD users with Azure AD

.NOTES
Use SkipLogin if you have run the script before on the same session

Andy Morales
#>

#Requires -modules MSOnline

[cmdletbinding()]
param(

[Parameter(Mandatory=$true)]
[string]$O365Email,

[Parameter(Mandatory=$true)]
[string]$ADUser,

[Parameter(Mandatory=$false)]
[Switch]$SkipLogin 

)

try{
    
    if($SkipLogin)
    {
        Write-Verbose "Skipping Office 365 login"
    }
    else {

        Write-Verbose "Asking user for Office 365 credentials"
        Write-Host "Enter Office 365 Credentials" -BackgroundColor Yellow -ForegroundColor Black
        $Office365Credential = Get-Credential

        Write-Verbose "Connecting to Office 365"
        $Office365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Office365Credential -Authentication Basic -AllowRedirection
        Import-PSSession $Office365Session

        Connect-MsolService -Credential $Office365Credential
    }

    [GUID]$UserGuid = (Get-ADUser -Identity $ADUser).ObjectGUID

    $bytearray = $UserGuid.tobytearray()
    $immutableID = [system.convert]::ToBase64String($bytearray)

    Set-MsolUser -UserPrincipalName $O365Email -ImmutableId $immutableID

    Get-Mailbox -Identity $O365Email | ForEach-Object {
        $ADUserParams = @{
            'Identity' = $ADUser;
            'EmailAddress' = $_.WindowsEmailAddress;
            'add' = @{mailNickname = $_.Alias}
            }
        Set-ADUser @ADUserParams

        ForEach($address in $_.EmailAddresses) {

            Write-Verbose "Adding $address to $_"

            Set-ADUser -Identity $ADUser -Add @{proxyAddresses = $address}

        }
    }
}
catch [System.Management.Automation.ParameterBindingException]{
    write-Error "Credentials not received. Please try again."
}
