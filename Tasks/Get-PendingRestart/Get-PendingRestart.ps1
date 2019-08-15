<#
.SYNOPSIS

    Checks windows update restart status

.DESCRIPTION
	Checks windows update restart status.  
	Get-PendingRestartSilent.vbs is required.
	Both scripts need to be placed in $env:APPDATA\AdminScripts`.
	Create a group policy to create a scheduled task to run Get-PendingRestartSilent.vbs throughout the day.
	
.PARAMETER DelayedRestart
	Parameter that flags that the user was already warned and to prepare for forced restart.
	Uptimes will be verified in case user already restarted.
	
.PARAMETER Test
	Sets false date so that the script is ran as if the computer uptime was 30 days.
	
.PARAMETER RestartDays
	Sets max uptime in days. Default is set to 7.
	
.PARAMETER Hour
	Time at which forced restart occurs. Default is 17 or 5PM
#>
[cmdletbinding()]
param(
    [switch]$DelayedRestart,
    [switch]$Test,
    #Amount of time before nag popup
    $RestartDays=[int]7,
    #Amount of time before forced restart
    #$RestartDayDelay=[int]0,
    #Time (hour) of forced restart
    $Hour=[int]17,
	#Time (hour) that script is allowed to check for updates
	$UpdateHour=[int]15
)

$Computer=$env:COMPUTERNAME
$DelayRestart=$null
$RestartTaskPending=$null
$NoRestartTask=$null
#Message Object
$message = new-object -comobject wscript.shell

function Get-CCMClientRebootPending {
    #Checks if SCCM reports pending reboot
    Try {
	    $CCMClientRebootPending = Invoke-WmiMethod -Class CCM_ClientUtilities -Namespace root\ccm\clientsdk -Name DetermineIfRebootPending -ErrorAction Stop
    } Catch {
	    $CcmStatus = Get-Service -Name CcmExec -ErrorAction SilentlyContinue
	    If ($CcmStatus.Status -ne 'Running') {
	        Write-Warning "$Computer`: Error - CcmExec service is not running."
	    }
    }
    Return $CCMClientRebootPending
}

function Get-CCMClientUpdates{
    #pulls list of updates
    Try {
        $CCMClientUpdates = Get-CimInstance -ClassName CCM_SoftwareUpdate -Namespace root\CCM\ClientSDK -ErrorAction Stop
    }catch{
	    Write-Error "An error occured while pulling pending SCCM update list."
    }
    Return $CCMClientUpdates
}
    
function Check-PendingRestarts {
    #RebootRequired subkey 
    $AutoUpdateKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
    $CCMReboots = Get-CCMClientRebootPending

    If ($CCMReboots) {
        Write-Verbose "SCCM service detected."
	    If ($CCMReboots.ReturnValue -ne 0) {
		    Write-Warning "Error: DetermineIfRebootPending returned error code $($CCMReboots.ReturnValue)"  
	    }
	    If ($CCMReboots.IsHardRebootPending -or $CCMReboots.RebootPending) {
            Write-Verbose "SCCM Client reports pending reboot"
            $SCCMUpdates = Get-CCMClientUpdates
            $SCCMUpdateCount = ($SCCMUpdates| Measure-Object).Count
            if ($SCCMUpdateCount -gt 0){
                $PendingReboot = $True
                $Output = $null
                foreach ($Update in $SCCMUpdates){
                    $Output += "`n$($Update.name)"
                }
                Write-Verbose "Updates found pending SCCM: $Output"
            }else{
                Write-Warning "SCCM reported pending restart but no updates were listed."
            }
	    }
    }
    If (Test-Path -Path "$AutoUpdateKeyPath\RebootRequired"){
        Write-Verbose "Registry flag for pending update found"
        $PendingReboot = $True
    }

    If ($PendingReboot){
        if ($SCCMUpdateCount -gt 1){
            Return $SCCMUpdateCount
        }else{
            Return $True
        }
    }else{
        Return $False
        Write-Verbose "No pending reboot flags found"
    }
}

