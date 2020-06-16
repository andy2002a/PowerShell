#This checks the output of the Test-RegistryValue function
#Andy Morales

#Directory of the script
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path

#Load the function
. "$script_dir\Test-RegistryValue.ps1"


$TestData = @(
    @{
        'TestName'       = 'Key that Exists';
        'RegPath'        = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'ProgramFilesDir';
        'ExpectedResult' = $true
    },
    @{
        'TestName'       = 'Key that Exists (Long Path)';
        'RegPath'        = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'ProgramFilesDir';
        'ExpectedResult' = $true
    },
    @{
        'TestName'       = 'Key that does not exist';
        'RegPath'        = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'NotExists';
        'ExpectedResult' = $false
    },
    @{
        'TestName'       = 'Key that does not exist (Long Path)';
        'RegPath'        = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'NotExists';
        'ExpectedResult' = $false
    },
    #Check for Values
    @{
        'TestName'       = 'Value that matches';
        'RegPath'        = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'ProgramFilesDir';
        'RegValueData'   = 'C:\Program Files';
        'ExpectedResult' = $true
    },
    @{
        'TestName'       = 'Value that matches (long path)';
        'RegPath'        = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'ProgramFilesDir';
        'RegValueData'   = 'C:\Program Files';
        'ExpectedResult' = $true
    },
    @{
        'TestName'       = 'Value that does not match';
        'RegPath'        = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'ProgramFilesDir';
        'RegValueData'   = 'BadValue';
        'ExpectedResult' = $false
    },
    @{
        'TestName'       = 'Value that does not match (long path)';
        'RegPath'        = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion';
        'RegName'        = 'ProgramFilesDir';
        'RegValueData'   = 'BadValue';
        'ExpectedResult' = $false
    }
)

Describe 'Test-RegistryValue Function' {

    It "<TestName>" -TestCases $TestData {
        param ($RegPath, $RegName, $RegValueData, $ExpectedResult)
        Test-RegistryValue -Path $RegPath -Name $RegName -ValueData $RegValueData | Should -Be $ExpectedResult
    }

    Context 'Check for Null Key' {
        Mock Get-ItemProperty {
            return $null
        }

        It 'Test if finding a $null key returns false' {
            Test-RegistryValue -Path 'HKEY_LOCAL_MACHINE\FakePath' -Name 'FakeName' | should -Be $false
        }

    }

}