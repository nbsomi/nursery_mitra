param (
    [Parameter(Mandatory=$true)]
    [string]$Version
)

Write-Host "============================================="
Write-Host " Nursery Mitra OTA Build Workflow"
Write-Host " Target Version: $Version"
Write-Host "============================================="

# 1. Update the OTA version in the backend
$otaFilePath = "backend\app\routers\ota.py"
Write-Host "`n[1/4] Updating backend OTA target version..."
if (Test-Path $otaFilePath) {
    $content = Get-Content $otaFilePath
    $content = $content -replace 'TARGET_APP_VERSION = ".*"', "TARGET_APP_VERSION = `"$Version`""
    Set-Content -Path $otaFilePath -Value $content
    Write-Host "  -> Updated ota.py to serve version $Version"
} else {
    Write-Host "  -> WARNING: Could not find $otaFilePath"
}

# 1.5 Update the version in pubspec.yaml
$pubspecPath = "pubspec.yaml"
Write-Host "`n[1.5/4] Updating pubspec.yaml target version..."
if (Test-Path $pubspecPath) {
    $content = Get-Content $pubspecPath
    $content = $content -replace '^version: .*', "version: $Version"
    Set-Content -Path $pubspecPath -Value $content
    Write-Host "  -> Updated pubspec.yaml to version $Version"
} else {
    Write-Host "  -> WARNING: Could not find $pubspecPath"
}

# 2. Build the Flutter APK
Write-Host "`n[2/4] Compiling Flutter Release APK (this may take a minute)..."
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "  -> ERROR: Flutter build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 3. Ensure the releases directory exists
Write-Host "`n[3/4] Preparing backend/releases directory..."
$releasesDir = "backend\releases"
if (-Not (Test-Path -Path $releasesDir)) {
    New-Item -ItemType Directory -Force -Path $releasesDir | Out-Null
    Write-Host "  -> Created directory: $releasesDir"
}

# 4. Copy the compiled APK to the backend
Write-Host "`n[4/4] Deploying APK to backend..."
$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$destApk = "$releasesDir\nurserymitra_$Version.apk"

if (Test-Path $sourceApk) {
    Copy-Item -Path $sourceApk -Destination $destApk -Force
    Write-Host "  -> Successfully copied APK to $destApk"
} else {
    Write-Host "  -> ERROR: Could not find compiled APK at $sourceApk" -ForegroundColor Red
    exit 1
}

Write-Host "`n============================================="
Write-Host " SUCCESS: Version $Version is now deployed locally!"
Write-Host " Restart your Uvicorn server to apply the changes."
Write-Host "============================================="
