<#

.SYNOPSIS
This script creates users from a CSV file.

The script first creates the user using paramaters that every user will need. It then uses Set-ADuser to add other paramaters if they exist.

.NOTES
If a user has an apostrophe in their name(O'Brien) the Username will not reflect the apostrophe.

The CSV should have the following format:

FirstName,LastName,MiddleName,password,OfficePhone,MobilePhone,Department,Title,Company,State,StreetAddressLine1,StreetAddressLine2,City,PostalCode,AlternateAlias1,AlternateAlias2,CopitrakCode,Extension

.EXAMPLE
New-ADUsersFromCSV.ps1 -Path C:\Users.csv -DomainName 'customer.com' -OUPath "OU=Users,DC=Domain,DC=com" -FInitialLName

Creates new users from the file Users.csv and specifies the email domain name as customer.com.

.EXAMPLE
New-ADUsersFromCSV.ps1 -Path C:\Users.csv OUPath "OU=Users,DC=Domain,DC=com" -FName.LName

Creates new users from the file Users.csv the script will use the Active Directory Domain name for the email address.

.PARAMETER CSVPath
This is the path of the CSV file

.PARAMETER DomainName
Enter a paramter here to specify the domain name of the email addresses. If the customer's domain name is .local this parameter should be specified.

.PARAMETER OUPath
The Path of the OU where users will be created  the format is "OU=Users,DC=Domain,DC=com"

.PARAMETER SkipUserCreation
Setting this parameter will prevent the user from being created. Use this when you want to edit user attributes rather than creating a new user.

.PARAMETER UserNameFormat
The format of the user's User Name

FInitialLName =             JSmith
FInitial.LName =            J.Smith
FNameLname =                JohnSmith
FName.LName =               John.Smith
FInitialMinitialLInitial =  JMS

Andy Morales
#>

#Requires -modules 'ActiveDirectory'
#Requires -Version 3.0

[cmdletbinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CSVPath,
    [Parameter(Mandatory = $true)]
    [string]$OUPath,
    [Parameter(Mandatory = $false)]
    [string]$DomainName,
    [Parameter(Mandatory = $false)]
    [Switch]$SkipUserCreation,
    [Parameter(Mandatory = $true)]
    [ValidateSet ('FInitialLName', 'FInitial.LName', 'FNameLname', 'FName.LName', 'FInitialMinitialLInitial')]
    [string]$UserNameFormat
)#End cmdletbinding

$UsersCSV = Import-Csv -Path "$CSVPath"

#If the user did not enter a domain name use the AD Domain Name
if ([string]::IsNullOrEmpty($DomainName)) {
    $DomainName = (Get-WmiObject Win32_ComputerSystem).Domain
}

#Confirm that domain name is valid
$SiteForest = Get-ADForest
$ValidUPNSuffixes = @( $SiteForest.name.tostring() )
foreach ($UPN in $SiteForest.UPNSuffixes) {
    $ValidUPNSuffixes += $UPN
}
if ( !($ValidUPNSuffixes -contains $DomainName) ) {
    throw [System.DirectoryServices.ActiveDirectory.ActiveDirectoryObjectNotFoundException] "$DomainName is not an accepted domain Name."
}

foreach ($User in $UsersCSV) {
    Try {
        Remove-Variable username, EmailAddress, NewADUserParams, SetADUserParams, proxyAddressesParams -ErrorAction ignore

        if ($User.MiddleName) {
            $FullName = $user.FirstName.trim() + " " + ( ($User.MiddleName.trim()).substring(0, 1) ).ToUpper() + ". " + $User.LastName.trim()
        }#End if
        else {
            $FullName = $user.FirstName.trim() + " " + $User.LastName.trim()
        }#End Else

        if ($UserNameFormat -eq 'FInitialLName') {
            $username = ($User.Firstname).substring(0, 1) + ($User.LastName)
        }#End if
        elseif ($UserNameFormat -eq 'FInitial.LName') {
            $username = ($User.Firstname).substring(0, 1) + '.' + ($User.LastName)
        }#End Else if
        elseif ($UserNameFormat -eq 'FNameLname') {
            $username = $User.Firstname + ($User.LastName)
        }#End Else if
        elseif ($UserNameFormat -eq 'FName.LName') {
            $username = ($User.Firstname) + '.' + ($User.LastName)
        }#End Else if
        elseif ($UserNameFormat -eq 'FInitialMinitialLInitial') {
            if ($User.MiddleName) {
                $username = ( ($User.Firstname).substring(0, 1) + ($User.MiddleName).substring(0, 1) + ($User.LastName).substring(0, 1) ).ToUpper()
            }#End if
            else {
                $username = ( ($User.Firstname).substring(0, 1) + ($User.LastName).substring(0, 1) ).ToUpper()
            }#End Else
        }#End Else if

        #Remove everything except letters, numbers, hiphens, and underscores from the username
        $username = $username -Replace "[^\w-]", ""

        $EmailAddress = $Username + '@' + $DomainName

        $NewADUserParams = @{
            'GivenName'         = $User.FirstName.trim();
            'AccountPassword'   = ConvertTo-SecureString -string  $User.password -AsPlainText -force;
            'Name'              = $FullName;
            'SamAccountName'    = $username;
            'UserPrincipalName' = $EmailAddress;
            'EmailAddress'      = $EmailAddress;
            'DisplayName'       = $FullName;
            'Country'           = "US";
            'Path'              = "$OUPath"
            'Enabled'           = $true
        }#End NewADUserParams

        if ($user.LastName) {
            $NewADUserParams += @{'Surname' = $User.LastName.trim() }
        }#End if

        if ( !($SkipUserCreation) ) {
            New-ADUser @NewADUserParams
        }#End if

        $SetADUserParams = @{
            'Identity' = $username;
        }#End SetADUserParams

        if ($User.MiddleName) {
            $SetADUserParams += @{'Initials' = ($User.MiddleName).substring(0, 1) }
        }#End if

        if ($User.OfficePhone) {
            $SetADUserParams += @{
                'OfficePhone' = $User.OfficePhone;
                'HomePhone'   = $User.OfficePhone
            }#End NewADUserParams
        }#End if

        if ($User.Department) {
            $SetADUserParams += @{'Department' = $User.Department }
        }#End if

        if ($user.Title) {
            $SetADUserParams += @{'Title' = $User.Title }
        }#End if

        if ($user.Company) {
            $SetADUserParams += @{'Company' = $User.Company }
        }#End if

        if ($User.State) {
            $SetADUserParams += @{'State' = $User.State }
        }#End if
        if ($user.StreetAddressLine2) {
            $SetADUserParams += @{'StreetAddress' = $User.StreetAddressLine1 + "`r`n" + $User.StreetAddressLine2 }
        }#End if
        elseif ($user.StreetAddressLine1) {
            $SetADUserParams += @{'StreetAddress' = $User.StreetAddressLine1 }
        }#End Elseif
        if ($User.City) {
            $SetADUserParams += @{'City' = $User.City }
        }#End if
        if ($User.PostalCode) {
            $SetADUserParams += @{'PostalCode' = $User.PostalCode }
        }#End if
        if ($user.MobilePhone) {
            $SetADUserParams += @{'MobilePhone' = $User.MobilePhone }
        }#End if

        $AddParams = @{
            'mailNickName'        = $username;
            'msExchUsageLocation' = "US";
            'proxyaddresses'      = ('SMTP:' + "$EmailAddress")
        }

        if ($User.Extension) {
            $Addparams += @{'ipPhone' = $User.Extension }
        }#End if
        if ($User.CopitrakCode) {
            $Addparams += @{'Pager' = $User.CopitrakCode }
        }#End if

        $SetADUserParams += @{'Add' = $AddParams }

        Set-ADUser @SetADUserParams

        if ($User.AlternateAlias1) {
            #If more aliases are required they can be added to the $Aliases variable
            $Aliases = $User.AlternateAlias1, $User.AlternateAlias2
            $smtpAliases = @()

            ForEach ($Alias in $Aliases) {
                #this checks to make sure that the items in the array are not empty
                if ( ![string]::IsNullOrEmpty($Alias) ) {
                    $currentAlias = 'smtp:' + $alias + '@' + $DomainName
                    $smtpAliases += $currentAlias
                }#End if
            }#End ForEach

            $proxyAddressesParams = @{
                'Identity' = $username;
                'Add'      = @{proxyaddresses = $smtpAliases }
            }#End proxyAddressesParams

            Set-ADUser @proxyAddressesParams
        }#End if

        Write-Output "Successfully created user $($FullName) with username $($username)"

    }#End Try

    Catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Output "Error Creating User $($FullName). The account already exists."
    }#End Catch[Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException]

    catch {
        Write-Output "Unkown error creating User $($FullName)"
        Write-Output $_
    }#End Catch
}#End ForEach
