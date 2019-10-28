#CMDlet Binding
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 1,
        ParameterSetName = "IndividualUsers")]
    [Alias('SamAccountName')]
    [string[]]$Users,

    [Parameter(Mandatory = $true,
        ParameterSetName = "Allusers")]
    [switch]$Allusers,

    [Parameter(Mandatory = $true,
        Position = 2)]
    [ValidateSet('2010', '2013', '2016', 'O365')]
    [string]$ExchangeVersion,

    [Parameter(Mandatory = $false)]
    [string]$FilePath
)


#Get Domain Name
$DomainShortName = ((Get-WmiObject Win32_ComputerSystem).Domain).Split(".")[0]

#Get UPN suffixes
Get-ADForest | fl *


#Get Error exeption
$Error[0].exception.GetType().fullname

#PScustom object
$CurrentUserAttributes = [PSCustomObject]@{
    SamAccountName    = $user.SamAccountName
    mail              = $user.mail
    userprincipalname = $user.UserPrincipalName
    mailnickname      = $user.mailnickname
    legacyexchangeDN  = $user.legacyexchangeDN
    proxyaddresses    = $UserProxyAddresses
}#End [PSCustomObject]

#Exclude items from array
Where-Object {$Exclusions -NotContains $_.name}

#Read XML
#Get the Name of the GPO from the content of the XML
[XML]$GPOReportXML = Get-Content -path $GPOReportPath.FullName
[string]$GPOBackupName = $GPOReportXML.GPO.Name

#Match array of items
$ToMatch = @('String1', 'String2', 'String3')

Get-ADComputer -Filter * | ? { $ToMatch -contains $_.Name }


#Multiple HTML tables
$a = Get-Process | Select -First 5 | ConvertTo-HTML -Title "Report Prozesse" -PreContent "<h1>Report Process</h1>"
$b = Get-Service | Select -First 5 | ConvertTo-HTML -Title "Report Service" -PreContent "<h1>Report Service</h1>"
$c = Get-WmiObject -class Win32_OperatingSystem | Select -First 5 | ConvertTo-HTML -Property * -Title "Report OS" -PreContent "<h1>Report OS</h1>"

ConvertTo-HTML -body "$a $b $c" -CSSUri "HtmlReport.css" | Set-Content "HtmlReportOption3.html"

#Select objects from GUI
$item = $folderQueries | Out-GridView -OutputMode Multiple -Title 'Select folder/s:'
