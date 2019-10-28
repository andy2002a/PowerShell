#Requires -Modules remotedesktopservices,remotedesktop,servermanager,servermanagertasks,IISAdministration -Version 5 -RunAsAdministrator

[cmdletbinding()]
param(

    [Parameter(Mandatory = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 1)]
    [string[]]$RDSservers,

    [Parameter(Mandatory = $true, HelpMessage = 'Domain Controller, or RDG')]
    [String]$LicensingServerFQDN,

    [Parameter(Mandatory = $true, HelpMessage = 'remote.example.com')]
    [String]$RDWebFQDN,

    [Parameter(Mandatory = $true)]
    [String]$CollectionName,

    [Parameter(Mandatory = $true, HelpMessage = 'CUST-RDG1')]
    [String]$GatewayName,

    [Parameter(Mandatory = $true, HelpMessage = 'C:\temp\f2b531849d3e966c.crt')]
    [ValidatePattern('.*\.crt$')]
    [String]$CertificateFullPath,

    [Parameter(Mandatory = $false)]
    [int32]$DisconnectedSessionLimitMin = '300',
    [Parameter(Mandatory = $false)]
    [int32]$IdleSessionLimitMin = '60'
)#End cmdletbinding


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
}#End Try
catch {
    Write-output 'No RDS Servers found. This is not an issue if this is a new deployment'
}#End Catch

#region Add-RDSServersToFarm
Write-Output "Adding RDS Servers $($RDSServersFQDN) to the farm"

try {
    Remove-Variable rdssrv -ErrorAction SilentlyContinue
    foreach ($RdsSrv in $RDSServersFQDN) {
        if ($CurrentRDSServers -match $RdsSrv) {
            Write-Output "Server $($RdsSrv) is already in the farm. It will be skipped."
        }#End if
        else {
            Add-RDServer -Server $RdsSrv -Role RDS-RD-SERVER -ConnectionBroker $RdgFQDN -ErrorAction Stop
        }#End Else
    }#End foreach
}#End Try
catch {
    Write-Output "Could not add server $($RDSSrv) to the farm.
            Make sure that the name is spelled correctly
            Make sure the RDG name is correct
            Make sure that the server is not in the farm already"
    Break
}#End Catch
#endregion

#region Set-RDSLicensing
Write-Output "Configuring RD Licensing. $($LicensingServerFQDN) will be the licensing server for the gateway $($RdgFQDN)"

if ($CurrentRDSServers -match $LicensingServerFQDN) {
    Write-Output "Server $($LicensingServerFQDN) is already in the farm. It will be skipped."
}#End if
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
        Write-output "Could not add the server $($LicensingServerFQDN) to the farm."
        break
    }
}#End Else

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
Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\Default Web Site" -Value @{enabled = "true"; destination = "https://$RDWebFQDN/rdweb"; exactDestination = "true"; httpResponseStatus = "Permanent" }
#endregion Configure-DefaultSiteRedirection

#Region Add-RDGtoGroups
#This should not be necessary, but it's done just in case the gateway didn't get added to that group
Add-ADGroupMember -Identity 'RAS and IAS servers' -Members "$($GatewayName)$"
#region Add-RDGtoGroups
