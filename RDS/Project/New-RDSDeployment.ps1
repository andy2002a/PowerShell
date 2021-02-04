<#
.SYNOPSIS
This script creates an RDG Deployment.

.DESCRIPTION
The script will add all RDS servers to one collection. Any required roles will be installed. The certificate for all roles will be assigned to the RDG.

The default webpage of the server will be redirected to RDWeb.

.PARAMETER RDSservers
All of the RDS Servers that will be part of the collection.

.PARAMETER RDWebFQDN
RDWebsite URL remote.example.com

.PARAMETER CertificateFullPath
Full path to the certificate file. CSR can be generated with New-RDGCertRequest.ps1

Andy Morales
#>
#Requires -Modules remotedesktopservices, remotedesktop, servermanager, servermanagertasks, ActiveDirectory, IISAdministration -Version 5 -RunAsAdministrator

$RDSservers = @('RDS1', 'RDS2')
$LicensingServerFQDN = 'SRV.domain.com'
$RDWebFQDN = 'remote.example.com'
$CollectionName = 'Collection'
$GatewayName = 'RDG1'
$CertificateFullPath = 'C:\temp\f2b531849d3e966c.crt'

$DisconnectedSessionLimitMin = '480'
$IdleSessionLimitMin = '120'


Write-Output "The Script will do the Following: `n`
    Add the Following RDS Servers to the farm: $($RDSServers)`n
    Use the following server for Licensing: $($LicensingServerFQDN)`n
    Use the following server as the gateway: $($GatewayName)`n
    Use the Following URL as the RDWeb URL: $($RDWebFQDN)`n
    Create and add all RDS Servers to the collection: $($CollectionName)`n
    Idle Session Limit: $($IdleSessionLimitMin)`n
    Disconnected Session Limit: $($DisconnectedSessionLimitMin)
    "

$confirmation = Read-Host "Do these settings look correct? [y/n]"
if ($confirmation -ne 'y') {
    Write-Output 'Script is terminating due to user input.'
    break
}

Import-Module remotedesktopservices, remotedesktop, servermanager, servermanagertasks, IISAdministration, ActiveDirectory

Function Set-RdPublishedName {
    #https://gallery.technet.microsoft.com/Change-published-FQDN-for-2a029b80
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, HelpMessage = "Specifies the FQDN that clients will use when connecting to the deployment.", Position = 1)]
        [string]$ClientAccessName,
        [Parameter(Mandatory = $False, HelpMessage = "Specifies the RD Connection Broker server for the deployment.", Position = 2)]
        [string]$ConnectionBroker = "localhost"
    )

    $CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    If (($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) -eq $false) {
        $ArgumentList = "-noprofile -noexit -file `"{0}`" -ClientAccessName $ClientAccessName -ConnectionBroker $ConnectionBroker"
        Start-Process powershell.exe -Verb RunAs -ArgumentList ($ArgumentList -f ($MyInvocation.MyCommand.Definition))
        Exit
    }

    Function Get-RDMSDeployStringProperty ([string]$PropertyName, [string]$BrokerName) {
        $ret = iwmi -Class "Win32_RDMSDeploymentSettings" -Namespace "root\CIMV2\rdms" -Name "GetStringProperty" `
            -ArgumentList @($PropertyName) -ComputerName $BrokerName `
            -Authentication PacketPrivacy -ErrorAction Stop
        Return $ret.Value
    }

    Try {
        If ((Get-RDMSDeployStringProperty "DatabaseConnectionString" $ConnectionBroker) -eq $null) {
            $BrokerInHAMode = $False
        }
        Else {
            $BrokerInHAMode = $True
        }
    }
    Catch [System.Management.ManagementException] {
        If ($Error[0].Exception.ErrorCode -eq "InvalidNamespace") {
            If ($ConnectionBroker -eq "localhost") {
                Write-Host "`n Set-RDPublishedName Failed.`n`n The local machine does not appear to be a Connection Broker.  Please specify the`n FQDN of the RD Connection Broker using the -ConnectionBroker parameter.`n" -ForegroundColor Red
            }
            Else {
                Write-Host "`n Set-RDPublishedName Failed.`n`n $ConnectionBroker does not appear to be a Connection Broker.  Please make sure you have `n specified the correct FQDN for your RD Connection Broker server.`n" -ForegroundColor Red
            }
        }
        Else {
            $Error[0]
        }
        Exit
    }

    $OldClientAccessName = Get-RDMSDeployStringProperty "DeploymentRedirectorServer" $ConnectionBroker

    If ($BrokerInHAMode.Value) {
        Import-Module RemoteDesktop
        Set-RDClientAccessName -ConnectionBroker $ConnectionBroker -ClientAccessName $ClientAccessName
    }
    Else {
        $return = iwmi -Class "Win32_RDMSDeploymentSettings" -Namespace "root\CIMV2\rdms" -Name "SetStringProperty" `
            -ArgumentList @("DeploymentRedirectorServer", $ClientAccessName) -ComputerName $ConnectionBroker `
            -Authentication PacketPrivacy -ErrorAction Stop
        $wksp = (gwmi -Class "Win32_Workspace" -Namespace "root\CIMV2\TerminalServices" -ComputerName $ConnectionBroker)
        $wksp.ID = $ClientAccessName
        $wksp.Put() | Out-Null
    }

    $CurrentClientAccessName = Get-RDMSDeployStringProperty "DeploymentRedirectorServer" $ConnectionBroker

    If ($CurrentClientAccessName -eq $ClientAccessName) {
        Write-Host "`n Set-RDPublishedName Succeeded." -ForegroundColor Green
        Write-Host "`n     Old name:  $OldClientAccessName`n`n     New name:  $CurrentClientAccessName"
        Write-Host "`n If you are currently logged on to RD Web Access, please refresh the page for the change to take effect.`n"
    }
    Else {
        Write-Host "`n Set-RDPublishedName Failed.`n" -ForegroundColor Red
    }
}

