Set objShell = CreateObject( "WScript.Shell" )
appDataLocation=objShell.ExpandEnvironmentStrings("%APPDATA%")
getPendingRestart = appDataLocation & "\AdminScripts\Get-PendingRestart.ps1"
Set vbArgs = WScript.Arguments.Named
Dim Args

If vbArgs.Exists("DelayedRestart") Then
	Args = Args & " -DelayedRestart"
End If


If vbArgs.Exists("RestartDays") Then
	Args = Args & " -RestartDays " & vbArgs.Item("RestartDays")
End If

If vbArgs.Exists("UpdateHour") Then
	Args = Args & " -UpdateHour " & vbArgs.Item("UpdateHour")
End If

sCmd = "powershell.exe -file " & getPendingRestart & Args

Set xShell = CreateObject("Wscript.Shell")
'WScript.echo sCmd
xShell.Run sCmd, 0