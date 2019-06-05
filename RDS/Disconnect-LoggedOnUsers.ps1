<#
This script is intended to be used before a reboot script, although it could be modified to reboot the server as well.

All users will be logged out of the computer. The goal is to allow applications to close on their own without being force closed.

Andy Morales
#>
#https://blog.ipswitch.com/how-to-log-off-windows-users-remotely-with-powershell
#https://blogs.msdn.microsoft.com/kenobonn/2014/03/29/create-event-log-sources-using-powershell/

$EventLogSourceName = 'RebootScript'

#set error action to stop so that we can use try/catch on cmd commands
$ErrorActionPreference = 'Stop'

#Create RebootScript Event Log source if it does not exist
if ([System.Diagnostics.EventLog]::SourceExists("$EventLogSourceName") -eq $false) {
    [System.Diagnostics.EventLog]::CreateEventSource("$EventLogSourceName", 'System')
}

#Check to see if the computer is running at least Windows 8.1 (Server 2012 R2)
if ([Environment]::OSVersion.Version -lt '6.3.9200') {
    Write-EventLog -LogName System -Source "$EventLogSourceName" -EventId 3156 -EntryType 'Warning' -Message "The OS Version is lower than Windows 8.1. The script will exit."
    exit
}

#get all the current sessions
$quserOutput = quser

#Remove the heading of all the columns. Also remove leading and trailing white space
$quserOutput = ($quserOutput[3..($quserOutput.length - 2)]).trim()

#create Empty array
$AllCurrentLoggedonUsers = @()

#go through all of the quser lines and convert them into PowerShell objects
foreach ($line in $quserOutput) {
    try {
        $parts = $Line -split "\s{2,}"

        #create the PS object if the array has 6 items.
        if ($parts.count -eq 6 ) {
            $AllCurrentLoggedonUsers += [PSCustomObject]@{
                USERNAME    = $parts[0]
                SESSIONNAME = $parts[1]
                ID          = [int]$parts[2]
                STATE       = $parts[3]
                IDLETIME    = $parts[4]
                LOGONTIME   = $parts[5]
            }
        }
        #create the PS object if the array has 5 items. This finds users who are disconencted.
        elseif ($parts.count -eq 5 ) {
            $AllCurrentLoggedonUsers += [PSCustomObject]@{
                USERNAME  = $parts[0]
                ID        = [int]$parts[1]
                STATE     = $parts[2]
                IDLETIME  = $parts[3]
                LOGONTIME = $parts[4]
            }
        }
        else {
            Throw "Could not parse text. Not enough, or too many items in the array"
        }
    }
    catch {
        $EventLogMessage = "Error Parsing the line below `n $parts"
        Write-EventLog -LogName System -Source "$EventLogSourceName" -EventId 3154 -EntryType 'Warning' -Message $EventLogMessage
    }
}

#log out all active users
Foreach ($user in $AllCurrentLoggedonUsers) {
    try {
        logoff $($user.ID)

        $EventLogMessage = "The user below was successfully logged off `n $user"
        Write-EventLog -LogName System -Source "$EventLogSourceName" -EventId 3150 -EntryType 'Information' -Message $EventLogMessage.trim()
    }
    catch {

        $EventLogMessage = "There was an error logging off the user below `n $user"

        Write-EventLog -LogName System -Source "$EventLogSourceName" -EventId 3152 -EntryType 'Error' -Message $EventLogMessage.trim()

        Write-EventLog -LogName System -Source "$EventLogSourceName" -EventId 3153 -EntryType 'Error' -Message $_.Exception.Message

    }
}
