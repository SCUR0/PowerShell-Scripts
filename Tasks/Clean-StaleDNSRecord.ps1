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
	Search pattern for subnet. Astrisk is wildcard.

.EXAMPLE
    .\Clean-StaleDNSRecord.ps1 -domain "example.com" -subnet "10.20.*"
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [string]$DNSServer,
    [Parameter(Mandatory=$True)]
    [string]$Domain,
    [Parameter(Mandatory=$True)]
    [string]$Subnet
)

$DNSArgs = @{
    ZoneName = $Domain
    RRType   = 'A'
}
if ($DNSServer){
    $DNSArgs.Add('ComputerName',$DNSServer)
}

Write-Verbose 'Checking DNS records' -Verbose
$DNSRecords = Get-DnsServerResourceRecord @DNSArgs | Where-Object {$_.RecordData.IPv4Address -like $Subnet -and ($_.Timestamp) <#-and $_.Hostname -notlike "*.$Domain"#>} |`
                  Select-Object Hostname,Timestamp,@{N="IPv4Address";E={$_.RecordData.IPv4Address}}
if (!$?){
    exit
}

$Script = {
    param(
        [string]$IP,
        [string]$Hostname,
        $DNSArgs
    )

    if (!(Test-Connection $IP -Quiet)){
        Remove-DnsServerResourceRecord @DNSArgs -Name $Hostname -RecordData $IP -Force -Verbose
    }
}

#check for orphaned jobs
Get-Job -Name DNSCleanup -ErrorAction SilentlyContinue | Remove-Job

Write-Verbose 'Checking connectivity of addresses in DNS' -Verbose
foreach($Record in $DNSRecords){
    Start-Job -Name DNSCleanup -ScriptBlock $Script -ArgumentList $Record.IPv4Address,$Record.Hostname,$DNSArgs > $null
}

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
