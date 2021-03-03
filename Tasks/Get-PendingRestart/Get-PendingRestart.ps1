<#
.SYNOPSIS

    Checks windows update restart status

.DESCRIPTION
	Checks windows update restart status.
	
.PARAMETER DelayedRestart
	Parameter that flags that the user was already warned and to prepare for forced restart.
	Uptimes will be verified in case user already restarted.
	
.PARAMETER Test
	Sets false date so that the script is ran as if the computer uptime was 30 days.
	
.PARAMETER RestartDays
	Sets max uptime in days. Default is set to 7.
	
.PARAMETER UpdateHour
	Time at which forced restart occurs. Default is 17 or 5PM

.PARAMETER ExclusionGroup
	LDAP path to group for excluded computers. An example would be "CN=GRP_NoRestart,OU=Computers,DC=domain,DC=net"
#>
[cmdletbinding()]
param(
    [switch]$DelayedRestart,
    [switch]$Test,
    #Amount of time before nag popup
    [int]$RestartDays = 7,
    #Time (hour) of forced restart
    [int]$UpdateHour = 17,
    [string]$ExclusionGroup
)

$Computer=$env:COMPUTERNAME
$DelayRestart=$null
$ExcludeRestart=$false
$RestartTaskPending=$null
$NoRestartTask=$null
#Message Object
$message = new-object -comobject wscript.shell
    
function Check-PendingRestarts {
    #RebootRequired subkey 
    $AutoUpdateKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"

    If (Test-Path -Path "$AutoUpdateKeyPath\RebootRequired"){
		Write-EventLog -LogName Application -Source "Admin-Scripts" -EntryType Information -EventID 1 -Message "Registry flag for reboot pending is True"
        Write-Verbose "Registry flag for pending update found"
        Return $True
    }else{
        Write-Verbose "No pending reboot flags found"
		Return $False
	}
}

if ($ExclusionGroup){
    #Check if in exclusion group
    $searcher = [adsisearcher]"(&(objectCategory=Computer)(name=$env:COMPUTERNAME))"
    if ($searcher.FindOne().Properties.memberof -contains $ExclusionGroup){
        Write-Verbose "Computer is in exclusion group. Exiting"
        exit
    }
}


#Only run on non server and computers not part of exclusion group
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 1){
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
        $RestartTask=Get-ScheduledTask "Admin - DelayedRestart - $env:USERNAME" -ErrorAction stop| Get-ScheduledTaskInfo
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
        if (((get-date).Hour -eq $UpdateHour) -or $Test) {
            $wmi = Get-WmiObject -Class win32_OperatingSystem
            if ((($wmi.ConvertToDateTime($wmi.LocalDateTime)–$wmi.ConvertToDateTime($wmi.LastBootUpTime)).Days -ge $RestartDays) -or (Check-PendingRestarts)){
				#Determine if running as System and delay to avoice race condition
                if ($env:USERNAME -eq $env:COMPUTERNAME+'$'){
                    Start-Sleep -s 10
                }               
                Write-EventLog -LogName Application -Source "Admin-Scripts" -EntryType Information -EventID 2 -Message "Forcing restart."
                Write-Verbose "Forced restart parameter. Starting restart countdown."
                shutdown -r -f -t 120
            }else{
				Write-EventLog -LogName Application -Source "Admin-Scripts" -EntryType Information -EventID 2 -Message "Forced restart unnecessary. Uptime less than $RestartDays days."
                Write-Verbose "Uptime is less than $RestartDays days. Aborting restart."
            }
        }else{
			Write-Verbose "Restart task was initiated outside specified time. Hour is set as $UpdateHour"
			Write-EventLog -LogName Application -Source "Admin-Scripts" -EntryType Information -EventID 3 `
				-Message "Restart task was initiated outside specified time. Hour is set as $UpdateHour"
		}
    }Elseif (!$RestartTaskPending){
        #Get date of forced restart
        $ForcedRestartDate = get-date -Hour $UpdateHour -Minute 0 -Second 0
        $restart = Check-PendingRestarts

        if ($restart){
            $messagestring = 
                "Your computer has a pending update that requires restart.`nWould you like to restart now?"`
                +"`nIf you select no, a restart will be scheduled at:`n$($ForcedRestartDate.tostring("M/d/yyyy hh:mm tt"))."
            $Answer = $message.popup($messagestring,1800,"Restart Pending!",4+48)

            #If yes, restart
            If ($Answer -eq 6){
                $DelayRestart = $false
            }Else{
                $DelayRestart = $true
            }
        #Checks if computer has been restarted
        }ElseIf ($Lastboot -and ($LastBoot -lt $DateLimit)){
            Write-EventLog -LogName Application -Source "Admin-Scripts" -EntryType Information -EventID 1 `
                -Message "No pending restarts were found but uptime is outside window. Computer was last booted $LastBoot."
            Write-Verbose "No pending restarts but computer has not been restarted at maximum threshold."
            $messagestring = 
                "Your computer has not been restarted in $RestartDays days. Would you like to restart now?"`
                +"`nIf you select no, a restart will be scheduled at:`n$($ForcedRestartDate.tostring("M/d/yyyy hh:mm tt"))."
            $Answer=$message.popup($messagestring,1800,"Restart Required!",4+48)

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
                -Argument "/DelayedRestart /Hour:$UpdateHour /RestartDays:$RestartDays"
            $trigger=New-ScheduledTaskTrigger -Once -At $ForcedRestartDate
            $settings=New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Verbose:$false

        Register-ScheduledTask -Settings $settings -Action $action -Trigger $trigger -TaskName "Admin - DelayedRestart - $env:USERNAME" -Description "User delayed required restart" -Force -Verbose:$false | Out-Null


        }elseif($null -ne $DelayRestart){
            #Restart
            shutdown -r -t 00
        }else{
			Write-EventLog -LogName Application -Source "Admin-Scripts" -EntryType Information -EventID 0 `
                -Message "No pending restarts were found and uptime is within window. Computer was last booted $LastBoot."
        }
    }
}else{
    Write-Verbose "Restart check was skipped due to being in a group exclusion or a server OS." -Verbose
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        if ($CTask = Get-ScheduledTask -TaskName "Admin - Get-PendingRestart Computer" -ErrorAction SilentlyContinue){
            Write-Verbose "Scheduled task for computer found on device. Removing." -Verbose
            $CTask | Unregister-ScheduledTask -Confirm:$false
        }
        if ($UTask = Get-ScheduledTask -TaskName "Admin - Get-PendingRestarts User" -ErrorAction SilentlyContinue){
            Write-Verbose "Scheduled task for user found on device. Removing." -Verbose
            $UTask | Unregister-ScheduledTask -Confirm:$false
        }
    }
}