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
	[switch]$NoPing
)

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

#ping scriptblock for job
$PingScript = {
	param(
		[string]$IP,
		[string]$Hostname,
		$DNSArgs
	)

	if (!(Test-Connection $IP -Quiet)){
		Remove-DnsServerResourceRecord @DNSArgs -Name $Hostname -RecordData $IP -Force -Verbose
	}
}

if (!$NoPing){
	#check for orphaned jobs
	Get-Job -Name DNSCleanup -ErrorAction SilentlyContinue | Remove-Job
	
	#test client connectivity
	Write-Verbose 'Checking connectivity of addresses in DNS' -Verbose
	foreach($Record in $DNSRecords){
		Start-Job -Name DNSCleanup -ScriptBlock $PingScript -ArgumentList $Record.IPv4Address,$Record.Hostname,$DNSArgs > $null
	}
	
	#show status of jobs
	$JobsRunning = (Get-Job -Name DNSCleanup | where {$_.State -eq 'Running'}).Count
	while ($JobsRunning -gt 0){
		Write-Host "`rChecking " -NoNewline
		Write-Host "$JobsRunning " -ForegroundColor Yellow -NoNewline
		Write-Host 'records...' -NoNewline
		Start-Sleep -Seconds 1
		$JobsRunning = (Get-Job -Name DNSCleanup | where {$_.State -eq 'Running'}).Count
	}
	Write-Host

	#Print results
	$EndJobs = Get-Job -Name DNSCleanup
	$EndJobs | Receive-Job
	$EndJobs | Remove-Job
}
