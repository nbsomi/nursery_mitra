$BackendDir = "C:\Users\nb\OneDrive\Desktop\nursery_mitra\backend"
$LogsDir = "$BackendDir\logs"

if (!(Test-Path -Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir | Out-Null
}

$UvicornLog = "$LogsDir\uvicorn.log"
$CloudflareLog = "$LogsDir\cloudflared.log"

# Start the FastAPI server using Uvicorn. Combine stdout/stderr (2>&1) and prepend timestamp to each line.
$UvicornScript = "python -m uvicorn main:app --host 0.0.0.0 --port 8000 2>&1 | ForEach-Object { `"`$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) `$_`" } >> '$UvicornLog'"
Start-Process "powershell.exe" -ArgumentList "-WindowStyle Hidden -Command `"$UvicornScript`"" -WorkingDirectory $BackendDir -WindowStyle Hidden

# Wait a couple of seconds to let the server start
Start-Sleep -Seconds 5

# Start Cloudflare Tunnel. Combine stdout/stderr (2>&1) to the same log. Cloudflared already outputs timestamps natively.
$CloudflareScript = "cloudflared tunnel run --url http://localhost:8000 nursery-mitra-backend 2>&1 >> '$CloudflareLog'"
Start-Process "powershell.exe" -ArgumentList "-WindowStyle Hidden -Command `"$CloudflareScript`"" -WindowStyle Hidden
