<#
.SYNOPSIS
    Install windows updates via powershell remotely

.DESCRIPTION
	Installs PSWindows update module, checks for updates and installs. Used for remote installs.

.PARAMETER ComputerName
	Name of computers to run remote updates on. Supports arrays.

.PARAMETER Restart
	Automatically reboot after updates are installed.

.PARAMETER Drivers
	Check for driver updates along with windows updates.
#>

[CmdletBinding()]
param (
    [parameter(Mandatory=$true,Position=1)]
    $ComputerName,
    [switch]$Restart,
    [switch]$Drivers
)

function Load-PSWindowsUpdate {
    Try {
		import-module PSWindowsUpdate -ErrorAction Stop
	}catch{
		Write-Warning "PSWindowsUpdate not found. Installing module"
					
		if (([System.Environment]::OSVersion.Version).Major -ne 10){
			Write-Error "Windows 10 required"
		}else{
			Install-PackageProvider NuGet -Force | Out-Null
			Set-PSRepository PSGallery -InstallationPolicy Trusted | Out-Null
			Install-Module PSWindowsUpdate -force -confirm:$false | Out-Null
		}
	}
}


#Admin check
$user = [Security.Principal.WindowsIdentity]::GetCurrent();
$AdminRole = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
If (!($AdminRole)){
    Write-Error "Script requires to be run as administrator"
    pause
    exit
}


#load PSWindowsUpdate
Load-PSWindowsUpdate