#Only run on workstations
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 1){
	#verify vbs script is in required folder
	if (!(Test-Path "$env:APPDATA\AdminScripts\Get-PendingRestartSilent.vbs")){
		Write-Error "Get-PendingRestartSilent.vbs is required for silent runs. Place in $env:APPDATA\AdminScripts"
		Exit
	}
    if ($Test){
        Write-Verbose "Test switch found. Setting date of last boot to 30 days ago."
        $LastBoot=(get-date).AddDays(-30)
    }else{
        #get date of last reboot
        $LastBoot = (Get-CimInstance -ClassName win32_operatingsystem -Verbose:$false | select lastbootuptime).lastbootuptime
        if (!$LastBoot){
            Write-Warning "Last boot time is null. Get-CimInstance might be unsupported!"
        }else{
			Write-Verbose "CimInstace boot time: $LastBoot"
		}
    }
    #get latest date for required restart
    $DateLimit = (get-date).adddays(-$RestartDays)
	Write-Verbose "Maximum uptime date: $DateLimit"

    #Check if task is already scheduled

    Try{
        $RestartTask=Get-ScheduledTask "DelayedRestart - $env:USERNAME" -ErrorAction stop| Get-ScheduledTaskInfo
    }Catch{
        Write-Verbose "No DelayedRestart task found"
        $NoRestartTask=$true
    }
    If (!$NoRestartTask){
        if ($RestartTask.NextRunTime){
            $RestartTaskPending = $true
            Write-Verbose "Task already set. Pending run."
        }else{
            Write-Verbose "Task already run in past and no current pending run."
        }
    }

    If ($DelayedRestart){
        Write-Verbose "DelayedRestart switch active."
        #Runs if ForcedRestart Parameter is true and time is correct
        if (((get-date).Hour -eq $Hour) -or $Test) {
            $wmi = Get-WmiObject -Class win32_OperatingSystem
            if ((($wmi.ConvertToDateTime($wmi.LocalDateTime)–$wmi.ConvertToDateTime($wmi.LastBootUpTime)).Days -ge $RestartDays) -or (Check-PendingRestarts)){
                Write-Verbose "Forced restart parameter. Starting restart countdown."
                shutdown -r -t 120
            }else{
                Write-Verbose "Uptime is less than $RestartDays days. Aborting restart."
            }
        }else{
			Write-Verbose "Forced restart was initiated at the incorrect time of $Hour hours. Aborting forced restart."
		}
    }Elseif (!$RestartTaskPending){
        #Get date of forced restart
        $ForcedRestartDate = get-date -Hour $Hour -Minute 0 -Second 0

        $restart = Check-PendingRestarts

        if ($restart){
            if ($restart -is [int]){
                $NumberString = "$restart updates"
            }else{
                $NumberString = "a pending update"
            }
            $messagestring = 
                "Your computer has $NumberString that requires restart.`nWould you like to restart now?"`
                +"`nIf you select no, a restart will be scheduled at:`n$($ForcedRestartDate.tostring("M/d/yyyy hh:mm tt"))."
            $Answer = $message.popup($messagestring,60,"Restart Pending!",4+48)

            #If yes, restart
            If ($Answer -eq 6){
                $DelayRestart = $false
            }Else{
                $DelayRestart = $true
            }
        #Checks if computer has been restarted
        }ElseIf ($Lastboot -and ($LastBoot -lt $DateLimit)){
            Write-Verbose "No pending restarts but computer has not been restarted at maximum threshold."
            $messagestring = 
                "Your computer has not been restarted in $RestartDays days. Would you like to restart now?"`
                +"`nIf you select no, a restart will be scheduled at:`n$($ForcedRestartDate.tostring("M/d/yyyy hh:mm tt"))."
            $Answer=$message.popup($messagestring,60,"Restart Required!",4+48)

            #If yes, restart in one minute
            If ($Answer -eq 6){
                $DelayRestart = $false
            }Else{
                $DelayRestart = $true
            }
        }

        #Creates Scheduled task to restart
        If ($DelayRestart){
            Write-Verbose "Creating scheduled task to restart the computer later."
            $action=New-ScheduledTaskAction -Execute "$env:APPDATA\AdminScripts\Get-PendingRestartSilent.vbs" `
                -Argument "/DelayedRestart /Hour:$Hour /RestartDays:$RestartDays"
            $trigger=New-ScheduledTaskTrigger -Once -At $ForcedRestartDate
            $settings=New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Verbose:$false #-hidden

        Register-ScheduledTask -Settings $settings -Action $action -Trigger $trigger -TaskName "DelayedRestart - $env:USERNAME" -Description "User delayed required restart" -Force -Verbose:$false | Out-Null


        }elseif($null -ne $DelayRestart){
            #Restart
            shutdown -r -t 00
        }else{
            $CCMClient = Get-CCMClientRebootPending
            if($CCMClient){
                #Check only for updates on Wednesday and scheduled time
                if (((get-date).DayOfWeek -eq "Wednesday") -and ((get-date).Hour -ge $UpdateHour)){
                    Write-Verbose "All checks passed and scheduled time is true. Checking for updates on SCCM."
                    #Checks for updates if any of the above was not true

                    $ApplicationClass = [WmiClass]"root\ccm\clientSDK:CCM_SoftwareUpdatesManager"
                    $Application = (Get-WmiObject -Namespace "root\ccm\clientSDK" -Class CCM_SoftwareUpdate `
                        | Where-Object { $_.EvaluationState -like "*0*" -or $_.EvaluationState -like "*1*"})
                    Invoke-WmiMethod -Class CCM_SoftwareUpdatesManager -Name InstallUpdates `
                        -ArgumentList (,$Application) -Namespace root\ccm\clientsdk -ErrorAction Continue | Out-Null
                }else{
                    Write-Verbose "All checks passed and update audit was skipped due to current time."
                }
            }else{
                Write-Verbose "SCCM service was not found but no pending updates were found and computer is within uptime window."
            }
        }
    }
}