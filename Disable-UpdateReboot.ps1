<#

.SYNOPSIS
    Disable Windows update auto reboot

.DESCRIPTION
    This script disables and sets permissions on registry key and task files to prevent the system
    from re-enabling reboot task

.NOTES
    Script will have to be run again after feature updates. This is because windows wipes the windows directory during it's update process.
    This script was created by SCUR0

.LINK
    https://github.com/SCUR0/PowerShell-Scripts

#>

[cmdletbinding()]
param ()

If (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).`
      IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){
        Write-Error "Admin permissions are required to run this script. Please open powershell as administrator."
        pause
        break
}

#Variables
$Errors=$null
$RebootReg="Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\UpdateOrchestrator\Reboot"
$RebootTask="$env:WinDir\System32\Tasks\Microsoft\Windows\UpdateOrchestrator\Reboot"


#attempt to set task to disabled on older version

Write-Verbose "Attepting to set task to disabled via task scheduler." -Verbose
Get-ScheduledTask -TaskName Reboot -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null


#SET ACL for registry key
#grant user access via .net
Write-Verbose "Modifying registry keys." -Verbose
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(`
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\UpdateOrchestrator\Reboot",`
    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
$acl = $key.GetAccessControl()
if ($null -eq $acl){
    Write-Warning "Error encountered while trying to modify registry key for reboot"
    $Errors=$true
}else{
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("BUILTIN\Administrators","FullControl","Allow")
    $acl.ResetAccessRule($rule)
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("System","ReadKey","Allow")
    $acl.SetAccessRule($rule)
    $key.SetAccessControl($acl)

    #remove inheritance
    $acl = Get-Acl -Path $RebootReg
    $acl.SetAccessRuleProtection($true,$false)
    $acl | Set-Acl
}

#SET ACL for task file
#Change owner
Write-Verbose "Modifying scheduled task files." -Verbose
$acl = Get-ACL -Path $RebootTask -ErrorAction SilentlyContinue
if ($null -eq $acl){
    Write-Warning "Error encountered while trying to modify task file for reboot"
    $Errors=$true
}else{
    $Group = New-Object System.Security.Principal.NTAccount("BUILTIN\Administrators")
    $acl.SetOwner($Group)
    Set-Acl -Path $RebootTask -AclObject $acl

    #remove inheritance 
    $acl = Get-Acl -Path $RebootTask
    $acl.SetAccessRuleProtection($true,$false)
    $acl | Set-Acl -ErrorAction Stop

    #remove and set permissions
    $acl = Get-ACL -Path $RebootTask
    $acl.Access | %{$acl.RemoveAccessRule($_)} |Out-Null
    $ar = New-Object  system.security.accesscontrol.filesystemaccessrule("$env:Username","FullControl","Allow")
    $acl.SetAccessRule($ar)
    $ar = New-Object  system.security.accesscontrol.filesystemaccessrule("System","ReadAndExecute","Allow")
    $acl.SetAccessRule($ar)
    Set-Acl -Path $RebootTask -AclObject $acl
}
if (!$Errors){
    Write-Verbose "Script complete." -Verbose
    Write-Warning "Script will need to be run again after a feature (new windows build) update."
}else{
    Write-Output "Errors were encountered while attempting to make changes. The script was not successful."
}
