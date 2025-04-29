$Global:ErrorActionPreference = 'Stop'
Write-Host "Stopping Intune Service" -ForegroundColor Yellow
Get-Service *intune* | Stop-Service
Write-Host "Check if device is AAD Joined" -ForegroundColor Yellow
$DSREGCMD = dsregcmd /status
$AADJoinCheck = $null
$AADJoinCheck = $DSREGCMD | Select-String -Pattern 'AzureAdJoined : YES'
if ($null -eq $AADJoinCheck) {
	Write-Host "Device is not AAD Joined!!! Stopping!" -ForegroundColor Red
	Break
} else {
	Write-Host "Device is AAD Joined - OK" -ForegroundColor Green
}
Write-Host "Searching for enrollment ID"
$Tasks = Get-ScheduledTask | Where-Object { $psitem.TaskPath -like "\Microsoft\Windows\EnterpriseMgmt\*" }
$EnrollId = $Tasks[0].TaskPath.Split('\\')[-2]
if ($EnrollID -match '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}') {
	Write-Host "Found EnrollID - $EnrollID" -ForegroundColor Green
} else {
	Write-Host "Error parsing EnrollID. Stopping" -ForegroundColor Red
	Break
}
Write-Host "Removing scheduledTasks" -ForegroundColor Yellow
Try {
	$Tasks | ForEach-Object { Unregister-ScheduledTask -InputObject $psitem -Verbose -Confirm:$false }
} catch {
	Throw $_.Exception.Message
}
Write-Host "Done" -ForegroundColor Green
Write-Host "Trying to remove tasks folder" -ForegroundColor Yellow
$TaskFolder = Test-Path "C:\windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollID"
try {
	if ($TaskFolder) {
		Remove-Item -Path "C:\windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollID" -Force -Verbose 
	}
} catch {
	Throw $_.Exception.Message
}
Write-Host "Removing registry keys" -ForegroundColor Yellow
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Enrollments\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Enrollments\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$EnrollID -Recurse -Force -Verbose 
}
##### Run this if Remove-Item -Path "C:\windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollID" -Force -Verbose FAILED
<#
$EnrollmentReg = Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\EnterpriseMgmt\$EnrollID"
if ($EnrollmentReg) {
	Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\EnterpriseMgmt\$EnrollID" -Recurse -Force -Verbose 
}
#>
Write-Host "Checking for Intune MDM cert" -ForegroundColor Yellow
$Certs = $null
$Certs = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { $psitem.issuer -like '*Intune*' }
if ($null -ne $Certs) {
	$(Get-Item ($Certs).PSPath) | Remove-Item -Force -Verbose 
	Write-Host "Removed" -ForegroundColor Green
} else {
	Write-Host "Not found" -ForegroundColor Yellow
}
Write-Host "Downloading psexec" -ForegroundColor Yellow
Invoke-RestMethod -Uri 'https://download.sysinternals.com/files/PSTools.zip' -OutFile $env:TEMP\PSTools.zip
Write-Host "Expanding psexec" -ForegroundColor Yellow
Expand-Archive -Path $env:TEMP\PSTools.zip -DestinationPath $env:TEMP\PSTools -Force
Write-Host "Starting psexec with AutoEnrollMDM" -ForegroundColor Yellow
$Process = Start-Process -FilePath $env:TEMP\PSTools\psexec.exe -ArgumentList "-i -s -accepteula cmd  /c `"deviceenroller.exe /c /AutoEnrollMDM`"" -Wait -NoNewWindow -PassThru
if ($process.ExitCode -eq 0) {
	Write-Host "Started AutoEnrollMDM" -ForegroundColor Green

} else {
	Write-Host "Exit code 1. Please verify manually" -ForegroundColor Red
}
if ((Get-Service *intune*).Status -ne 'Running') {
	Get-Service *intune* | Start-Service
}


