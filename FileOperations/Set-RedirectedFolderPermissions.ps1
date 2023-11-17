<#
This Script applies Redirected Folder permissions to a folder
https://social.technet.microsoft.com/Forums/office/en-US/51b7a268-4f46-4adf-b226-763236cdd491/icacls-permissions-set-but-dont-apply-without-change-something-in-the-acl-by-hand?forum=winservergen

Andy Morales
#>

$FolderDirectory = 'D:\RedirectedFolders'

#Clear all Explicit Permissions on the folder
ICACLS ("$FolderDirectory") /reset

#Add CREATOR OWNER permission
ICACLS ("$FolderDirectory") /grant ("CREATOR OWNER" + ':(OI)(CI)(IO)F')

#Add SYSTEM permission
ICACLS ("$FolderDirectory") /grant ("SYSTEM" + ':(OI)(CI)F')

#Give Domain Admins Full Control
ICACLS ("$FolderDirectory") /grant ("Domain Admins" + ':(OI)(CI)F')

#Apply Create Folder/Append Data, List Folder/Read Data, Read Attributes, Traverse Folder/Execute File, Read permissions to this folder only. Synchronize is required in order for the permissions to work
ICACLS ("$FolderDirectory") /grant ("Domain Users" + ':(AD,REA,RA,X,RC,RD,S)')

#Disable Inheritance on the Folder. This is done last to avoid permission errors.
ICACLS ("$FolderDirectory") /inheritance:r
