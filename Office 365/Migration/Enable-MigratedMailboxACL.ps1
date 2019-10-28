<#
This script is intended to be run as a scehduled task every 5 hours or so.

The Scheduled task should look like this: https://imgur.com/a/JiV3Dqe

The script will set an attrbiute that allows delegate mailbox access across the Hybrid.

Use the SA_Hybrid account to run the task since it should have all the required permissions.

https://docs.microsoft.com/en-us/exchange/hybrid-deployment/set-up-delegated-mailbox-permissions
Andy Morales
#>

$LogLocation = 'C:\BIN\365Migration\Logs\MailboxACLScript.txt'

function Get-TimeStamp {
    #https://www.gngrninja.com/script-ninja/2016/2/12/powershell-quick-tip-simple-logging-with-timestamps
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

#Do not modify line below
$LogFolder = $LogLocation.Substring(0, $LogLocation.LastIndexOf('\'))

#Check to see if Log Folder exists
if (!(Test-Path -Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory
}

#Detect if Exchange PSSnapins exist
if (Get-PSSnapin -Registered 'Microsoft.Exchange.Management.PowerShell.*' -ErrorAction SilentlyContinue) {
    #Exchange 2013+
    if (Get-PSSnapin -Registered -Name 'Microsoft.Exchange.Management.PowerShell.SnapIn' -ErrorAction SilentlyContinue) {
        Add-PSSnapin -Name 'Microsoft.Exchange.Management.PowerShell.SnapIn'

        if ((Get-OrganizationConfig).ACLableSyncedObjectEnabled) {
            "$(Get-TimeStamp) ACLableSyncedObjectEnabled was already enabled" | Out-file $LogLocation -Force -Append
        }
        else {
            try {
                Set-OrganizationConfig -ACLableSyncedObjectEnabled $True -ErrorAction Stop
                "$(Get-TimeStamp) ACLableSyncedObjectEnabled has been enabled" | Out-file $LogLocation -Force -Append
            }
            catch {
                "$(Get-TimeStamp) Could not enable ACLableSyncedObjectEnabled" | Out-file $LogLocation -Force -Append
            }
        }
    }
    #Exchange 2010
    ElseIf (Get-PSSnapin -Registered -Name 'Microsoft.Exchange.Management.PowerShell.E2010' -ErrorAction SilentlyContinue) {
        Add-PSSnapin -Name 'Microsoft.Exchange.Management.PowerShell.E2010'
    }
    Get-RemoteMailbox -ResultSize unlimited | ForEach-Object { Get-AdUser -Identity $_.Guid | Set-ADObject -Replace @{msExchRecipientDisplayType = -1073741818 } }
    "$(Get-TimeStamp) Atributes have been set for all moved users" | Out-file $LogLocation -Force -Append
}
else {
    "$(Get-TimeStamp) PowerShell PSSnapins not found" | Out-file $LogLocation -Force -Append
}