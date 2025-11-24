<#
PowerShell packaging script for YTP Windows app
Usage examples (run from repo root):
  # Basic: package for win-x64
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-windows.ps1

  # With options:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-windows.ps1 -Runtime win-x86 -PublishTrim $true

This script will:
- dotnet publish the `src\YTP.WindowsUI\YTP.WindowsUI.csproj` project
- place published files under artifacts\publish\YTP.WindowsUI-<rid>\
- compress the publish folder to artifacts\publish\YTP.WindowsUI-<rid>.zip
#>

param(
    [string]$Project = "src\YTP.WindowsUI\YTP.WindowsUI.csproj",
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [bool]$SelfContained = $true,
    [bool]$SingleFile = $true,
    [object]$PublishTrim = $false,
    [string]$OutputRoot = "artifacts\publish"
)

# Normalize paths
$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot $Project
$publishDir = Join-Path $repoRoot (Join-Path $OutputRoot "YTP.WindowsUI-$Runtime")
$zipPath = Join-Path $repoRoot (Join-Path $OutputRoot "YTP.WindowsUI-$Runtime.zip")

Write-Host "Packaging project: $projectPath" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration, Runtime: $Runtime, SelfContained: $SelfContained, SingleFile: $SingleFile, Trim: $PublishTrim" -ForegroundColor DarkCyan

if (-Not (Test-Path $projectPath)) {
    Write-Error "Project file not found: $projectPath"
    exit 2
}

# Ensure output root exists
$fullOutputRoot = Join-Path $repoRoot $OutputRoot
New-Item -ItemType Directory -Force -Path $fullOutputRoot | Out-Null

# Clean previous publish
if (Test-Path $publishDir) {
    Write-Host "Removing existing publish directory: $publishDir" -ForegroundColor Yellow
    Remove-Item -Recurse -Force -LiteralPath $publishDir
}

# Build/publish
$scParams = @()
$scParams += "-c"; $scParams += $Configuration
$scParams += "-r"; $scParams += $Runtime
$scParams += "-o"; $scParams += $publishDir
$scParams += "--nologo"

# Coerce PublishTrim to boolean to be tolerant of string input from different PowerShell hosts
if (-not ($PublishTrim -is [bool])) {
    try {
        $PublishTrim = [System.Management.Automation.LanguagePrimitives]::ConvertTo($PublishTrim, [bool])
    } catch {
        Write-Host "Warning: could not convert PublishTrim value '$PublishTrim' to boolean; defaulting to False" -ForegroundColor Yellow
        $PublishTrim = $false
    }
}

# Additional MSBuild properties
$msbuildProps = "-p:SelfContained=$SelfContained"
if ($SingleFile) { $msbuildProps += " -p:PublishSingleFile=true" }
if ($PublishTrim) { $msbuildProps += " -p:PublishTrimmed=true" }
# recommend disabling ready-to-run for best single-file behavior on some projects
# $msbuildProps += " -p:PublishReadyToRun=false"

$cmd = "dotnet publish `"$projectPath`" $($scParams -join ' ') $msbuildProps"
Write-Host "Running: $cmd" -ForegroundColor Gray

if (-not ($PublishTrim -is [bool])) {
    try {
        $PublishTrim = [System.Management.Automation.LanguagePrimitives]::ConvertTo($PublishTrim, [bool])
    } catch {
        Write-Host "Warning: could not convert PublishTrim value '$PublishTrim' to boolean; defaulting to False" -ForegroundColor Yellow
        $PublishTrim = $false
    }
}

$publishResult = & dotnet publish $projectPath -c $Configuration -r $Runtime -o $publishDir --nologo $msbuildProps
if ($LASTEXITCODE -ne 0) {
    # Write-Error does not support ForegroundColor in Windows PowerShell 5.1.
    # Use Write-Host for colored output and exit with the publish exit code.
    Write-Host "dotnet publish failed (exit $LASTEXITCODE). See output above." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Create zip
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Write-Host "Compressing publish output to: $zipPath" -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $publishDir '*') -DestinationPath $zipPath -Force

Write-Host "Packaging complete." -ForegroundColor Green
Write-Host "Publish folder: $publishDir" -ForegroundColor Green
Write-Host "Zip artifact: $zipPath" -ForegroundColor Green

exit 0
