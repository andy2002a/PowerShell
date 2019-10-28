<#
Creates a scheduled task that invokes ADSync whenever a user changes their password (instead of having to wait 30 minutes).

Andy Morales
#>

#Requires -RunAsAdministrator
#requires -Modules ActiveDirectory,ADSync


[Decimal]$OSBuild = "$([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor)"

#Check to see if the server if 2012 or higher
if ($OSBuild -ge 6.2) {

    $GMSAName = 'GMSA_ADSyncTsk'
    $GMSAFullName = ((Get-WmiObject Win32_ComputerSystem).Domain).Split(".")[0] + '\' + $GMSAName + '$'
    $GMSADNSHostName = $GMSAName + '.' + $( (Get-WmiObject Win32_ComputerSystem).Domain )
    $GMSARetrievePasswordGroupName = $GMSAName + ' AllowToRetrieveManPwd'

    #Create the GMSA retrieve group, and add the currernt computer to the group
    New-ADGroup -Name $GMSARetrievePasswordGroupName -Description "Members of this group can use the GMSA $GMSAName" -GroupScope Global
    Add-ADGroupMember -Identity $GMSARetrievePasswordGroupName -Members ([System.Environment]::MachineName + '$')

    #Purge all Kerberos tickets in order to update group membership without restart
    klist -lh 0 -li 0x3e7 purge

    $NewADServiceAccountParams = @{
        'Name'                                       = $GMSAName;
        'DisplayName'                                = $GMSAName;
        'PrincipalsAllowedToRetrieveManagedPassword' = $GMSARetrievePasswordGroupName;
        'DNSHostName'                                = $GMSADNSHostName
        'Description'                                = 'This Account is used for a scheduled task that runs AD sync when a user changes their password'
    }

    New-ADServiceAccount @NewADServiceAccountParams

    #Add the GMSA to the ADSync Admins Group
    Add-ADGroupMember -Identity 'ADSyncAdmins' -Members "$GMSAName$"

    #install GMSA
    Install-ADServiceAccount -Identity "$GMSAName$"

    #Create Scheduled task
    #https://stackoverflow.com/questions/42801733/creating-a-scheduled-task-which-uses-a-specific-event-log-entry-as-a-trigger
    $TskName = "Start AD Sync on Password Change"
    $TskPath = 'PowerShell.exe'
    $TskArguments = "-command &{Start-ADSyncSyncCycle -PolicyType Delta}"

    $Service = new-object -ComObject ("Schedule.Service")
    $Service.Connect()

    $RootFolder = $Service.GetFolder("\")

    $TaskDefinition = $Service.NewTask(0) # TaskDefinition object https://msdn.microsoft.com/en-us/library/windows/desktop/aa382542(v=vs.85).aspx
    $TaskDefinition.RegistrationInfo.Description = ''
    $TaskDefinition.Settings.Enabled = $True
    $TaskDefinition.Settings.AllowDemandStart = $True

    $Triggers = $TaskDefinition.Triggers
    $Trigger = $Triggers.Create(0) ## 0 is an event trigger https://msdn.microsoft.com/en-us/library/windows/desktop/aa383898(v=vs.85).aspx
    $Trigger.Enabled = $true
    $Trigger.Subscription = '<QueryList><Query Id="0" Path="Security"><Select Path="Security">*[System[(EventID=4724 or EventID=4723)]]</Select></Query></QueryList>'

    $Action = $TaskDefinition.Actions.Create(0)
    $Action.Path = $TskPath
    $action.Arguments = $TskArguments

    $RootFolder.RegisterTaskDefinition($TskName, $TaskDefinition, 6, "System", $null, 5) | Out-Null

    #set the task to use the GMSA
    schtasks /change /TN "\Start AD Sync on Password Change" /RU "$GMSAFullName" /RP
}
