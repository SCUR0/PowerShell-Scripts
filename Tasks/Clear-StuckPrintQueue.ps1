<#
.SYNOPSIS
    Clears print queue

.PARAMETER  Force
	Forces deletion of oldest print job regardless of time.

.PARAMETER  Minutes
	Time window for maximum age of print. Default is 60

.DESCRIPTION
	Script runs a simple check on print queue files and looks for files older than set time.
	If item is found. Print service is stopped and the print job removed.
	Default is 60 minutes
#>
[cmdletbinding()]
param (
    [switch]$Force,
	[int]$Minutes = 60
)

$timeLimit = (Get-Date).AddMinutes(-$Minutes)

#Print Spooler Queue directory
$Dir = "$env:SystemRoot\System32\spool\PRINTERS\"

if (!$Force){
	Write-Verbose "Checking for items older than $Minutes minutes" -Verbose
	#check for items older than minutes(s)
	
	#Optional code: ($_.PrinterStatus -ne "Error") -and
	$StuckPrints = Get-Printer | where-object {($_.JobCount -gt 0)} | Get-PrintJob | where-object {$_.SubmittedTime -lt $timeLimit}
	if ($null -ne $StuckPrints){
		Write-Verbose "Print job older than $Minutes minutes found in print queue. Canceling print job" -Verbose
        #Eventlog Output of printer and owner of stuck prints
        $StuckPrintInfo = ''
        $StuckPrints | %{$StuckPrintInfo += "`nPrinter:$($_.PrinterName)`nUser: $($_.Username) `nDocument:$($_.DocumentName)`n"}
		Write-EventLog -LogName Application -Source "OHSD-Scripts" -EntryType Information -EventID 4 -Message `
			"Print job older than $Minutes minutes found in print queue. Canceling print job.`n$StuckPrintInfo"
		$StuckPrints | Remove-PrintJob
		#Loop to check if remove was successful
		$Timeout = 0
		do{
			Start-Sleep -seconds 1
			$StuckPrints = Get-Printer | where-object {($_.JobCount -gt 0)} | Get-PrintJob | where-object {($_.SubmittedTime -lt $timeLimit) -and ($_.jobstatus -like "*Deleting*")}
            if ($Timeout -eq 0){
                $StuckPrintsT = Get-Printer | where-object {($_.JobCount -gt 0)} | Get-PrintJob | where-object {($_.SubmittedTime -lt $timeLimit) -and ($_.jobstatus -like "*Deleting*")}
            }
            $Timeout++
		}until((!$StuckPrints) -or ($Timeout -ge 60))
		if ($Timeout -ge 60){
            Write-Warning "Print job hung on deletion. Will attempt forced deletion"
            $StuckPrints = Get-ChildItem -Path $Dir | Where-Object {$_.CreationTime -lt $timeLimit}
		}else{
		}
		
	}

}else{
    #force mode
	Write-Verbose "Forcing deletion of oldest print job." -Verbose
	$StuckPrints = Get-ChildItem -Path $Dir | Sort CreationTime | select -First 2
}
#only stop services as last resort or force parameter is present
if ($StuckPrints){
	Write-EventLog -LogName Application -Source "Admin-Scripts" -EntryType Information -EventID 5 -Message `
	"Print job did not terminate. Forcing deletion of print. `n$StuckPrints"
	Write-Verbose "Stopping Print Spooler." -Verbose
	Get-Service "Spooler" | Stop-Service -Force
	Write-Verbose "Deleting old prints" -Verbose
	$StuckPrints | Remove-Item -Force
	Write-Verbose "Starting Print Spooler." -Verbose
	Get-Service "Spooler" | Start-Service
	#exit with error code one to signify a print object required forced deletion
	exit 1
}
