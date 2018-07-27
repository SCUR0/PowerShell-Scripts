<#

.SYNOPSIS
    Disable Windows update auto reboot

.DESCRIPTION
    This script disables and sets permissions on registry key and task files to prevent the system
    from re-enabling reboot task

.NOTES
    Requires admin permissions in order to set registry keys and permissions.
    Created by SCUR0

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
$RebootReg="Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\UpdateOrchestrator\Reboot"
$RebootTask="$env:WinDir\System32\Tasks\Microsoft\Windows\UpdateOrchestrator\Reboot"


#Disable task
try{
    Get-ScheduledTask -TaskName Reboot -ErrorAction Stop | Disable-ScheduledTask -ErrorAction Stop | Out-Null
}catch{
    Write-Warning "An error occurred while trying to set task to disabled. Verify system still has full permissions."
    Write-Error $Error[0]
    pause
    break
}

#SET ACL for registry key
#grant user access via .net
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(`
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\UpdateOrchestrator\Reboot",`
    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
$acl = $key.GetAccessControl()
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:Username","FullControl","Allow")
$acl.ResetAccessRule($rule)
$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("System","ReadKey","Allow")
$acl.SetAccessRule($rule)
$key.SetAccessControl($acl)

#remove inheritance
$acl = Get-Acl -Path $RebootReg
$acl.SetAccessRuleProtection($true,$false)
$acl | Set-Acl

#SET ACL for task file
#Change owner
$acl = Get-ACL -Path $RebootTask
$Group = New-Object System.Security.Principal.NTAccount("$env:Username")
$acl.SetOwner($Group)
Set-Acl -Path $RebootTask -AclObject $acl

#remove and set permissions
$acl = Get-ACL -Path $RebootTask
$acl.Access | %{$acl.RemoveAccessRule($_)} |Out-Null
$ar = New-Object  system.security.accesscontrol.filesystemaccessrule("$env:Username","FullControl","Allow")
$acl.SetAccessRule($ar)
$ar = New-Object  system.security.accesscontrol.filesystemaccessrule("System","ReadAndExecute","Allow")
$acl.SetAccessRule($ar)
Set-Acl -Path $RebootTask -AclObject $acl
