$Form1_Load = {
}
function Search-LockedUsers {
    try {
        Import-Module ActiveDirectory -ErrorAction stop

        Try {
            Search-ADAccount -LockedOut
        }
        catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
            #Can't connect to AD
            [System.Windows.Forms.MessageBox]::Show("Could not connect to an Active Directory Server. Make sure that you are on the corporate network")
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Ran into an unknown error searching for Locked Users")
        }
    }
    catch [System.IO.FileNotFoundException] {
        #AD module not found
        [System.Windows.Forms.MessageBox]::Show("AD RSAT Tools not found. Please contact support to have them installed")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("There was an unknown error searching for Locked Accounts")
    }
}

$Cancel_bttn_Click = {
    $form1.hide()
}

$UnlockUsr_bttn_Click = {
    try {
        $LockedUser = [PSCustomObject]@{
            SamAccountName    = ($LockedOutUsers[$LockedUsr_DataGrid.SelectedCells[0].rowindex]).SamAccountName;
            UserPrincipalName = ($LockedOutUsers[$LockedUsr_DataGrid.SelectedCells[0].rowindex]).UserPrincipalName;
            Name              = ($LockedOutUsers[$LockedUsr_DataGrid.SelectedCells[0].rowindex]).Name
        }
        Unlock-ADAccount -Identity $LockedUser.SamAccountName
        [System.Windows.Forms.MessageBox]::Show("User $($LockedUser.Name) has been unlocked")
    }
    catch [Microsoft.ActiveDirectory.Management.ADException] {
        #AD Access Denied most likely
        [System.Windows.Forms.MessageBox]::Show("Could not unlock the account. You might not have permission")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Unknown error occured please contact support.")
    }
}
$SearchLocked_bttn_Click = {
    #Search for locked users using the function.
    #The where object makes sure that $null values don't get stored in the array
    [Array]$AllLockedUsers = @(Search-LockedUsers | Select-Object Name, UserPrincipalName, SamAccountName | where-Object { $_.name -ne $null })

    #create and Array List so that the contents of the AllLockedUsers array can be stored on a DataGrid
    $Script:LockedOutUsers = New-Object System.Collections.ArrayList
    $LockedOutUsers.addRange($AllLockedUsers)
    $LockedUsr_DataGrid.datasource = $LockedOutUsers
    $LockedUsr_DataGrid.AutoResizeColumns( "AllCells")
    $LockedUsr_DataGrid.Refresh()

    if ($AllLockedUsers.count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No Locked users found")
        $UnlockUsr_bttn.Enabled = $false
    }
    else {
        $UnlockUsr_bttn.Enabled = $true
    }
}

Add-Type -AssemblyName "System.Windows.Forms"
. (Join-Path $PSScriptRoot 'Unlock-ADuser.designer.ps1')
$Form1.ShowDialog()