#Get the domain name and append it to the RDG
$DomainName = (Get-WmiObject Win32_ComputerSystem).Domain
$RdgFQDN = $GatewayName + '.' + $DomainName

#Append the domain name to all RDS servers
$RDSServersFQDN = @()
Foreach ($RdsSrv in $RDSservers) {
    $RDSServersFQDN += ($RdsSrv + '.' + $DomainName)
}


#region Create-RDDeployment
Write-Output "Creating Session deployment using $($rdgFQDN) as the gateway"

try {
    New-RDSessionDeployment -ConnectionBroker $RdgFQDN -WebAccessServer $RdgFQDN -SessionHost $RdgFQDN -ErrorAction Stop
}
catch {
    Write-Output "Could not create new RD Session deployment on gateway $($RdgFQDN)"
    break
}
#endregion Create-RDDeployment

#region Add-RDGateway
Write-Output "Adding $($rdgFQDN) as a gateway server"

try {
    $AddRDGParams = @{
        'Server'              = $RdgFQDN;
        'Role'                = 'RDS-GATEWAY';
        'ConnectionBroker'    = $RdgFQDN;
        'GatewayExternalFqdn' = $RDWebFQDN
    }

    Add-RDServer @AddRDGParams -ErrorAction Stop
}
catch {
    Write-Output "Could not create new RD Session deployment on gateway $($RdgFQDN)"
    break
}
#endregion Add-RDGateway


#Get RDS Servers in the Farm
try {
    $CurrentRDSServers = (Get-RDServer -ErrorAction Stop).server
}
catch {
    Write-Output 'No RDS Servers found. This is not an issue if this is a new deployment'
}

#region Add-RDSServersToFarm
Write-Output "Adding RDS Servers $($RDSServersFQDN) to the farm"

try {
    Remove-Variable rdssrv -ErrorAction SilentlyContinue
    foreach ($RdsSrv in $RDSServersFQDN) {
        if ($CurrentRDSServers -match $RdsSrv) {
            Write-Output "Server $($RdsSrv) is already in the farm. It will be skipped."
        }
        else {
            Add-RDServer -Server $RdsSrv -Role RDS-RD-SERVER -ConnectionBroker $RdgFQDN -ErrorAction Stop
        }
    }
}
catch {
    Write-Output "Could not add server $($RDSSrv) to the farm.
            Make sure that the name is spelled correctly
            Make sure the RDG name is correct
            Make sure that the server is not in the farm already"
    Break
}
#endregion Add-RDSServersToFarm

