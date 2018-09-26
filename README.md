# PowerShell-Scripts
Personal collection of powershell scripts used at home

- Disable-UpdateReboot.ps1

 A Powershell script that will adjust the reboot task permissions in update orchestrator to prevent windows from automatically rebooting. The script will perminently disable auto reboot until the next feature update. This is due to how windows wipes the windows directory during updates.

- Tasks/Export-VMs.ps1

 Simple script that exports a copy of all VMs to a backup directory.

- Tasks/Get-FileHistoryStatus.ps1

 Filehistory on windows 8-10 is known for randomly failing to run. I enjoy the feature of FileHistory tracking of files so I created a script that will email you if it has not ran in the specified time range.

- Tasks/Set-NTFSCompression.ps1

 Compress specified folders using NTFS compression. Very useful for saving space in areas that don't have high IO. I was unable to find any negative performance impact.

- Tasks/Update-PlexService.ps1

 Update plex if you are running it as a service.
