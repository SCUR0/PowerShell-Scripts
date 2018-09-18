<#
.SYNOPSIS
  Checks status of FileHistory.

.DESCRIPTION
  Filehistory logs will be checked to see if the service has been running.
  If they have not been running, the service will send email.
#>
[cmdletbinding()]
param ()

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

#varriables
$checkhours=12

#Delete this section if you don't care about notification via windows notifications
$objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
#Icon file used to show ballon tip
$objNotifyIcon.Icon = "D:\Shared\Documents\Scripts\Tasks\warn.ico"
$objNotifyIcon.BalloonTipIcon = "Warning" 
$objNotifyIcon.BalloonTipText = "File History has not ran in more than $checkhours hours. Check status" 
$objNotifyIcon.BalloonTipTitle = "File History Error"

$messagestring = "File history has not been ran in more than $checkhours hours. Please check status.
More than often, the service was stopped after an update."
$timespan = New-TimeSpan -Hours $checkhours
$FilehistoryLog = Get-WinEvent -LogName Microsoft-Windows-FileHistory-Core/WHC -MaxEvents 1
$EmailFrom = "no-reply@domain.com"
$EmailTo = "address@domain.com" 
$Subject = "Warning: FileHistory has not ran in $checkhours hours." 
$Body = "FileHistory has frozen. Please check status on $env:COMPUTERNAME." 

#change to SMTP server. I used Gmail's
$SMTPServer = "smtp.gmail.com" 

if (((get-date) - $FilehistoryLog.TimeCreated) -gt $timespan){
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587) 
    $SMTPClient.EnableSsl = $true 
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential("username", "password"); 
    $SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
    
    #delete below if not using windows notifications
    $objNotifyIcon.Visible = $True 
    $objNotifyIcon.ShowBalloonTip(10000)
}
