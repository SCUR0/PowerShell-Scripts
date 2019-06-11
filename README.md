# PowerShell-Scripts
Personal collection of powershell scripts used at home. These were designed to run on Powershell for Windows.

***

### Disable-UpdateReboot.ps1

  A Powershell script that will adjust the reboot task permissions in update orchestrator to prevent windows from automatically rebooting. The script will perminently disable auto reboot until the next feature update. This is due to how windows wipes the windows directory during updates.
  
  Changes have been made for 1809.

### Tasks/Export-VMs.ps1

  Simple script that exports a copy of all VMs to a backup directory.

### Tasks/Check-FileHistoryStatus.ps1

  Filehistory on windows 8-10 is known for randomly failing to run. I enjoy the feature of FileHistory tracking of files so I created a script that will email you if it has not ran in the specified time range.

### Tasks/Set-NTFSCompression.ps1
  
  Compress specified folders using NTFS compression. Very useful for saving space in areas that don't have high IO. I was unable to find any negative performance impact.

### Tasks/Update-PlexService.ps1
  
  Update plex if you are running it as a service.
  
### Tools/Batch-UFWConfig.ps1
  
  This script takes a text file of IPs or IP subnets and converts it to be used with UFW config files. Useful for IP Geo firewall rules. You can copy paste output into config file to add rules.

### Tools/Compact-VMs.ps1
  This script is used to automatically compact all of your dynamic virtual disks on all of your VMs. It will shut down VM if running, compact, and then boot VM if it was running before.
