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
        #Verify update task isn't still running
        write-output "Connecting to $ComputerName"
        if ((Get-ScheduledTask "PSWindowsUpdate" -CimSession $ComputerName).State -ne "Running"){
            #start remote powershell session to the computer
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
                $Script = [scriptblock]::Create("Get-wulist -NotCategory $UpdateCats -NotTitle 'Feature|Preview' -MicrosoftUpdate -verbose")
			    $updates = invoke-command -session $session -scriptblock $Script
			    $UpdateNumber = ($updates | Measure-Object).Count
                if (($UpdateNumber -eq 0) -and ($Restart)){
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
					    $Script = "Install-WindowsUpdate -NotCategory $UpdateCats -NotTitle 'Feature|Preview' -AcceptAll -MicrosoftUpdate -AutoReboot | "
				    }else{
					    $Script = "Install-WindowsUpdate -NotCategory $UpdateCats -NotTitle 'Feature|Preview' -AcceptAll -MicrosoftUpdate -IgnoreReboot | "
				    }
                    $Script = [scriptblock]::Create($Script + ({Out-File $env:ALLUSERSPROFILE\AdminScripts\PSWindowsUpdate.log}).ToString())

                    Write-Verbose "Initiating Windows Updates" -Verbose

                    $OldTask = Get-ScheduledTask "PSWindowsUpdate" -CimSession $ComputerName -ErrorAction SilentlyContinue
                    if ($OldTask){
                        $OldTask | Unregister-ScheduledTask -Confirm:$false
                    }

                    $action=New-ScheduledTaskAction -Execute powershell.exe -Argument "-command `"$Script`""
                    $StartTime=Invoke-Command -session $session -ScriptBlock {(get-date).AddSeconds(3)}
                    $trigger=New-ScheduledTaskTrigger -Once -At $StartTime
                    $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable
                    $principal = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest


                    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PSWindowsUpdate" -Description "Windows Updates" `
                        -Settings $settings -Principal $principal -Force -Verbose:$false -CimSession $ComputerName | Out-Null

                    #Pause to let task start
                    Start-Sleep -Seconds 5

                    #check if running else force to run
                    $TaskInfo = Get-ScheduledTaskInfo "PSWindowsUpdate" -CimSession $ComputerName
                    if ($TaskInfo.LastTaskResult -eq 267011){
                        Start-ScheduledTask "PSWindowsUpdate" -CimSession $ComputerName
                        Start-Sleep -Seconds 5
                    }

				    #Show update status until the amount of installed updates equals the same as the amount of updates available
                    $InstalledNumber = $DownloadNumber = 0
				    do {
					    if (Test-Path \\$ComputerName\c$\ProgramData\AdminScripts\PSWindowsUpdate.log){
						    $UpdateLog = Get-Content \\$ComputerName\c$\ProgramData\AdminScripts\PSWindowsUpdate.log
						    if (!$UpdateLog){
							    $ProgStatus = "Connecting to update servers"
						    }else{
                                [int]$DownloadNumber = ([regex]::Matches($UpdateLog, "Downloaded" )).count
							    if ($DownloadNumber -ne $UpdateNumber){
                                    $ProgStatus = "Downloading $((($UpdateLog[($DownloadNumber + 3)]) -replace '\s+', ' ').split(" ",6)[5] -join ' ')"
                                }else{
                                    $ProgStatus = (($UpdateLog[($InstalledNumber + 3)]) -replace '\s+', ' ').split(" ",6)[3,5] -join ' '
                                }
                                [int]$InstalledNumber = ([regex]::Matches($UpdateLog, "Installed|Failed" )).count
						    }
                            if ($InstalledNumber -lt $UpdateNumber){
                                $DisplayNumber = $InstalledNumber + 1
                            }else{
                                $DisplayNumber = $InstalledNumber
                            }
						    Write-Progress -Activity "Installing Updates ($DisplayNumber of $UpdateNumber)" `
							    -Status $ProgStatus `
							    -PercentComplete ([Math]::Round($InstalledNumber/$UpdateNumber*100)) `
                                -Id 1
					    }
                        $TaskState = Get-ScheduledTask "PSWindowsUpdate" -CimSession $ComputerName
                        $TaskInfo = Get-ScheduledTaskInfo "PSWindowsUpdate" -CimSession $ComputerName
                        $PingState = Test-Connection $ComputerName -Count 2 -Quiet
					    start-sleep -Seconds 1
				    }until ((!($PingState)) -or ($TaskState.State -ne "Running"))
                
                    if (!($PingState)){
                        Write-Error "Connection lost to $ComputerName"
                        $host.ui.RawUI.WindowTitle = "$ComputerName - Error"ù
                        Exit
                    }
				
				    Write-Progress -Activity "Installing Updates" -Completed -Id 1
                    if ($TaskState.State -ne "Running" -and ($TaskInfo.LastTaskResult -eq 0 -or $TaskInfo.LastTaskResult -eq 267014 -or $TaskInfo.LastTaskResult -eq 259)){  
				        Write-Output "Update Task Ended - $(get-date)"
				        $host.ui.RawUI.WindowTitle = "$ComputerName - Task Completed"ù
				        if ($Restart){
                            if ($UpdateNumber -eq 1){
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
                        $host.ui.RawUI.WindowTitle = "$ComputerName - Error"
                        Write-Warning "Task completed with an error."
                    }
			    }else{
				    $host.ui.RawUI.WindowTitle = "$ComputerName - Up to Date"ù
			    }
		    }
        }else{
            $host.ui.RawUI.WindowTitle = "$ComputerName - Updates Already Running"
            Write-Warning "Update task is still running on $ComputerName"
        }
    }else{
        Write-Error "Unable to connect to $ComputerName"
    }
}
