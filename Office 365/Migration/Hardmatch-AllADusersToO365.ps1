<#

.SYNOPSIS


.EXAMPLE


.PARAMETER SearchBase

.PARAMETER SkipLogin

https://gallery.technet.microsoft.com/scriptcenter/Convert-between-Immutable-e1e96aa9

Andy Morales
#>

#Requires -modules MSOnline,ADSync

[cmdletbinding()]
param(

[Parameter(Mandatory=$true)]
[string]$SearchBase,

[Parameter(Mandatory=$false)]
[Switch]$SkipLogin 

)

try{
    if($SkipLogin){
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

    $users = Get-ADUser -Filter * -SearchBase "$SearchBase" -Properties mail,samaccountname

    #Change ImmutableId
    foreach ($user in $users){
        
        Remove-Variable UserGuid,immutableID,bytearray,ADUsername,ADEmail -ErrorAction SilentlyContinue

        $ADUsername = $user.samAccountName
        $ADEmail = $user.mail

        Write-Verbose "Changing ImmutableId for user $ADUsername"

        [GUID]$UserGuid = (Get-ADUser -Identity $ADUsername).ObjectGUID
    
        $bytearray = $UserGuid.tobytearray()
        $immutableID = [system.convert]::ToBase64String($bytearray)

        Set-MsolUser -UserPrincipalName $ADEmail -ImmutableId $immutableID
       
    }

    <#
    #change the UPN back to the email
    $users | ForEach-Object {

        $ADUsername = $_.UserPrincipalName
        $ADEmail = $_.mail

        Write-Verbose "Changing UPN for user $ADUsername to $ADEmail"

        Set-MsolUserPrincipalName -UserPrincipalName $ADUsername -NewUserPrincipalName $ADEmail
    }
    #>
}

catch [System.Management.Automation.ParameterBindingException]{
    write-Error "Credentials not received. Please try again."
}
