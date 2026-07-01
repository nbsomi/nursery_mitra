$BackendDir = "C:\Users\nb\OneDrive\Desktop\nursery_mitra\backend"
$UvicornLog = "$BackendDir\uvicorn.log"
$CloudflareLog = "$BackendDir\cloudflared.log"

# Start the FastAPI server using Uvicorn in the background and log output
Start-Process "uvicorn" -ArgumentList "main:app --host 0.0.0.0 --port 8000" -WorkingDirectory $BackendDir -RedirectStandardOutput $UvicornLog -RedirectStandardError $UvicornLog -WindowStyle Hidden

# Wait a couple of seconds to let the server start
Start-Sleep -Seconds 5

# Start Cloudflare Tunnel in the background and log output
Start-Process "cloudflared" -ArgumentList "tunnel run --url http://localhost:8000 nursery-mitra-backend" -RedirectStandardOutput $CloudflareLog -RedirectStandardError $CloudflareLog -WindowStyle Hidden
