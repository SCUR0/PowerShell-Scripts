<#
.SYNOPSIS
    Removes uneeded windows 10 apps

.DESCRIPTION
	Removes both installed apps and provisioned packages if they exists.
#>

[CmdletBinding()]
Param()

# Black list of appx packages to uninstall
$BlackListedApps = @(
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
$AppArrayList = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName

# Loop through the list of appx packages
foreach ($App in $AppArrayList) {
    # If application name is in appx package black list, remove AppxPackage and AppxProvisioningPackage
    if ($App -in $BlackListedApps) {
        # Gather package names
        $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $App } | Select-Object -ExpandProperty PackageName -First 1

        # Attempt to remove AppxProvisioningPackage
        if ($AppProvisioningPackageName -ne $null) {
            try {
                Write-Verbose  "Removing AppxProvisioningPackage: $($AppProvisioningPackageName)" -Verbose
                Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -ErrorAction Stop | Out-Null
            }
            catch [System.Exception] {
                Write-Error  "Removing AppxProvisioningPackage '$($AppProvisioningPackageName)' failed: $($_.Exception.Message)"
            }
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
        $AppPackageFullName = Get-AppxPackage -Name $App -AllUsers | Select-Object -ExpandProperty PackageFullName -First 1
        if ($AppPackageFullName){
            try {
                Write-Verbose  "Removing AppxPackage: $App" -Verbose
                Remove-AppxPackage -Package $AppPackageFullName -AllUsers -ErrorAction Stop | Out-Null
            }
            catch [System.Exception] {
                Write-Error  "Removing AppxPackage $App failed: $($_.Exception.Message)"
            }
        }
    }
}
