#Requires -Version 5.1
<#
.SYNOPSIS
    Daemon process for auto-sys-test.ps1, periodic repository update detection

.DESCRIPTION
    Run as daemon process:
    - Check repository updates hourly
    - Only execute within specified time range (default 9:00-01:00)
    - Support background running
    - No administrator privileges required
    - Support graceful shutdown

.PARAMETER ScriptPath
    Full path to auto-sys-test.ps1 script
    
.PARAMETER Branch
    Target branch name, default: test

.PARAMETER IntervalMinutes
    Check interval in minutes, default: 60

.PARAMETER StartHour
    Start hour, default: 9

.PARAMETER EndHour
    End hour, default: 1 (1:00 AM next day)

.PARAMETER RunOnce
    Run detection only once, do not loop

.EXAMPLE
    .\daemon-manager.ps1 -Action start -Background
    Recommended: Use manager to start daemon in background

.EXAMPLE
    .\daemon-manager.ps1 -Action stop
    Recommended: Use manager to stop daemon

.EXAMPLE
    .\daemon-manager.ps1 -Action status
    Recommended: View daemon status

.NOTES
    Recommend using daemon-manager.ps1 to manage daemon start/stop
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ScriptPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "test",
    
    [Parameter(Mandatory=$false)]
    [int]$IntervalMinutes = 60,
    
    [Parameter(Mandatory=$false)]
    [int]$StartHour = 9,
    
    [Parameter(Mandatory=$false)]
    [int]$EndHour = 1,
    
    [Parameter(Mandatory=$false)]
    [switch]$RunOnce = $false
)

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Log file and PID file
$DAEMON_LOG = Join-Path $PSScriptRoot "daemon.log"
$PID_FILE = Join-Path $PSScriptRoot "daemon.pid"
$MAX_LOG_SIZE_MB = 5

# Global stop flag
$global:StopRequested = $false

function Write-DaemonLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Check log size
    if ((Test-Path $DAEMON_LOG) -and ((Get-Item $DAEMON_LOG).Length / 1MB) -ge $MAX_LOG_SIZE_MB) {
        $backupLog = "$DAEMON_LOG.old"
        if (Test-Path $backupLog) { Remove-Item $backupLog -Force }
        Move-Item $DAEMON_LOG $backupLog -Force
    }
    
    # Write to log
    $logMessage | Out-File -Append -FilePath $DAEMON_LOG -Encoding UTF8
    
    # Output to console
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
}

function Test-WithinActiveHours {
    param(
        [int]$Start,
        [int]$End
    )
    
    $currentHour = (Get-Date).Hour
    
    # Handle cross-midnight case (e.g., 9:00 - 01:00)
    if ($Start -gt $End) {
        # Cross midnight: current hour >= start OR current hour <= end
        return ($currentHour -ge $Start) -or ($currentHour -le $End)
    } else {
        # Same day: current hour between start and end
        return ($currentHour -ge $Start) -and ($currentHour -le $End)
    }
}

function Invoke-SyncScript {
    param(
        [string]$Path,
        [string]$TargetBranch
    )
    
    Write-DaemonLog "Starting sync script..." "INFO"
    
    try {
        $scriptDir = Split-Path -Parent $Path
        
        # Execute script
        $process = Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$Path`"", "-Branch", "`"$TargetBranch`"" `
            -WorkingDirectory $scriptDir `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput "$env:TEMP\sync_out.txt" `
            -RedirectStandardError "$env:TEMP\sync_err.txt"
        
        # Read output
        $stdout = Get-Content "$env:TEMP\sync_out.txt" -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $stderr = Get-Content "$env:TEMP\sync_err.txt" -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        # Log output
        if ($stdout) {
            $stdout.Split("`n") | Where-Object { $_.Trim() } | ForEach-Object {
                Write-DaemonLog $_.Trim() "INFO"
            }
        }
        
        # Cleanup temp files
        Remove-Item "$env:TEMP\sync_out.txt" -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\sync_err.txt" -ErrorAction SilentlyContinue
        
        if ($process.ExitCode -eq 0) {
            Write-DaemonLog "Sync script completed successfully" "SUCCESS"
            return $true
        } else {
            Write-DaemonLog "Sync script completed with exit code: $($process.ExitCode)" "WARNING"
            return $false
        }
        
    } catch {
        Write-DaemonLog "Error executing sync script: $_" "ERROR"
        return $false
    }
}

