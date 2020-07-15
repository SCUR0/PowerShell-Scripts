<#
.SYNOPSIS
    Uninstalls unnecessary default applications

.DESCRIPTION
	Common Microsoft "bloat" is checked for and removed.
	It is recommended to run this during the image process such as an MDT task sequence.
#>
[CmdletBinding()]
Param()

# Black list of appx packages to uninstall
$BlackListedApps = @(
	"king.com.FarmHeroesSaga",
	"king.com.CandyCrushFriends",
    "Microsoft.SkypeApp",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.YourPhone",
    "Microsoft.OneConnect",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameOverlay",
    "Microsoft.Office.OneNote",
    "Microsoft.MixedReality.Portal",
    "Microsoft.Messaging"
    "Microsoft.People",
    "Microsoft.GetHelp",
    "Microsoft.XboxApp",
    "Microsoft.Getstarted",
    "Microsoft.BingWeather",
    "Microsoft.ZuneMusic",
    "Microsoft.WindowsCommunicationsApps" # Mail, Calendar etc
)

$ErrorActionPreference = "continue"


# Remove Provisioned packages
Write-Verbose "Starting AppxProvisioningPackage removal process" -Verbose
$AppArrayList = Get-AppxProvisionedPackage -Online -Verbose:$false | Select-Object -ExpandProperty DisplayName

#Loop through the list of appx packages
foreach ($App in $AppArrayList) {
    #If application name is in appx package black list, remove AppxPackage and AppxProvisioningPackage
    if ($App -in $BlackListedApps) {
        #Gather package names
        $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online -Verbose:$false | Where-Object { $_.DisplayName -like $App } | Select-Object -ExpandProperty PackageName -First 1

        #Attempt to remove AppxProvisioningPackage
        if ($AppProvisioningPackageName -ne $null) {
            Write-Verbose  "Removing AppxProvisioningPackage: $($AppProvisioningPackageName)" -Verbose
            Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -ErrorAction SilentlyContinue | Out-Null
        }
        else {
            Write-Warning  "Unable to locate AppxProvisioningPackage for current app: $($App)"
        }
    }
}
#Remove apps for all users
Write-Verbose "Starting AppxPackage removal process" -Verbose
$AppArrayList = Get-AppxPackage -AllUsers | Select-Object Name
foreach ($App in $AppArrayList.Name) {
    if ($App -in $BlackListedApps) {
        $AppPackageFullName = Get-AppxPackage -Name $App -AllUsers -Verbose:$false | Select-Object -ExpandProperty PackageFullName -First 1
        if ($AppPackageFullName){
            Write-Verbose  "Removing AppxPackage: $App" -Verbose
            Remove-AppxPackage -Package $AppPackageFullName -AllUsers  -Verbose:$false -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

#Remove OneDrive
$OneDrivePath = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
$OneDriveProcess = Get-Process | Where-Object { $_.ProcessName -like '*OneDrive*' }

#remove installer from default registry
Write-Verbose "Removing Onedrive from default registry" -Verbose
REG LOAD HKU\DefUser C:\Users\Default\NTUSER.DAT | Out-Null
REG delete HKEY_USERS\DefUser\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v OneDriveSetup /f 2>&1 | out-null
REG UNLOAD HKU\DefUser | Out-Null

if ($OneDriveProcess){  
    Write-Verbose "Onedrive local install found. Uninstalling" -Verbose  
    
    #remove package
    $OneDriveProcess | Stop-Process -confirm:$false
    .$OneDrivePath /uninstall
}
