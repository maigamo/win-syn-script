#Requires -Version 5.1
<#
.SYNOPSIS
    Multi-project sync script - Sync multiple Git repositories

.DESCRIPTION
    Read project configuration from projects-config.json and sync each project:
    - Support multiple project directories
    - Each project can have different branch
    - Run auto-sys-test.ps1 for each enabled project

.PARAMETER ConfigFile
    Path to configuration file, default: projects-config.json in script directory

.PARAMETER ProjectName
    Only sync specified project (by name)

.PARAMETER ListProjects
    List all configured projects

.EXAMPLE
    .\multi-project-sync.ps1
    Sync all enabled projects

.EXAMPLE
    .\multi-project-sync.ps1 -ProjectName "mc-shop-app"
    Sync only specified project

.EXAMPLE
    .\multi-project-sync.ps1 -ListProjects
    List all configured projects
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$ListProjects = $false
)

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Log file
$SYNC_LOG = Join-Path $PSScriptRoot "multi-sync.log"
$MAX_LOG_SIZE_MB = 10

function Write-SyncLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Check log size
    if ((Test-Path $SYNC_LOG) -and ((Get-Item $SYNC_LOG).Length / 1MB) -ge $MAX_LOG_SIZE_MB) {
        $backupLog = "$SYNC_LOG.old"
        if (Test-Path $backupLog) { Remove-Item $backupLog -Force }
        Move-Item $SYNC_LOG $backupLog -Force
    }
    
    # Write to log
    $logMessage | Out-File -Append -FilePath $SYNC_LOG -Encoding UTF8
    
    # Output to console
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
}

function Get-ProjectConfig {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-SyncLog "Config file not found: $Path" "ERROR"
        return $null
    }
    
    try {
        $content = Get-Content $Path -Raw -Encoding UTF8
        $config = $content | ConvertFrom-Json
        return $config
    } catch {
        Write-SyncLog "Failed to parse config file: $_" "ERROR"
        return $null
    }
}

function Show-Projects {
    param($Config)
    
    Write-Host ""
    Write-Host "========== Configured Projects ==========" -ForegroundColor Cyan
    Write-Host ""
    
    $index = 1
    foreach ($project in $Config.projects) {
        $status = if ($project.enabled) { "Enabled" } else { "Disabled" }
        $statusColor = if ($project.enabled) { "Green" } else { "Yellow" }
        
        Write-Host "[$index] " -NoNewline -ForegroundColor Gray
        Write-Host $project.name -ForegroundColor White
        Write-Host "    Status:     " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
        Write-Host "    Branch:     $($project.branch)"
        Write-Host "    Project:    $($project.projectDir)"
        Write-Host "    Target:     $($project.targetDir)"
        Write-Host ""
        $index++
    }
    
    Write-Host "Total: $($Config.projects.Count) projects" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-ProjectSync {
    param(
        [object]$Project,
        [string]$ScriptPath
    )
    
    Write-SyncLog "========== Syncing: $($Project.name) ==========" "INFO"
    Write-SyncLog "Branch: $($Project.branch)" "INFO"
    Write-SyncLog "Project Dir: $($Project.projectDir)" "INFO"
    
    if (-not $Project.enabled) {
        Write-SyncLog "Project is disabled, skipping" "WARNING"
        return @{ Success = $true; Skipped = $true }
    }
    
    if (-not (Test-Path $Project.projectDir)) {
        Write-SyncLog "Project directory not found: $($Project.projectDir)" "ERROR"
        return @{ Success = $false; Skipped = $false; Error = "Directory not found" }
    }
    
    # Create temporary script with project config
    $tempScript = Join-Path $env:TEMP "auto-sys-test-$($Project.name).ps1"
    
    # Read original script
    $scriptContent = Get-Content $ScriptPath -Raw -Encoding UTF8
    
    # Replace config values
    $scriptContent = $scriptContent -replace '\$PROJECT_DIR\s*=\s*"[^"]*"', "`$PROJECT_DIR = `"$($Project.projectDir)`""
    $scriptContent = $scriptContent -replace '\$TARGET_DIR\s*=\s*"[^"]*"', "`$TARGET_DIR = `"$($Project.targetDir)`""
    
    # Write temp script
    $scriptContent | Out-File -FilePath $tempScript -Encoding UTF8
    
    try {
        # Execute script
        $process = Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"", "-Branch", "`"$($Project.branch)`"" `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput "$env:TEMP\sync_$($Project.name)_out.txt" `
            -RedirectStandardError "$env:TEMP\sync_$($Project.name)_err.txt"
        
        # Read output
        $stdout = Get-Content "$env:TEMP\sync_$($Project.name)_out.txt" -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        # Log output
        if ($stdout) {
            $stdout.Split("`n") | Where-Object { $_.Trim() } | ForEach-Object {
                Write-SyncLog $_.Trim() "INFO"
            }
        }
        
        # Cleanup
        Remove-Item "$env:TEMP\sync_$($Project.name)_out.txt" -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\sync_$($Project.name)_err.txt" -ErrorAction SilentlyContinue
        Remove-Item $tempScript -ErrorAction SilentlyContinue
        
        if ($process.ExitCode -eq 0) {
            Write-SyncLog "Project $($Project.name) synced successfully" "SUCCESS"
            return @{ Success = $true; Skipped = $false }
        } else {
            Write-SyncLog "Project $($Project.name) sync completed with exit code: $($process.ExitCode)" "WARNING"
            return @{ Success = $false; Skipped = $false; ExitCode = $process.ExitCode }
        }
        
    } catch {
        Write-SyncLog "Error syncing project $($Project.name): $_" "ERROR"
        Remove-Item $tempScript -ErrorAction SilentlyContinue
        return @{ Success = $false; Skipped = $false; Error = $_.ToString() }
    }
}

