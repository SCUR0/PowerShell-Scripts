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


Function Enable-Privilege {
  param($Privilege)
  $Definition = @'
using System;
using System.Runtime.InteropServices;
public class AdjPriv {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
    ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr rele);
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name,
    ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid {
    public int Count;
    public long Luid;
    public int Attr;
  }
  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege) {
    bool retVal;
    TokPriv1Luid tp;
    IntPtr hproc = new IntPtr(processHandle);
    IntPtr htok = IntPtr.Zero;
    retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
      ref htok);
    tp.Count = 1;
    tp.Luid = 0;
    tp.Attr = SE_PRIVILEGE_ENABLED;
    retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
    retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero,
      IntPtr.Zero);
    return retVal;
  }
}
'@
  $ProcessHandle = (Get-Process -id $pid).Handle
  $type = Add-Type $definition -PassThru
  $type[0]::EnablePrivilege($processHandle, $Privilege)
}

#verify task is created
If (!(test-path $RebootTask)){
    Write-Output "Reboot task has to first be created by windows update in order to disable. Please run script after first cumulative update."
}else{
    do {} until (Enable-Privilege SeTakeOwnershipPrivilege)


    #SET ACL for registry key
    #Set ownership
    Write-Verbose "Modifying registry keys." -Verbose
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(`
        "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\UpdateOrchestrator\Reboot",`
        [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::TakeOwnership)
    $owner = [Security.Principal.NTAccount]'Administrators'
    $acl = $key.GetAccessControl()
    if ($null -eq $acl){
        Write-Warning "Error encountered while trying to modify registry for reboot"
        $Errors=$true
    }else{
        $acl.SetOwner($owner)
        $key.SetAccessControl($acl)

        #Remove system
        $acl = $key.GetAccessControl()
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
        $ar = New-Object  system.security.accesscontrol.filesystemaccessrule("BUILTIN\Administrators","FullControl","Allow")
        $acl.SetAccessRule($ar)
        $ar = New-Object  system.security.accesscontrol.filesystemaccessrule("System","ReadAndExecute","Allow")
        $acl.SetAccessRule($ar)
        Set-Acl -Path $RebootTask -AclObject $acl
    }
    if (!$Errors){
        #attempt to set task to disabled
        Write-Verbose "Attepting to set task to disabled via task scheduler." -Verbose
        Get-ScheduledTask -TaskName Reboot | Disable-ScheduledTask | Out-Null
        Write-Verbose "Script complete." -Verbose
        Write-Warning "Script will need to be run again after a feature (new windows build) update."
    }else{
        Write-Output "Errors were encountered while attempting to make changes. The script was not successful."
    }
}
