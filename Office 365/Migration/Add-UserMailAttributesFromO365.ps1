<#
.NAME 
Add-UserMailAttributesFromO365.ps1

.DESCRIPTION
This script adds proxyAddress information and the Email Address field to AD user accounts.

.SYNOPSYS
The script first asks the user for the Office 365 credentials. 

The script then queries all the Mailboxes on Office 365. If AddToPilot has been set the user will be added to the Office 365 Pilot Group.

The Mail, mailNickname, and proxyAddresses attributes are then set for the user. 

.SYNTAX
Add-MailAttributesFromO365.ps1 [-AddToPilot]

.EXAMPLE
Add-MailAttributesFromO365.ps1 -addToPilot

.PARAMETER AddToPilot
This is used when rolling out Azure Connect in stages. An Office 365 pilot group will be required before this can be used.

.REMARKS
Use "Add-MailAttributesFromO365.ps1 -Verbose" to get more details when running the script.


Andy Morales
#>

[cmdletbinding()]
param(
[switch]$AddToPilot
)

Write-Verbose "Asking user for Office 365 credentials"
Write-Host "Enter Office 365 Credentials" -BackgroundColor Yellow -ForegroundColor Black
$Office365Credential = Get-Credential

Write-Verbose "Connecting to Office 365"
$Office365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Office365Credential -Authentication Basic -AllowRedirection
Import-PSSession $Office365Session


Write-Verbose "starting"


$AllMailboxes = Get-Mailbox

Foreach ($Mailbox in $AllMailboxes){
    if($AddToPilot){
        Write-Verbose "Adding user to Pilot group"

        Add-ADGroupMember -Identity Office365Pilot -Members $Mailbox.Alias

        Write-Output "User has been added to group"

    }
    else{
        Write-Output "User will not be added to Pilot Group"
    }


    try {
            Write-Output "Setting User $Mailbox"

            $ADUserParams = @{
                'Identity' = $Mailbox.Alias;
                'EmailAddress' = $Mailbox.WindowsEmailAddress;
                'add' = @{mailNickname = $Mailbox.Alias}
                }
            Set-ADUser @ADUserParams

            ForEach($address in $Mailbox.EmailAddresses) {

                Write-Output "Adding $address to $Mailbox"

                Set-ADUser -Identity $Mailbox.Alias -Add @{proxyAddresses = $address}

            }

            Write-Output "Attributes for user $Mailbox.Alias have been set"
    }

    catch {
        Write-host "Error with  $Mailbox" -BackgroundColor Yellow -ForegroundColor black
    }

}
