<#
.SYNOPSIS
  Email notification for outages

.PARAMETER SMTPServer
  SMTP server used to send email. The default gmail one is set as default.

.PARAMETER EmailTo
  Address where email is sent

.PARAMETER EmailFrom
  Address where email is sent from. Ignored by gmail.

.PARAMETER MailUsername
  SMTP username for authentication

.PARAMETER MailPassword
  SMTP password for authentication

.PARAMETER EventID
  Event ID of event posted by UPS service. Message will contain details of event.

.DESCRIPTION
  Sends email message based on event ID of UPS service.
#>
[cmdletbinding()]
param(
    [string]$SMTPServer = "smtp.gmail.com",
    [string]$EmailTo = "username@gmail.com",
    [string]$EmailFrom = "noreply@domain.com",
    [string]$MailUsername = "username",
    [string]$MailPassword = "password",
    [Parameter(Mandatory=$true)]
    [int]$EventID
)

#Get details of event
$filter = @{
    LogName = 'Application'
    ID = $EventID
    StartTime = [datetime]::Now.AddDays(-7) 
}
$Event = Get-WinEvent -FilterHashtable $filter -MaxEvents 1


$Subject = $Event.Message
$Body = "<pre>$(($Event | Format-Table | Out-String).Trim())</pre>"
$MailMessage = New-Object System.Net.Mail.Mailmessage $EmailFrom, $EmailTo, $Subject, $Body
$MailMessage.IsBodyHtml = $true

$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
$SMTPClient.EnableSsl = $true
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($MailUsername, $MailPassword); 
$SMTPClient.Send($MailMessage)
    