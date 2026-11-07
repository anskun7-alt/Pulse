# ==============================================================================
# Build Script - Pulse Media Player Windows Installer
# ==============================================================================
# Usage: powershell -ExecutionPolicy Bypass -File .\windows\build_installer.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

Write-Host "`n🚀 Building Pulse Media Player Windows Release..." -ForegroundColor Cyan

# Check for Inno Setup compiler
$isccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
    "C:\Program Files\Inno Setup 5\ISCC.exe"
)

$isccExe = $null
foreach ($path in $isccPaths) {
    if (Test-Path $path) {
        $isccExe = $path
        break
    }
}

if (-not $isccExe) {
    $commandCheck = Get-Command iscc.exe -ErrorAction SilentlyContinue
    if ($commandCheck) {
        $isccExe = $commandCheck.Source
    }
}

if (-not $isccExe) {
    Write-Error "❌ Inno Setup Compiler (ISCC.exe) not found. Please install Inno Setup 6 from https://jrsoftware.org/isdl.php"
    exit 1
}

Write-Host "✅ Found Inno Setup Compiler: $isccExe" -ForegroundColor Green

# 1. Build Flutter Windows Release Bundle
Write-Host "`n🔨 Running 'flutter build windows --release'..." -ForegroundColor Yellow
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Flutter Windows build failed."
    exit 1
}

# 2. Compile Inno Setup Script from project root
$projectRoot = Split-Path -Parent $PSScriptRoot
$issPath = Join-Path $projectRoot "installer_media_player_x64.iss"
Write-Host "`n📦 Compiling Inno Setup script: $issPath..." -ForegroundColor Yellow
& "$isccExe" "$issPath"

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Inno Setup compilation failed."
    exit 1
}

Write-Host "`n🎉 Setup installer built successfully!" -ForegroundColor Green
Write-Host "📂 Location: installer\" -ForegroundColor Cyan
