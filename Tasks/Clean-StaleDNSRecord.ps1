<#
.SYNOPSIS
	Cleans duplicate DNS records

.DESCRIPTION
	Searches DNS records for duplicates on the specified subnet. Also removes unresponsive clients from DNS. Useful for VPN records that aren't scrubbed

.PARAMETER DNSSErver
	DNS server hostname if running script remotely

.PARAMETER Domain
	Used for looking up zone name and filtering

.PARAMETER Subnet
	Search pattern for subnet. Astrisk is wildcard

.PARAMETER NoPing
	By default script will also ping clients to check connectivity. If ICMP is blocked or clients aren't configured to reply, use -NoPing to skip.

.PARAMETER Jobs
	How many jobs are run for pings. Default is 10.

.EXAMPLE
	.\Clean-StaleDNSRecord.ps1 -domain "example.com" -subnet "10.20.*"
#>

[CmdletBinding(SupportsShouldProcess)]
param (
	[string]$DNSServer,
	[Parameter(Mandatory=$True)]
	[string]$Domain,
	[Parameter(Mandatory=$True)]
	[string]$Subnet,
	[switch]$NoPing,
	[int]$Jobs = 10
)

#functions
function JobsRunningCount {
	return (Get-Job -Name DNSCleanup -ErrorAction SilentlyContinue | where {$_.State -eq 'Running'}).Count
}

$DNSArgs = @{
	ZoneName = $Domain
	RRType   = 'A'
}
if ($DNSServer){
	$DNSArgs.Add('ComputerName',$DNSServer)
}

Write-Verbose 'Pulling DNS records' -Verbose
$DNSRecords = Get-DnsServerResourceRecord @DNSArgs | Where-Object {$_.RecordData.IPv4Address -like $Subnet -and ($_.Timestamp) -and $_.Hostname -notlike "*.$Domain"} |`
				  Select-Object Hostname,Timestamp,@{N="IPv4Address";E={$_.RecordData.IPv4Address}} | Sort-Object IPv4Address, Timestamp -Descending
if (!$?){
	exit
}

#Remove duplicate records that are older than most recent
Write-Verbose 'Searching and removing duplicate IPs in DNS' -Verbose
$IPCount = 1
Foreach ($Record in $DNSRecords){
	if ($Record.IPv4Address -eq $LastIP){
		$IPCount++
	}else{
		$IPCount = 1
	}
	if ($IPCount -gt 1){
		Remove-DnsServerResourceRecord @DNSArgs -Name $Record.Hostname -RecordData $Record.IPv4Address -Force -Verbose
	}
	$LastIP = $Record.IPv4Address
}

$PingScript = {
	param(
		[string]$IP,
		[string]$Hostname,
		$DNSArgs
	)

	if (!(Test-Connection $IP -Quiet -Count 3)){
		Remove-DnsServerResourceRecord @DNSArgs -Name $Hostname -RecordData $IP -Force -Verbose
	}
}


#check for orphaned jobs
Get-Job -Name DNSCleanup -ErrorAction SilentlyContinue | Remove-Job

if (!$NoPing){
	Write-Verbose 'Checking connectivity of addresses in DNS' -Verbose
	$i = 0
	$TotalRecords = $DNSRecords.count
	foreach($Record in $DNSRecords){
		if (($TotalRecords -lt 100) -or ($i % $Increments -eq 0)){
			#Progress bar
			Write-Progress -Activity 'Checking Connectivity' -Status "$i of $TotalRecords"  -PercentComplete ($i / $TotalRecords * 100)
		}
		if ((JobsRunningCount) -le $Jobs){
			Start-Job -Name DNSCleanup -ScriptBlock $PingScript -ArgumentList $Record.IPv4Address,$Record.Hostname,$DNSArgs > $null
		}else{
			#loop until next opening
			while ((JobsRunningCount) -ge $Jobs){
				Start-Sleep -Seconds 1
			}
			Start-Job -Name DNSCleanup -ScriptBlock $PingScript -ArgumentList $Record.IPv4Address,$Record.Hostname,$DNSArgs > $null
		}
		$i++
	}
	Write-Progress -Activity 'Pinging IPs' -Completed

	#loop waiting for jobs to finish
	while ((JobsRunningCount) -gt 0){
		$JobsRunningPrint = JobsRunningCount
		Write-Host "`rWaiting for " -NoNewline
		Write-Host "$JobsRunningPrint " -ForegroundColor Yellow -NoNewline
		Write-Host "jobs to complete..." -NoNewline
		Start-Sleep -Seconds 1
	}
	Write-Host

	#Print results
	$EndJobs = Get-Job -Name DNSCleanup
	$EndJobs | Receive-Job
	$EndJobs | Remove-Job
}