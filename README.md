# PowerShell-Scripts
Personal collection of powershell scripts used at home. These were designed to run on Powershell for Windows.

***

### Disable-UpdateReboot.ps1

  A Powershell script that will adjust the reboot task permissions in update orchestrator to prevent windows from automatically rebooting. The script will perminently disable auto reboot until the next feature update. This is due to how windows wipes the windows directory during updates.
  
  Changes have been made for 1809.

## Tasks

### Export-VMs.ps1

  Simple script that exports a copy of all VMs to a backup directory.

### Check-FileHistoryStatus.ps1

  Filehistory on windows 8-10 is known for randomly failing to run. I enjoy the feature of FileHistory tracking of files so I created a script that will email you if it has not ran in the specified time range.

### Get-PendingRestarts
  
  Both scripts are needed if you want the process to be hidden from the user except for prompts. Both scripts **need to be placed in** `$env:APPDATA\AdminScripts\`. Create a group policy to create a scheduled task to run `Get-PendingRestartSilent.vbs` throughout the day. **Run as script as user not system.**

### Set-NTFSCompression.ps1
  
  Compress specified folders using NTFS compression. Very useful for saving space in areas that don't have high IO. I was unable to find any negative performance impact.

### Update-PlexService.ps1
  
  Update plex if you are running it as a service.
  
## Tools
  
### Batch-UFWConfig.ps1
  
  This script takes a text file of IPs or IP subnets and converts it to be used with UFW config files. Useful for IP Geo firewall rules. You can copy paste output into config file to add rules.

### Compact-VMs.ps1

This script is used to automatically compact all of your dynamic virtual disks on all of your VMs. It will shut down VM if running, compact, and then boot VM if it was running before.

### Disable-NTFSCompression.ps1
  
  Recusive NTFS uncompression for a directory or more.

### Get-CPUProcessLoad.ps1

I use this script to get remote CPU load with top processes of remote machines. Can also be used local.

### Get-Logins.ps1

Audit RDP and SMB logins. Login auditing will need to be enabled in local policy.

### Toggle-Service.ps1

A simple script for toggleing a service (start/stop). Remote ComputerName supported.

## Active Directory

These use a config hash that needs to be modified to match local enviroment. These were designed for my work center.

### Remove-UserHybrid.ps1

Used for account closure in a hyprid office 365 enviroment. No files, accounts, or mailboxes are deleted, instead they are moved to archive locations. Archive-UserFiles.ps1 and ShareOnlineEmailAccount.ps1 are included as part of the script

### Archive-UserFiles.ps1

Searches multiple network locations for user files and then moves via robocopy.


### ShareOnlineEmailAccount.ps1

Set a mailbox to be shared to another via office 365.