# ==================== Main ====================

# Determine config file path
if (-not $ConfigFile) {
    $ConfigFile = Join-Path $PSScriptRoot "projects-config.json"
}

# Load config
$config = Get-ProjectConfig -Path $ConfigFile

if (-not $config) {
    Write-SyncLog "Failed to load configuration" "ERROR"
    exit 1
}

# List projects mode
if ($ListProjects) {
    Show-Projects -Config $config
    exit 0
}

# Get auto-sys-test.ps1 path
$autoSysTestScript = Join-Path $PSScriptRoot "auto-sys-test.ps1"
if (-not (Test-Path $autoSysTestScript)) {
    Write-SyncLog "auto-sys-test.ps1 not found: $autoSysTestScript" "ERROR"
    exit 1
}

Write-SyncLog "========================================" "INFO"
Write-SyncLog "Multi-Project Sync Started" "INFO"
Write-SyncLog "Config File: $ConfigFile" "INFO"
Write-SyncLog "========================================" "INFO"

$startTime = Get-Date
$results = @{
    Total = 0
    Success = 0
    Failed = 0
    Skipped = 0
}

# Filter projects if ProjectName specified
$projectsToSync = $config.projects
if ($ProjectName) {
    $projectsToSync = $config.projects | Where-Object { $_.name -eq $ProjectName }
    if (-not $projectsToSync) {
        Write-SyncLog "Project not found: $ProjectName" "ERROR"
        Write-SyncLog "Use -ListProjects to see available projects" "INFO"
        exit 1
    }
}

# Sync each project
foreach ($project in $projectsToSync) {
    $results.Total++
    
    $syncResult = Invoke-ProjectSync -Project $project -ScriptPath $autoSysTestScript
    
    if ($syncResult.Skipped) {
        $results.Skipped++
    } elseif ($syncResult.Success) {
        $results.Success++
    } else {
        $results.Failed++
    }
    
    Write-SyncLog "" "INFO"
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

# Summary
Write-Host ""
Write-Host "========== Sync Summary ==========" -ForegroundColor Cyan
Write-Host "Total Projects: $($results.Total)"
Write-Host "Successful:     " -NoNewline
Write-Host $results.Success -ForegroundColor Green
Write-Host "Failed:         " -NoNewline
Write-Host $results.Failed -ForegroundColor $(if ($results.Failed -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped:        " -NoNewline
Write-Host $results.Skipped -ForegroundColor Yellow
Write-Host "Duration:       $([Math]::Round($duration, 2)) seconds"
Write-Host "==================================" -ForegroundColor Cyan

Write-SyncLog "Sync completed - Success: $($results.Success), Failed: $($results.Failed), Skipped: $($results.Skipped)" "INFO"

if ($results.Failed -gt 0) {
    exit 1
}
exit 0

