<#
.SYNOPSIS
Archives old user data. 

.DESCRIPTION
Script checks for user data and then uses robocopy to move data to neverland network share.

.PARAMETER username
Used as the identifier for which account requires data to be searched for and archived.

.EXAMPLE
archive-user-files.ps1 jsmith

This would archive files for John Smith
#>

[cmdletbinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string] $username
    )

#tests for admin rights

function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

if (!(Test-Administrator)){
    write-error "You do not have administrative rights!"
    return
}

#Variables
$ErrorActionPreference = "inquire"
$date = Get-Date
$ADuser= Get-ADUser $username
$totalp = 0
$robostatus= @()


#Config
$AConfig = @{
    Archive = "\\do-fs-03\Neverland$\_Archive_User_Data\$($date.year)\$username\"
	
	#this group is to search multiple locations for user directories with username or full name
	#this will need to be edited to match local structure of user directories
    networkpaths = @{
        personal = "\\fs-03\users$\$username"
        common = "\\fs-03\staff$\_Common\_Staff_Folders\$($ADuser.name)"
        never_personal = "\\fs-03\Never$\_Staff_Folders\$username"
        never_shared = "\\fs-03\Never$\_common\_Staff_Folders\$($ADuser.name)"
        webfiles = "\\fs-03\staff$\_WebFiles\Users\$username"
    }
}

if ($aduser.enabled -eq "True"){
    Write-warning "User account is still enabled!"
    $continue = Read-host "Do you want to continue? [Y] or [N]"
    if ($continue -eq "n"){
		return
	}
}

if (!$aduser){
    Write-Error "This script requires an AD user account to run."
    exit
}

#main script
write-warning "${username}'s files are being archived. Do NOT close script. A prompt will tell you when it is complete."
new-item $($AConfig.Archive) -type directory -ErrorAction SilentlyContinue | Out-Null

foreach ($networkpath in $AConfig.networkpaths.GetEnumerator()){
    $stat = New-Object System.Object
    $percent = "Percent moved: "+([decimal]::round(($totalp / $AConfig.networkpaths.count)*100)) + "%"
	
    #checks to see if folder exists. if it does not it skips to next path.
    if (Test-Path $networkpath.Value){
        Write-verbose "Files found in $($networkpath.value). Archiving..." -verbose
        $destination = [string]$AConfig.Archive + "$($networkpath.Name)"
        $source = [string]"$($networkpath.Value)"
        Write-Progress -activity "Archiving folders" -status $percent -PercentComplete (($totalp / $AConfig.networkpaths.count)  * 100)
        robocopy $source $destination /Move /E /W:1 /R:6 /ZB /IS /NFL /NP /TEE
        $totalp++
    } 
    
    if (test-path $networkpath.Value){
        $stat | Add-Member -MemberType NoteProperty -Name "Error location" -Value $($networkpath.Value)
        $robostatus += $stat
    }  
}
if ($robostatus){
    Write-Progress -activity "Archiving folders" -Completed 
    Write-warning "Problems were found during archive. Check these folders and log:"
    Write-output ($robostatus | Format-Table | Out-String)
    pause
} else {
	write-verbose "${username}'s files have been archived."
}
Write-Progress -activity "Archiving folders" -Completed 

