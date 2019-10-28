@{
        Root = 'c:\Users\AMorales\OneDrive - Western Digitech\Windows\Script\Active Directory\Unlock-ADUser\Unlock-ADuser.ps1'
        OutputPath = 'c:\Users\AMorales\OneDrive - Western Digitech\Windows\Script\Active Directory\Unlock-ADUser\out'
        Package = @{
            Enabled = $true
            Obfuscate = $true
            HideConsoleWindow = $true
            DotNetVersion = 'v4.6.2'
            FileVersion = '1.0.0'
            FileDescription = ''
            ProductName = ''
            ProductVersion = ''
            Copyright = ''
            RequireElevation = $false
            ApplicationIconPath = 'c:\Users\AMorales\OneDrive - Western Digitech\Windows\Script\Active Directory\Unlock-ADUser\shell32_269.ico'
            PackageType = 'Console'
        }
        Bundle = @{
            Enabled = $true
            Modules = $true
            # IgnoredModules = @()
        }
    }
