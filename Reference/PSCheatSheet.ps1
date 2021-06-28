#CMDlet Binding
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 1,
        ParameterSetName = "IndividualUsers",
        HelpMessage = 'Scripts\Example')]
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

#Get Error exception
$Error[0].exception.GetType().fullname

#Get Computer Domain
$DomainName = (Get-WmiObject Win32_ComputerSystem).Domain

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
Where-Object { $Exclusions -NotContains $_.name }

#Read XML
#Get the Name of the GPO from the content of the XML
[XML]$GPOReportXML = Get-Content -Path $GPOReportPath.FullName
[string]$GPOBackupName = $GPOReportXML.GPO.Name

#Match array of items
$ToMatch = @('String1', 'String2', 'String3')

Get-ADComputer -Filter * | ? { $ToMatch -contains $_.Name }

#Match Wildcards array
#https://stackoverflow.com/questions/41107211/powershell-use-wildcards-when-matching-arrays
$WildCardArray = @("RED-*.htm", "*.yellow", "BLUE!.txt", "*.green", "*.purple")
$SpelledOutArray = @("RED-123.htm", "456.yellow", "BLUE!.txt", "789.green", "purple.102", "orange.abc")

# Turn wildcards into regexes
# First escape all characters that might cause trouble in regexes (leaving out those we care about)
$escaped = $WildcardArray -replace '[ #$()+.[\\^{]', '\$&' # list taken from Regex.Escape
# replace wildcards with their regex equivalents
$regexes = $escaped -replace '\*', '.*' -replace '\?', '.'
# combine them into one regex
$singleRegex = ($regexes | % { '^' + $_ + '$' }) -join '|'

# match against that regex
$SpelledOutArray -notmatch $singleRegex



#Multiple HTML tables
$a = Get-Process | select -First 5 | ConvertTo-Html -Title "Report Prozesse" -PreContent "<h1>Report Process</h1>"
$b = Get-Service | select -First 5 | ConvertTo-Html -Title "Report Service" -PreContent "<h1>Report Service</h1>"
$c = Get-WmiObject -Class Win32_OperatingSystem | select -First 5 | ConvertTo-Html -Property * -Title "Report OS" -PreContent "<h1>Report OS</h1>"

ConvertTo-Html -Body "$a $b $c" -CssUri "HtmlReport.css" | Set-Content "HtmlReportOption3.html"

#Select objects from GUI
$item = $folderQueries | Out-GridView -OutputMode Multiple -Title 'Select folder/s:'

#Open CMD as a GMSA
./psexec -i -u domain\gMSA$ -p ~ notepad.exe

#Invoke Expression from GitHub
Invoke-Expression(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/user/example.ps1')
Invoke-Command -ScriptBlock { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/CompassMSP/PublicScripts/master/ActiveDirectory/Update-krbtgtPassword.ps1') }

#Download file
#USE SINGLE QUOTES!!!
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object System.Net.WebClient).DownloadFile('https://github.com/repo/file.zip', 'C:\temp\file.zip')

Invoke-Command -ScriptBlock { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/CompassMSP/PublicScripts/master/ActiveDirectory/ADPasswordProtection/Install-ADPasswordProtection.ps1'); Install-ADPasswordProtection -StoreFilesInDBFormatLink 'file.zip' -NotificationEmail 'to@ex.com' -SMTPRelay 'relay.com' -FromEmail 'from@ex.com'


#Print error in try/catch
$($_.Exception.Message)