if ($ComputerName.Count -gt 1){
    $ArgList = @(
        "-noexit",
		"-file $PSCommandPath"
    )
    if ($Restart){
        $ArgList += "-Restart"
    }
    foreach ($Computer in $ComputerName){
        #launch each computer in new window for easy tracking
        start-process powershell -ArgumentList ($ArgList + "-ComputerName $Computer")		
    }
}else{
    $host.ui.RawUI.WindowTitle = "$ComputerName"
	if ($Drivers){
		$UpdateCats = "'Feature Packs'"
	}else{
		$UpdateCats = "'Drivers','Feature Packs'"
	}
    If (Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Ignore){        
        #starts up a remote powershell session to the computer
        write-output "Connecting to $ComputerName"
        $session = New-PSSession -ComputerName $ComputerName
		if ($session){
			#Installs PSWindowsUpdate if missing
			invoke-command -session $session -scriptblock ${function:Load-PSWindowsUpdate}

			#Creates AdminScript folder if it does not exist
			invoke-command -session $session -scriptblock {
				if (!(Test-Path $env:ALLUSERSPROFILE\AdminScripts)){
					New-Item $env:ALLUSERSPROFILE\AdminScripts -ItemType Directory | Out-Null
				}else{
					Remove-Item $env:ALLUSERSPROFILE\AdminScripts\PSWindowsUpdate.log -ErrorAction SilentlyContinue
				}
			}
			#retrieves a list of available updates
			write-output "Initiating PSWindowsUpdate on $ComputerName"
            $Script = [scriptblock]::Create("Get-wulist -NotCategory $UpdateCats -MicrosoftUpdate -verbose")
			$updates = invoke-command -session $session -scriptblock $Script
			$updatenumber = ($updates | Measure-Object).Count
            if (($updatenumber -eq 0) -and ($Restart)){
                invoke-command -session $session -scriptblock {
                    If (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"){
                        Write-Output "Pending restart flag found for $env:COMPUTERNAME. Restarting"
                        Restart-Computer -Force -ErrorAction SilentlyContinue
                    }
                }
            }

			#if there are available updates proceed with installing
			if ($updates){

				#remote command to install windows updates, creates a scheduled task on remote computer
				if ($Restart){
					$Script = "Install-WindowsUpdate -NotCategory $UpdateCats -AcceptAll -MicrosoftUpdate -AutoReboot | "
				}else{
					$Script = "Install-WindowsUpdate -NotCategory $UpdateCats -AcceptAll -MicrosoftUpdate -IgnoreReboot | "
				}
                $Script = [scriptblock]::Create($Script + ({Out-File $env:ALLUSERSPROFILE\AdminScripts\PSWindowsUpdate.log}).ToString())

                Write-Verbose "Initiating Windows Updates" -Verbose

                $OldTask = Get-ScheduledTask "PSWindowsUpdate" -CimSession $ComputerName -ErrorAction SilentlyContinue
                if ($OldTask){
                    $OldTask | Unregister-ScheduledTask -Confirm:$false
                }

                $action=New-ScheduledTaskAction -Execute powershell.exe -Argument "-command `"$Script`""
                $StartTime=Invoke-Command -session $session -ScriptBlock {(get-date).AddSeconds(2)}
                $trigger=New-ScheduledTaskTrigger -Once -At $StartTime
                $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable
                $principal = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest

                #$settings=New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Verbose:$false

                Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PSWindowsUpdate" -Description "Windows Updates" `
                    -Settings $settings -Principal $principal -Force -Verbose:$false -CimSession $ComputerName | Out-Null

				#Invoke-WUjob -ComputerName $ComputerName -Script $Script -Confirm:$false -RunNow -Credential $Credential -ErrorAction SilentlyContinue#>
				#Show update status until the amount of installed updates equals the same as the amount of updates available
                $installednumber = $downloadnumber = 0
				do {
					if (Test-Path \\$ComputerName\c$\ProgramData\AdminScripts\PSWindowsUpdate.log){
						$UpdateLog = Get-Content \\$ComputerName\c$\ProgramData\AdminScripts\PSWindowsUpdate.log
						if (!$UpdateLog){
							$ProgStatus = "Connecting to update servers"
						}else{
							if (($UpdateLog[-1] -replace '\s+', ' ').split(" ")[2] -eq "Downloaded"){
                                [int]$downloadnumber = ([regex]::Matches($UpdateLog, "Downloaded" )).count
                                $ProgStatus = "Downloading $((($UpdateLog[($downloadnumber + 3)]) -replace '\s+', ' ').split(" ",6)[5] -join ' ')"
                            }else{
                                $ProgStatus = (($UpdateLog[($installednumber + 3)]) -replace '\s+', ' ').split(" ",6)[3,5] -join ' '
                            }
                            [int]$installednumber = ([regex]::Matches($UpdateLog, "Installed|Failed" )).count
						}
						Write-Progress -Activity "Installing Updates ($($installednumber + 1) of $updatenumber)" `
							-Status $ProgStatus `
							-PercentComplete ([Math]::Round($installednumber/$updatenumber*100));
					}
					start-sleep -Seconds 1
				}until (($installednumber -eq $updatenumber) -or (!(Test-Connection $ComputerName -Count 3 -Quiet)) `
                       -or ((Get-ScheduledTask "PSWindowsUpdate" -CimSession $ComputerName).State -ne "Running"))
                
                if (!(Test-Connection $ComputerName -Count 2 -Quiet)){
                    Write-Error "Connection lost to $ComputerName"
                    $host.ui.RawUI.WindowTitle = “$ComputerName Error”
                    Exit
                }
				
				Write-Progress -Activity "Installing Updates" -Completed
                $EndTask = Get-ScheduledTaskInfo "PSWindowsUpdate" -CimSession $ComputerName
                if ($EndTask.LastRunTime -ne "11/29/1999 11:00:00 PM" -and $EndTask.LastTaskResult -eq 0){
				    Write-Host "Updates installed - $(get-date)" -ForegroundColor Green
				    $host.ui.RawUI.WindowTitle = “$ComputerName updates completed”
				    if ($Restart){
                        if ($updatenumber -eq 1){
                            #Antivirus updates sometimes occur on second run and doesn't reboot afterwards
                            invoke-command -session $session -scriptblock {
                                If (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"){
                                    Restart-Computer -Force -ErrorAction SilentlyContinue
                                }
                            }
                        }
					
                        Write-Output "If updates required restart, the computer will restart shortly"
				    }
                }else{
                    Write-Warning "PSUpdate task did not run correctly. Verify time is correct on $ComputerName"
                }
			}else{
				$host.ui.RawUI.WindowTitle = “$ComputerName up to date”
			}
		}
    }else{
        Write-Error "Unable to connect to $ComputerName"
    }
}