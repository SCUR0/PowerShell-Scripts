<#
.SYNOPSIS
  Checks status of FileHistory.

.PARAMETER TaskbarNotification
  Enables taskbar warning when filehistory has not been ran.

.PARAMETER CheckHours
  Amount of time filehistory has to run before a notification is sent. Defaults to 12.

.PARAMETER SMTPServer
  SMTP server used to send email. The default gmail one is set as default.

.PARAMETER EmailTo
  Address where email is sent

.PARAMETER MailUsername
  SMTP username for authentication

.PARAMETER MailPassword
  SMTP password for authentication

.DESCRIPTION
  Filehistory logs will be checked to see if the service has been running.
  If they have not been running, the service will send email.
  If you do not want to send parameters edit defaults below
#>
[cmdletbinding()]
param(
    [switch]$TaskbarNotification,
    [int]$CheckHours = 12,
    [string]$SMTPServer = "smtp.gmail.com",
    [string]$EmailTo = "user@gmail.com",
    [string]$MailUsername = "gmailusername",
    [string]$MailPassword = "gmailAppPassword"
)

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")


if ($TaskbarNotification){
    ########Icon file used to show ballon tip if enabled########
    $IconPath = "D:\Shared\Documents\Scripts\Tasks\warn.ico"

    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
    #Icon file used to show ballon tip
    $objNotifyIcon.Icon = $IconPath
    $objNotifyIcon.BalloonTipIcon = "Warning" 
    $objNotifyIcon.BalloonTipText = "File History has not ran in more than $CheckHours hours. Check status" 
    $objNotifyIcon.BalloonTipTitle = "File History Error"
}

$messagestring = "File history has not been ran in more than $CheckHours hours. Please check status.
More than often, the service was stopped after an update."
$timespan = New-TimeSpan -Hours $CheckHours
$FilehistoryLog = Get-WinEvent -LogName Microsoft-Windows-FileHistory-Core/WHC -MaxEvents 1
$EmailFrom = "no-reply@domain.com"

$Subject = "Warning: FileHistory has not ran in $CheckHours hours." 
$Body = "FileHistory has frozen. Please check status on $env:COMPUTERNAME." 

if (((get-date) - $FilehistoryLog.TimeCreated) -gt $timespan){
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587) 
    $SMTPClient.EnableSsl = $true
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($MailUsername, $MailPassword); 
    $SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
    
    if ($TaskbarNotification){
        $objNotifyIcon.Visible = $True 
        $objNotifyIcon.ShowBalloonTip(10000)
    }
}
