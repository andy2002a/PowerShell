<#

This script creates migration batches based on CSV input. The CSV should have been created with the Get-MailboxList.ps1 script.

Users will be separated into different CSVs based on that their "MigrationGroup" is. Users with no group will be ignored. Afterward, the CSVs will be passed to the new New-MigrationBatch command.

This script will create the migration batches, but it will not start them! Either do it manually from EAC, or run the commented commands at the bottom.

Andy Morales
#>


#Connect to Office 365 before running script <<<<<<<<<<<<


#region BreakUpCSV
#Get the CSV with all of the users and break it up by group
$AllMailboxUsersCSVPath = "C:\AllMailboxInfo.csv"

#Remove the last part of the original string
$projectFolder = $AllMailboxUsersCSVPath -replace "\\[^\\]*(?:\\)?$"

#CSVs that we generate will be stored here
$NewCSVFolder = "$projectFolder\MigrationBatchCSVs"

#Delete the CSV folder just incase it has old CSVs in it
Remove-Item $NewCSVFolder -Force -Recurse -ErrorAction SilentlyContinue

New-Item $NewCSVFolder -Force -ItemType Directory

$AllMailboxUsers = Import-Csv -Path $AllMailboxUsersCSVPath

$MinGroupNum = ($AllMailboxUsers.MigrationGroup | measure -Minimum).Minimum
$MaxGroupNum = ($AllMailboxUsers.MigrationGroup | measure -Maximum).Maximum

for ($i = $MinGroupNum; $i -le $MaxGroupNum; $i++) {
    $AllMailboxUsers | Where-Object { $_.MigrationGroup -eq $i } | Export-Csv -NoTypeInformation -Path "$NewCSVFolder/MigrationGroup$i.csv" -Force
}
#endregion BreakUpCSV

#region CreateBatchesFromGroups
$AllGroupCSVFiles = Get-ChildItem $NewCSVFolder -Filter *.csv

Foreach ($GroupCSV in $AllGroupCSVFiles) {

    $GroupCSVData = Import-Csv $GroupCSV.FullName

    if ($GroupCSVData -ne $null) {
        $MigrationBatchParams = @{
            #We get the batch group Number by assuming that all users in a CSV are part of the same group.
            Name                     = "Migration Group $($groupcsvdata[0].MigrationGroup)";
            SourceEndpoint           = (Get-MigrationEndpoint).identity;
            CSVData                  = ([System.IO.File]::ReadAllBytes("$($GroupCSV[0].FullName)"));
            AllowUnknownColumnsInCsv = $true
            BadItemLimit             = 100;
            LargeItemLimit           = 100;
            AutoComplete             = $false
            TargetDeliveryDomain     = (Get-AcceptedDomain | Where-Object {$_.DomainName -like '*.mail.onmicrosoft.com'}).DomainName
        }

        New-MigrationBatch @MigrationBatchParams
    }
}
#endregion CreateBatchesFromGroups


#region Startbatch
#The region below works, but it is commented out so that it is not run by acciden

<#

    #List All batches
    Get-migrationBatch

    #Start but do not complete batch
    Start-MigrationBatch -Identity 'Migration Group 100'

    #set the migration batch to complete
    Set-MigrationBatch -Identity 'Migration Group 100' -CompleteAfter (Get-date).AddHours(8)

#>

#endregion Startbatch