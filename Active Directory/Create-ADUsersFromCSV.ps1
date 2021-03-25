<#

.SYNOPSIS
This script creates users from a CSV file.

The script first creates the user using parameters that every user will need. It then uses Set-ADuser to add other parameters if they exist.

.NOTES
If a user has an apostrophe in their name(O'Brien) the Username will not reflect the apostrophe.

The CSV should have the following format:

FirstName,LastName,MiddleName,password,OfficePhone,MobilePhone,Department,Title,Company,State,StreetAddressLine1,StreetAddressLine2,City,PostalCode,AlternateAlias1,AlternateAlias2,CopitrakCode,Extension

.EXAMPLE
Create-ADUsersFromCSV.ps1 -CSVPath C:\Users.csv -DomainName 'customer.com' -OUPath "OU=Users,DC=Domain,DC=com" -UserNameFormat FInitialLName

Creates new users from the file Users.csv and specifies the email domain name as customer.com.

.EXAMPLE
Create-ADUsersFromCSV.ps1 -CSVPath C:\Users.csv -OUPath "OU=Users,DC=Domain,DC=com" -UserNameFormat FName.LName

Creates new users from the file Users.csv the script will use the Active Directory Domain name for the email address.

.PARAMETER CSVPath
This is the path of the CSV file

.PARAMETER DomainName
Enter a parameter here to specify the domain name of the email addresses. If the customer's domain name is .local this parameter should be specified.

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

        #Remove unecessary whitespace
        if ($User.MiddleName) {
            #Select just the middle initial
            $FullName = $user.FirstName.trim() + " " + ( ($User.MiddleName.trim()).substring(0, 1) ).ToUpper() + ". " + $User.LastName.trim()
        }
        else {
            $FullName = $user.FirstName.trim() + " " + $User.LastName.trim()
        }

        Switch ($UserNameFormat) {
            #Remove everything except letters, numbers, hyphens, and underscores from the username
            'FInitialLName' {
                $username = ($User.Firstname -Replace "[^\w-]", "").substring(0, 1) + ($User.LastName -Replace "[^\w-]", "")
            }
            'FInitial.LName' {
                $username = ($User.Firstname -Replace "[^\w-]", "").substring(0, 1) + '.' + ($User.LastName -Replace "[^\w-]", "")
            }
            'FNameLname' {
                $username = ($User.Firstname -Replace "[^\w-]", "") + ($User.LastName -Replace "[^\w-]", "")
            }
            'FName.LName' {
                $username = ($User.Firstname -Replace "[^\w-]", "") + '.' + ($User.LastName -Replace "[^\w-]", "")
            }
            'FInitialMinitialLInitial' {
                if ($User.MiddleName) {
                    $username = ( ($User.Firstname -Replace "[^\w-]", "").substring(0, 1) + ($User.MiddleName -Replace "[^\w-]", "").substring(0, 1) + ($User.LastName -Replace "[^\w-]", "").substring(0, 1) ).ToUpper()
                }
                else {
                    $username = ( ($User.Firstname -Replace "[^\w-]", "").substring(0, 1) + ($User.LastName -Replace "[^\w-]", "").substring(0, 1) ).ToUpper()
                }
            }
        }

        #Shorten the username if it is too long
        if (($username.ToCharArray()).count -gt 20) {
            Write-Output "User $($username) has a username longer than 20 chars. SamAccountName will be shortened"
            $username = ($username.ToCharArray() | Select-Object -first 20) -join ''
        }

        $EmailAddress = $Username + '@' + $DomainName

        $NewADUserParams = @{
            'GivenName'         = $User.FirstName.trim();
            'AccountPassword'   = ConvertTo-SecureString -string  $User.password -AsPlainText -force;
            'Name'              = $FullName;
            #Limit the SamAccountName to 20 chars
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
        }

        #params that need to be added through the "Add" parameter
        $AddParams = @{
            'mailNickName'        = $username;
            'msExchUsageLocation' = "US";
            'proxyaddresses'      = ('SMTP:' + "$EmailAddress")
        }

        #Add all applicable SetAdUserParams if they exist
        switch ($user) {
            { $_.MiddleName } {
                $SetADUserParams += @{'Initials' = ($User.MiddleName).substring(0, 1) }
            }
            { $_.OfficePhone } {
                $SetADUserParams += @{
                    'OfficePhone' = $User.OfficePhone;
                    'HomePhone'   = $User.OfficePhone
                }
            }
            { $_.Department } {
                $SetADUserParams += @{'Department' = $User.Department }
            }
            { $_.Title } {
                $SetADUserParams += @{'Title' = $User.Title }
            }
            { $_.Company } {
                $SetADUserParams += @{'Company' = $User.Company }
            }
            { $_.State } {
                $SetADUserParams += @{'State' = $User.State }
            }
            { $_.City } {
                $SetADUserParams += @{'City' = $User.City }
            }
            { $_.PostalCode } {
                $SetADUserParams += @{'PostalCode' = $User.PostalCode }
            }
            { $_.MobilePhone } {
                $SetADUserParams += @{'MobilePhone' = $User.MobilePhone }
            }
            { $_.Description } {
                $SetADUserParams += @{'Description' = $User.Description }
            }

            #Below are params that need to be added manually though the "Add" parameter
            { $_.Extension } {
                $Addparams += @{'ipPhone' = $User.Extension }
            }
            { $_.CopitrakCode } {
                $Addparams += @{'Pager' = $User.CopitrakCode }
            }
        }

        if ($user.StreetAddressLine2) {
            $SetADUserParams += @{'StreetAddress' = $User.StreetAddressLine1 + "`r`n" + $User.StreetAddressLine2 }
        }#End if
        elseif ($user.StreetAddressLine1) {
            $SetADUserParams += @{'StreetAddress' = $User.StreetAddressLine1 }
        }#End Elseif

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
        Write-Output "Unknown error creating User $($FullName)"
        Write-Output $_
    }#End Catch
}#End ForEach
