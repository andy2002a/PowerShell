$Form1 = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.Button]$SearchLocked_bttn = $null
[System.Windows.Forms.Button]$UnlockUsr_bttn = $null
[System.Windows.Forms.Button]$Cancel_bttn = $null
[System.Windows.Forms.DataGridView]$LockedUsr_DataGrid = $null
function InitializeComponent
{
#Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName 'Unlock-ADuser.resources.psd1' -BindingVariable resources
$SearchLocked_bttn = (New-Object -TypeName System.Windows.Forms.Button)
$UnlockUsr_bttn = (New-Object -TypeName System.Windows.Forms.Button)
$Cancel_bttn = (New-Object -TypeName System.Windows.Forms.Button)
$LockedUsr_DataGrid = (New-Object -TypeName System.Windows.Forms.DataGridView)
([System.ComponentModel.ISupportInitialize]$LockedUsr_DataGrid).BeginInit()
$Form1.SuspendLayout()
#
#SearchLocked_bttn
#
$SearchLocked_bttn.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]12))
$SearchLocked_bttn.Name = [System.String]'SearchLocked_bttn'
$SearchLocked_bttn.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]534,[System.Int32]34))
$SearchLocked_bttn.TabIndex = [System.Int32]0
$SearchLocked_bttn.Text = [System.String]'Search for Locked Users'
$SearchLocked_bttn.UseCompatibleTextRendering = $true
$SearchLocked_bttn.UseVisualStyleBackColor = $true
$SearchLocked_bttn.add_Click($SearchLocked_bttn_Click)
#
#UnlockUsr_bttn
#
$UnlockUsr_bttn.Enabled = $false
$UnlockUsr_bttn.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]215))
$UnlockUsr_bttn.Name = [System.String]'UnlockUsr_bttn'
$UnlockUsr_bttn.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]202,[System.Int32]34))
$UnlockUsr_bttn.TabIndex = [System.Int32]1
$UnlockUsr_bttn.Text = [System.String]'Unlock Selected User'
$UnlockUsr_bttn.UseCompatibleTextRendering = $true
$UnlockUsr_bttn.UseVisualStyleBackColor = $true
$UnlockUsr_bttn.add_Click($UnlockUsr_bttn_Click)
#
#Cancel_bttn
#
$Cancel_bttn.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]344,[System.Int32]215))
$Cancel_bttn.Name = [System.String]'Cancel_bttn'
$Cancel_bttn.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]202,[System.Int32]34))
$Cancel_bttn.TabIndex = [System.Int32]2
$Cancel_bttn.Text = [System.String]'Cancel'
$Cancel_bttn.UseCompatibleTextRendering = $true
$Cancel_bttn.UseVisualStyleBackColor = $true
$Cancel_bttn.add_Click($Cancel_bttn_Click)
#
#LockedUsr_DataGrid
#
$LockedUsr_DataGrid.AllowUserToAddRows = $false
$LockedUsr_DataGrid.AllowUserToDeleteRows = $false
$LockedUsr_DataGrid.AllowUserToOrderColumns = $true
$LockedUsr_DataGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
$LockedUsr_DataGrid.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]52))
$LockedUsr_DataGrid.Name = [System.String]'LockedUsr_DataGrid'
$LockedUsr_DataGrid.ReadOnly = $true
$LockedUsr_DataGrid.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]534,[System.Int32]150))
$LockedUsr_DataGrid.TabIndex = [System.Int32]3
#
#Form1
#
$Form1.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]558,[System.Int32]261))
$Form1.Controls.Add($LockedUsr_DataGrid)
$Form1.Controls.Add($Cancel_bttn)
$Form1.Controls.Add($UnlockUsr_bttn)
$Form1.Controls.Add($SearchLocked_bttn)
$Form1.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form1.Icon = ([System.Drawing.Icon]$resources.'$this.Icon')
$Form1.MaximizeBox = $false
$Form1.Text = [System.String]'Unlock AD Accounts'
$Form1.add_Load($Form1_Load)
([System.ComponentModel.ISupportInitialize]$LockedUsr_DataGrid).EndInit()
$Form1.ResumeLayout($false)
Add-Member -InputObject $Form1 -Name base -Value $base -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name SearchLocked_bttn -Value $SearchLocked_bttn -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name UnlockUsr_bttn -Value $UnlockUsr_bttn -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name Cancel_bttn -Value $Cancel_bttn -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name LockedUsr_DataGrid -Value $LockedUsr_DataGrid -MemberType NoteProperty
}
. InitializeComponent
