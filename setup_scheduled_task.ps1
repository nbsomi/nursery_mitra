# Must be run as Administrator
$ScriptPath = "C:\Users\nb\OneDrive\Desktop\nursery_mitra\start_backend.ps1"
$TaskName = "NurseryMitraServer"

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""$ScriptPath"""

# Run with highest privileges (Admin)
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Action $Action -Principal $Principal -Description "Starts Nursery Mitra Uvicorn server and Cloudflare tunnel silently with logging" -Force

Write-Host "Successfully registered Scheduled Task: $TaskName"
Write-Host "It will run silently on login and output logs to the 'backend' folder."
Start-Sleep -Seconds 5
