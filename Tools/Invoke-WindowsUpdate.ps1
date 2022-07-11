<#
.SYNOPSIS
	Install windows updates via powershell remotely

.DESCRIPTION
	Installs PSWindows update module, checks for updates and installs. Used for remote installs.

.PARAMETER ComputerName
	Name of computers to run remote updates on. Supports arrays.

.PARAMETER Restart
	Automatically reboot after updates are installed.

.PARAMETER WSUS
	Set WSUS as default location to pull updates. Script defaults to Microsoft update servers.

.PARAMETER Drivers
	Check for driver updates along with windows updates.

.PARAMETER DriversOnly
	Check for driver updates only.

.PARAMETER NoFeatures
	Feature updates are ignored. Feature updates include new builds (21H2)

.PARAMETER Credential
	Used to send alternative credentials
#>

[CmdletBinding()]
param (
	$ComputerName,
    [Alias("Reboot")]
	[switch]$Restart,
    [switch]$WSUS,
	[switch]$Drivers,
    [switch]$DriversOnly,
    [switch]$NoFeatures,
	[System.Management.Automation.PSCredential]$Credential
)

function Load-PSWindowsUpdate {
    #Force TLS Verion
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ModuleError = $null
	$NuGet = Get-PackageProvider | where {$_.Name -like 'NuGet'}
    if (!$NuGet){
        Write-Warning "Installing NuGet Package Provider"
        Install-PackageProvider NuGet -Force | Out-Null
		Set-PSRepository PSGallery -InstallationPolicy Trusted | Out-Null
    }
	Try {
		import-module PSWindowsUpdate -ErrorAction Stop
	}catch{
        $ModuleError = $true
		Write-Warning "PSWindowsUpdate not found. Installing module"					
		Install-Module PSWindowsUpdate -force -confirm:$false | Out-Null

	}
    if ($ModuleError -ne $true){
        #check for updates
        Write-Verbose "Checking for module updates" -Verbose
        $CurrentAWSPSModule = ((Get-Module -Name PSWindowsUpdate -ListAvailable).Version | Sort-Object -Descending | Select-Object -First 1).ToString()
        $NewestAWSPSModule = (Find-Module -Name PSWindowsUpdate).Version.ToString()
        if ([System.Version]$CurrentAWSPSModule -lt [System.Version]$NewestAWSPSModule){
            Write-Verbose "Module is out of date. Attempting to update" -verbose
            Update-Module PSWindowsUpdate -force -confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
        
    }
}

#Powershell Version check
if (!($PSVersionTable.PSVersion -ge 5.1)){
	Write-Error "Powershell version 5.1 or greater is required"
    Exit
}

#Admin check
$user = [Security.Principal.WindowsIdentity]::GetCurrent();
$AdminRole = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
If (!($AdminRole)){
	Write-Error "Script requires to be run as administrator"
	pause
	exit
}

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
	if ($Computername){
        $host.ui.RawUI.WindowTitle = "$ComputerName"
    }
	if ((!$ComputerName) -or (Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Ignore)){			
		if ($ComputerName){
            write-output "Connecting to $ComputerName"
        }

		$CimPara = @{
            ComputerName = $ComputerName
            Name = 'PSWinUpdate'
            
        }
		if ($Credential){
			$CimPara.Add('Credential',$Credential)
		}
        if (!$ComputerName){
            $CimPara.Remove('ComputerName')
        }

		Try{
			$CimSession = New-CimSession @CimPara -ErrorAction Stop
		}Catch{
			Write-Error $Error[0]
			exit
		}

        #Verify update task isn't still running
		if ((Get-ScheduledTask "PSWindowsUpdate" -CimSession $CimSession -ErrorAction Ignore).State -ne "Running"){
			#start remote powershell session to the computer
			$PSPara = @{ComputerName = $ComputerName}
			if ($Credential){
				$PSPara.Add("Credential",$Credential)
			}
            
            #Creates AdminScript folder if it does not exist
            $LogSetup = {
                if (!(Test-Path $env:ALLUSERSPROFILE\AdminScripts)){
					New-Item $env:ALLUSERSPROFILE\AdminScripts -ItemType Directory | Out-Null
				}else{
					Remove-Item $env:ALLUSERSPROFILE\AdminScripts\PSWindowsUpdate.log -ErrorAction SilentlyContinue
				}
            }
            
			if ($ComputerName){
                $session = New-PSSession @PSPara
            }
			if ($session -or (!$ComputerName)){
				#Installs PSWindowsUpdate if missing
				if ($ComputerName){
                    Invoke-Command -session $session -ScriptBlock ${function:Load-PSWindowsUpdate}
                    Invoke-Command -session $session -ScriptBlock $LogSetup
                }else{
                    Load-PSWindowsUpdate
                    Invoke-Command -ScriptBlock $LogSetup
                }

				

				#retrieves a list of available updates
                if ($ComputerName){
                    $Name = $ComputerName
                }else{
                    $Name = $env:COMPUTERNAME
                }
				write-output "Initiating PSWindowsUpdate on $Name"
                
                $WUPara = @{
                    NotTitle     = 'Preview'
                    NotCategory  = @('Drivers')
                    IgnoreReboot = $true
                    Verbose      = $true
                }

                #Update Source
                if ($WSUS){
                    $WUPara.Add('WindowsUpdate',$true)
                }else{
                    $WUPara.Add('MicrosoftUpdate',$true)
                }

                #Exclusions
                if ($Drivers -or $DriversOnly){
                    $WUPara.Remove('NotCategory')
                    if ($DriversOnly){
                        $WUPara.Category = 'Drivers'
                    }
	            }
                if ($NoFeatures){
                    $WUPara.NotCategory += 'Feature Packs'
                }
                ##################          Pending Restart Script Block          ##################
                $GetPendingRestart = {
					If (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"){
						Write-Output "Pending restart flag found for $env:COMPUTERNAME. Restarting"
						Restart-Computer -Force -ErrorAction SilentlyContinue
					}
				}

				if ($ComputerName){
                    $updates = Invoke-Command -session $session -ScriptBlock {$a=$args[0];Get-WUList @a} -ArgumentList $WUPara
                }else{
                    $updates = Get-WUList @WUPara
                }
				$UpdateNumber = ($updates | Measure-Object).Count
				if (($UpdateNumber -eq 0) -and ($Restart)){
					if ($ComputerName){
                        Invoke-Command -session $session -ScriptBlock $GetPendingRestart
                    }else{
                        Invoke-Command -ScriptBlock $GetPendingRestart
                    }
				}

				#if there are available updates proceed with installing
				if ($updates){
                    $WUPara.Add('AcceptAll',$true)

                    #Auto Restart
                    if ($Restart){
                        $WUPara.Add('AutoReboot',$true)
                        $WUPara.Remove('IgnoreReboot')
                    }

                    #convert parameter splatter to string
                    $String = $null
                    foreach ($Item in $WUPara) {
                        foreach ($Entry in $Item.GetEnumerator()) {
                            if ($Entry.Value -eq $true){
                                $String = $String + ' -' + $Entry.Key
                            }else{
                                $String = $String + ' -' + $Entry.Key + ' '
                                foreach ($Value in $Entry.Value){
                                    $String = $String + "'" + $Value + "'"
                                    if ($Value -ne $Entry.Value[-1] -and ($Entry.Value).Count -ne 1){
                                        $String = $String + ","
                                    }
                                }
                            }
                        }
                    }

					#remote command to install windows updates, creates a scheduled task on remote computer
					$Script = [scriptblock]::Create("Install-WindowsUpdate $String | Out-File $env:ALLUSERSPROFILE\AdminScripts\PSWindowsUpdate.log")

					Write-Verbose "Initiating Windows Updates" -Verbose
                    
                    if ($ComputerName){

					    $OldTask = Get-ScheduledTask "PSWindowsUpdate" -CimSession $CimSession -ErrorAction SilentlyContinue
					    if ($OldTask){
						    $OldTask | Unregister-ScheduledTask -Confirm:$false
					    }

					    $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-command `"$Script`""
                        $DateBlock = {(get-date).AddSeconds(3)}
					    $StartTime = Invoke-Command -session $session -ScriptBlock $DateBlock
					    $Trigger = New-ScheduledTaskTrigger -Once -At $StartTime
					    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
					    $Principal = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest


					    Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "PSWindowsUpdate" -Description "Windows Updates" `
						    -Settings $Settings -Principal $Principal -Force -Verbose:$false -CimSession $CimSession | Out-Null

					    #Pause to let task start
					    Start-Sleep -Seconds 5

					    #check if running else force to run
					    $TaskInfo = Get-ScheduledTaskInfo "PSWindowsUpdate" -CimSession $CimSession
					    if ($TaskInfo.LastTaskResult -eq 267011){
						    Start-ScheduledTask "PSWindowsUpdate" -CimSession $CimSession
						    Start-Sleep -Seconds 5
					    }

					    #Show update status until the amount of installed updates equals the same as the amount of updates available
					    $InstalledNumber = $DownloadNumber = 0

                        #temp drive for tracking updates
                        $DriveName = "WUDrive-$($ComputerName -replace '\.','')"

					    #Remove PSDrive if exists (script interupted)
                        Get-PSDrive | Where-Object {$_.Name -like  "WUDrive-*"} | Remove-PSDrive

					    $DrivePara = @{
						    Name = $DriveName
						    PSProvider = "FileSystem"
						    ErrorAction = "Stop"
					    }
                        $DrivePara.Add('Root',"\\$ComputerName\c$")

					    if ($Credential){
						    $DrivePara.Add("Credential",$Credential)
					    }
					    #create temp drive
					    New-PSDrive @DrivePara | out-null
					    $LogPath = "$($DrivePara.Name):\ProgramData\AdminScripts\PSWindowsUpdate.log"
                        $ErrorActionPreference = 'SilentlyContinue'
					    do {
						    if (Test-Path "$LogPath"){
							    $UpdateLog = Get-Content "$LogPath"
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
						    $TaskState = Get-ScheduledTask "PSWindowsUpdate" -CimSession $CimSession -ErrorAction SilentlyContinue
						    $TaskInfo = Get-ScheduledTaskInfo "PSWindowsUpdate" -CimSession $CimSession -ErrorAction SilentlyContinue
						    $PingState = Test-Connection $ComputerName -Quiet
					    }until ((!($PingState)) -or ($TaskState.State -ne "Running"))

                        $ErrorActionPreference = 'Continue'
				
					    if (!($PingState)){
						    Write-Error "Connection lost to $ComputerName"
						    $host.ui.RawUI.WindowTitle = "$ComputerName - Error"
						    Exit
					    }
					
					    Write-Progress -Activity "Installing Updates" -Completed -Id 1
					    Remove-PSDrive "$($DrivePara.Name)"
					
					    if ($TaskState.State -ne "Running" -and ($TaskInfo.LastTaskResult -eq 0 -or $TaskInfo.LastTaskResult -eq 267014 -or $TaskInfo.LastTaskResult -eq 259)){  
						    Write-Output "Update Task Ended - $(get-date)"
						    $host.ui.RawUI.WindowTitle = "$ComputerName - Task Completed"
					    }else{
						    $host.ui.RawUI.WindowTitle = "$ComputerName - Error"
						    Write-Warning "Task completed with an error."
					    }
                    }else{
                        Invoke-Command -ScriptBlock $Script
                    }

                    if ($Restart){
						if ($UpdateNumber -eq 1){
							#Antivirus updates sometimes occur on second run and doesn't reboot afterwards
							Invoke-Command -session $session -ScriptBlock $GetPendingRestart
						}					
						Write-Output "If updates required restart, the computer will restart shortly"				 
					}

				}else{
					if ($ComputerName){$host.ui.RawUI.WindowTitle = "$ComputerName - Up to Date"}
				}
			}
		}else{
			if ($ComputerName){$host.ui.RawUI.WindowTitle = "$ComputerName - Updates Already Running"}
			Write-Warning "Update task is still running on $ComputerName"
		}
	}else{
		Write-Error "Unable to connect to $ComputerName"
	}
}