#region Set-RDSLicensing
Write-Output "Configuring RD Licensing. $($LicensingServerFQDN) will be the licensing server for the gateway $($RdgFQDN)"

if ($CurrentRDSServers -match $LicensingServerFQDN) {
    Write-Output "Server $($LicensingServerFQDN) is already in the farm. It will be skipped."
}
else {
    $AddLicensingServerParams = @{
        'Server'           = $LicensingServerFQDN;
        'Role'             = 'RDS-LICENSING';
        'ConnectionBroker' = $RdgFQDN
    }

    Try {
        Add-RDServer @AddLicensingServerParams -ErrorAction Stop
        Write-Output "$($LicensingServerFQDN) has been sucessfully added to the farm"
    }
    Catch {
        Write-Output "Could not add the server $($LicensingServerFQDN) to the farm."
        break
    }
}

try {
    $RDLicenseConfigurationParams = @{
        'LicenseServer'    = $LicensingServerFQDN;
        'Mode'             = 'PerUser';
        'ConnectionBroker' = $RdgFQDN;
        'Force'            = $true
    }

    Set-RDLicenseConfiguration @RDLicenseConfigurationParams -ErrorAction Stop
    Write-Output "$($LicensingServerFQDN) has been sucessfully configured as the licensing server for $($RdgFQDN)"
}
catch {
    Write-Output "Could not configure server $($LicensingServerFQDN) as a licensing server."
    break
}
#endregion Set-RDSLicensing

#region Set-GatewaySettings
try {

    Write-Output "Changing Gateway settings of $($RdgFQDN)"

    $RDDeploymentGatewayConfigurationParams = @{
        'ConnectionBroker'     = $RdgFQDN;
        'GatewayExternalFqdn'  = $RDWebFQDN;
        'UseCachedCredentials' = $true;
        'BypassLocal'          = $false;
        'LogonMethod'          = 'Password';
        'GatewayMode'          = 'Custom';
        'Force'                = $true
    }

    Set-RDDeploymentGatewayConfiguration @RDDeploymentGatewayConfigurationParams -ErrorAction Stop

    Write-Output "Gateway settings of $($RdgFQDN) have been changed"
}
catch {
    Write-Output "Could not set GatewaySettings. Settings will be displayed below"
    $RDDeploymentGatewayConfigurationParams
}
#endregion Set-GatewaySettings

#region Create-NewCollection
try {
    Write-Output "Creating collection $($CollectionName)"

    New-RDSessionCollection -CollectionName $CollectionName -SessionHost $RDSServersFQDN -ConnectionBroker $RDGFQDN -ErrorAction Stop

    Write-Output "Collection $($CollectionName) has been created"
}
catch {
    Write-Output "The creation of the collection $($CollectionName) returned an error. Restart server manager. Ignore this error if the collection exists now."
}

try {
    $RDSessionCollectionConfigurationParams = @{
        'CollectionName'              = $CollectionName;
        'DisconnectedSessionLimitMin' = $DisconnectedSessionLimitMin;
        'IdleSessionLimitMin'         = $IdleSessionLimitMin
    }

    Write-Output "Changing Inactivity settings for collection $($Collectionname)"

    Set-RDSessionCollectionConfiguration @RDSessionCollectionConfigurationParams  -ErrorAction Stop

    Write-Output "Collection $($CollectionName) inactivity settings have been set"
}
catch {
    Write-Output "Could not change inactivity settings for collection $($CollectionName). Make sure that they are not controlled through GPO"
}
#Endregion Create-NewCollection


