<#

.SYNOPSIS
The script asks for OUs that correspond to workstations and servers. It also asks if the user would like to skip extending the schema.
The AdmPwd Module is loaded
The Schema is extended
Two new Domain groups are created. $WorkstationGroupName  and $ServerGroupName  will be able to read passwords corresponding to their respective name.
The script then goes through all the OUs and assigns read permissions to the perviosuly created groups.
Finally, the script assigns computer password write self permission to all OUs.

.DESCRIPTION
This script extends the Active directory schema to include LAPS attributes, and assigns the necessary permissions to the OUs passed to it.

Make sure to pay close attention when specifying OUs. If a top level OU is specified it will be a huge pain to remove those permissions.

.EXAMPLE
Add permissions to the two OUs specified, but do not extend the schema, or create groups
Configure-LAPS.ps1 -DoNotExtendSchema -DoNotCreateGroups

.PARAMETER WorkstationOUs
Workstation OU distinguished names separated by commas.

.PARAMETER ServerOUs
Server OU distinguished names separated by commas.

.PARAMETER DoNotExtendSchema
If specfiied, the script will not extend the AD Schema. This is useful when running the script a second time.

.PARAMETER DoNotCreateGroups
If specfiied, the script will not create the groups $WorkstationGroupName and $ServerGroupName . This is useful when running the script a second time.

#>

#Requires -modules AdmPwd.PS
#Requires -RunAsAdministrator
#Requires -Version 3.0

[cmdletbinding()]
param(
    [Switch]$DoNotExtendSchema,

    [Switch]$DoNotCreateGroups
)


Import-module AdmPwd.PS, ActiveDirectory

$AllADOUs = Get-ADOrganizationalUnit -Filter *

$WorkstationOUs = $AllADOUs | Out-GridView -OutputMode Multiple -Title 'Select Workstaion OUs:'
$serverOus = $AllADOUs | Out-GridView -OutputMode Multiple -Title 'Select Server OUs:'

#Update AD Schema
if (!$DoNotExtendSchema) {
    Update-AdmPwdADSchema
}

$WorkstationGroupName = 'OU_Workstation OUs_LAPS Read'
$ServerGroupName = 'OU_Server OUs_LAPS Read'

if (!$DoNotCreateGroups) {

    try {
        New-ADGroup -Name $WorkstationGroupName -GroupScope DomainLocal
        Add-ADGroupMember -Identity $WorkstationGroupName -Members 'Domain Admins'
    }
    catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "Could not create group $WorkstationGroupName. It might already exist."
    }

    try {
        New-ADGroup -Name $ServerGroupName -GroupScope DomainLocal
        Add-ADGroupMember -Identity $ServerGroupName -Members 'Domain Admins'
    }
    catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "Could not create group $ServerGroupName. It might already exist."
    }
}

#Give $WorstationGroupName read access to OUs
Foreach ($wkOU in $WorkstationOUs) {
    Write-Output "Adding Read permission to Workstation OU $($wkOU)"
    Set-AdmPwdReadPasswordPermission -OrgUnit $wkOU -AllowedPrincipals $WorkstationGroupName
}

#Give $ServerGroupName read access to OUs
Foreach ($srvOU in $ServerOUs) {
    Write-Output "Adding Read permission to Server OU $($srvOU)"
    Set-AdmPwdReadPasswordPermission -OrgUnit $srvOU -AllowedPrincipals $ServerGroupName
}

<#This method is not required since OUs inherit permissions

$WorkstationOUs | ForEach-Object {
    Clear-Variable CurrentWorkstaionOUs, AllWorkstaionOUs -ErrorAction Ignore

    $CurrentWorkstationOUs = Get-ADOrganizationalUnit -SearchBase $_ -SearchScope Subtree -filter *

    $CurrentWorkstationOUs | ForEach-Object {

        Clear-Variable currentOU -ErrorAction Ignore

        $currentOU = $_.DistinguishedName

        Write-Verbose "Setting Workstation OU $currentOU"

        Set-AdmPwdReadPasswordPermission -OrgUnit $currentOU -AllowedPrincipals $WorkstationGroupName
    }

    $AllWorkstaionOUs += $CurrentWorkstationOUs
}

#Enumarate All Server OUs and give Admins read access
$ServerOUs | ForEach-Object {
    Clear-Variable CurrentServerOUs, AllServerOUs -ErrorAction Ignore

    $CurrentServerOUs = Get-ADOrganizationalUnit -SearchBase $_ -SearchScope Subtree -filter *

    $CurrentServerOUs | ForEach-Object {

        Clear-Variable currentOU -ErrorAction Ignore

        $currentOU = $_.DistinguishedName

        Write-Verbose "Setting Server OU $currentOU"

        Set-AdmPwdReadPasswordPermission -OrgUnit $currentOU -AllowedPrincipals $ServerGroupName
    }

    $AllServerOUs += $CurrentServerOUs
}
#>

Clear-Variable AllOUs -ErrorAction Ignore
$AllOUs = $ServerOUs + $WorkstationOUs

#Allow computers to write their password and timestamp to AD
ForEach ($OU in $AllOUs) {
    Write-Output "Adding self write permission to OU $OU"
    Set-AdmPwdComputerSelfPermission -Identity $OU
}

Get-ADComputer -filter * | Reset-AdmPwdPassword