# Cleanup function
function Cleanup-Daemon {
    Write-DaemonLog "Cleaning up daemon..." "INFO"
    
    # Delete PID file
    if (Test-Path $PID_FILE) {
        Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
        Write-DaemonLog "PID file deleted" "INFO"
    }
    
    Write-DaemonLog "========== Daemon Stopped ==========" "INFO"
}

# Register exit event handler
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Cleanup-Daemon
} -ErrorAction SilentlyContinue | Out-Null

# ==================== Main ====================

# Validate script path
if (-not $ScriptPath) {
    $ScriptPath = Join-Path $PSScriptRoot "auto-sys-test.ps1"
}

if (-not (Test-Path $ScriptPath)) {
    Write-DaemonLog "Script file not found: $ScriptPath" "ERROR"
    exit 1
}

$ScriptPath = (Resolve-Path $ScriptPath).Path

# Write PID file
$PID | Out-File -FilePath $PID_FILE -Encoding UTF8 -NoNewline

Write-DaemonLog "========== Daemon Started ==========" "INFO"
Write-DaemonLog "Script Path: $ScriptPath" "INFO"
Write-DaemonLog "Target Branch: $Branch" "INFO"
Write-DaemonLog "Check Interval: $IntervalMinutes minutes" "INFO"
Write-DaemonLog "Active Hours: $StartHour:00 - $EndHour:00" "INFO"
Write-DaemonLog "Process PID: $PID" "INFO"
Write-DaemonLog "PID File: $PID_FILE" "INFO"
Write-DaemonLog "====================================" "INFO"

# Run once mode
if ($RunOnce) {
    Write-DaemonLog "Single run mode" "INFO"
    
    if (Test-WithinActiveHours -Start $StartHour -End $EndHour) {
        Invoke-SyncScript -Path $ScriptPath -TargetBranch $Branch
    } else {
        Write-DaemonLog "Not within active hours, skipping" "WARNING"
    }
    
    Write-DaemonLog "Single run completed" "INFO"
    Cleanup-Daemon
    exit 0
}

# Loop mode
$loopCount = 0
try {
    while (-not $global:StopRequested) {
        $loopCount++
        $currentTime = Get-Date
        
        Write-DaemonLog "===== Check #$loopCount =====" "INFO"
        
        if (Test-WithinActiveHours -Start $StartHour -End $EndHour) {
            Write-DaemonLog "Within active hours, starting check..." "INFO"
            Invoke-SyncScript -Path $ScriptPath -TargetBranch $Branch
        } else {
            Write-DaemonLog "Current time $($currentTime.ToString('HH:mm')) not within active hours ($StartHour:00 - $EndHour:00), skipping" "WARNING"
        }
        
        # Calculate next run time
        $nextRun = $currentTime.AddMinutes($IntervalMinutes)
        Write-DaemonLog "Next check: $($nextRun.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"
        Write-DaemonLog "Waiting $IntervalMinutes minutes..." "INFO"
        
        # Wait in segments to respond to stop requests
        $waitSeconds = $IntervalMinutes * 60
        $waitInterval = 10  # Check every 10 seconds
        $waited = 0
        
        while ($waited -lt $waitSeconds -and -not $global:StopRequested) {
            $sleepTime = [Math]::Min($waitInterval, $waitSeconds - $waited)
            Start-Sleep -Seconds $sleepTime
            $waited += $sleepTime
        }
    }
} finally {
    Cleanup-Daemon
}