#Region Configure-RDSCertificates
try {
    $CertificateFile = Get-ChildItem -Path $CertificateFullPath

    $PFXCertFilePath = 'c:\temp\RDGCert.pfx'

    $CertificateFile | Import-Certificate -CertStoreLocation cert:\LocalMachine\My

    $CertPassword = ConvertTo-SecureString -String 'Thi$pa55isactuallyNotSecure' -Force -AsPlainText

    $certPrint = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certPrint.Import($CertificateFile)

    Get-ChildItem -Path "cert:\localMachine\my\$($certPrint.Thumbprint)" | Export-PfxCertificate -FilePath $PFXCertFilePath -Password $CertPassword

    $RDRoles = @(
        'RDGateway',
        'RDWebAccess',
        'RDRedirector',
        'RDPublishing'
    )

    foreach ($Role in $RDRoles) {
        Set-RDCertificate -Role $Role -ImportPath $PFXCertFilePath -Password $CertPassword -ConnectionBroker $RdgFQDN -Force
    }

    Remove-Item -Path $PFXCertFilePath
}
catch {
    Write-Host 'Could not import SSL Certificate. Try re-keying the cert even if you just did so. Also use the ZIP file from the website, not the one from the email.' -BackgroundColor Yellow -ForegroundColor black
}
#endregion Configure-RDSCertificates

#region Configure-DefaultSiteRedirection
Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\Default Web Site" -Value @{enabled = "true"; destination = "https://$RDWebFQDN/rdweb"; exactDestination = "true"; httpResponseStatus = "Permanent"; childOnly="true"}
#endregion Configure-DefaultSiteRedirection

#Region Add-RDGtoGroups
#This should not be necessary, but it's done just in case the gateway didn't get added to that group
Add-ADGroupMember -Identity 'RAS and IAS servers' -Members "$($GatewayName)$"
#endregion Add-RDGtoGroups

#Fix Certificate mismatch
#Set RD RAP to allow access to all computers
Set-Item -Path 'RDS:\GatewayServer\RAP\RDG_AllDomainComputers\ComputerGroupType' -Value 2
Set-RdPublishedName -ClientAccessName $RDWebFQDN
#Remove All Desktops from RDWeb
Set-WebConfigurationProperty -PSPath 'IIS:\Sites\Default Web Site\RDweb\Pages' -Filter "/appSettings/add[@key='ShowDesktops']" -Name 'Value' -Value 'false'

#Enable Password Change
Set-WebConfigurationProperty -PSPath 'IIS:\Sites\Default Web Site\RDweb\Pages' -Filter "/appSettings/add[@key='PasswordChangeEnabled']" -Name 'Value' -Value 'true'

#Enable private mode logins
((Get-Content -Path 'C:\Windows\Web\RDWeb\Pages\en-US\Default.aspx' -Raw) -replace 'bPrivateMode = false', 'bPrivateMode = true') | Set-Content -Path 'C:\Windows\Web\RDWeb\Pages\en-US\Default.aspx'

#Automatically add DOMAIN to logins
$ExpressionWithDomain = "
if ( -1 == strDomainUserName.indexOf(`"\\`") && -1 == strDomainUserName.indexOf(`"@`"))
{
objForm.elements[`"DomainUserName`"].value = `"$env:userdomain\\`" + objForm.elements[`"DomainUserName`"].value;
strDomainUserName = objForm.elements[`"DomainUserName`"].value;
}"

$DomainJs = Get-Content -Path "C:\Windows\Web\RDWeb\Pages\webscripts-domain.js"
$DomainJs[40] += $ExpressionWithDomain
$DomainJs | Set-Content "C:\Windows\Web\RDWeb\Pages\webscripts-domain.js"

#region RdWebClient
#Only install if OS is Server 2016+
if ([environment]::OSVersion.Version -gt [version]('{0}.{1}.{2}.{3}' -f '10.0.0.0'.split('.'))) {
    #Install required modules
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-PackageProvider -Name NuGet -Force -Confirm:$False
    Install-Module –Name PowershellGet -Force -Confirm:$False
    Install-Module -Name RDWebClientManagement -AcceptLicense -Confirm:$False

    Import-RDWebClientBrokerCert $CertificateFullPath
    Install-RDWebClientPackage
    Publish-RDWebClientPackage -Type Production -Latest
}
#endregion RdWebClient
