<#
.SYNOPSIS
  Email notification

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

.PARAMETER HTMLMessage
  html body for email

.DESCRIPTION
  Sends email message
#>
[cmdletbinding()]
param(
    [string]$SMTPServer = "smtp.gmail.com",
    [string]$EmailTo = "USERNAME@gmail.com",
    [string]$EmailFrom = "noreply@domain.com",
    [string]$MailUsername = "USERNAME",
    [string]$MailPassword = "12345",
    [parameter(Mandatory=$true)]
    [string]$Message,
    [switch]$HTML,
    [string]$Subject,
    [int]$Port = 587
)


$Secpasswd = ConvertTo-SecureString $MailPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($MailUsername, $Secpasswd)


$MailArgs = @{
    SmtpServer = $SMTPServer
    Credential = $cred
    To         = $EmailTo
    From       = $EmailFrom
    Subject    = $Subject
    Body       = $Message
    Port       = $Port
}

if ($HTML){
    $MailArgs.BodyAsHtml = $true
}

Send-MailMessage -UseSsl @MailArgs