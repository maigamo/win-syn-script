#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Task Scheduler Management Script

.DESCRIPTION
    Manage Windows scheduled tasks for auto-sys-test.ps1:
    - Create scheduled task (9:00 AM - 1:00 AM, hourly)
    - Remove scheduled task
    - View task status
    - Stop running task
    - Run task immediately

.PARAMETER Action
    Action type: create, remove, status, stop, run
    Default: create

.PARAMETER ScriptPath
    Path to auto-sys-test.ps1 script
    
.PARAMETER Branch
    Target branch name, default: test

.PARAMETER TaskName
    Scheduled task name, default: AutoSysTest

.PARAMETER Remove
    [Deprecated] Use -Action remove instead

.EXAMPLE
    .\setup-scheduled-task.ps1 -Action create -Branch "test"

.EXAMPLE
    .\setup-scheduled-task.ps1 -Action remove

.EXAMPLE
    .\setup-scheduled-task.ps1 -Action status

.EXAMPLE
    .\setup-scheduled-task.ps1 -Action stop

.EXAMPLE
    .\setup-scheduled-task.ps1 -Action run

.NOTES
    Requires Administrator privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("create", "remove", "status", "stop", "run")]
    [string]$Action = "create",
    
    [Parameter(Mandatory=$false)]
    [string]$ScriptPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "test",
    
    [Parameter(Mandatory=$false)]
    [string]$TaskName = "AutoSysTest",
    
    [Parameter(Mandatory=$false)]
    [switch]$Remove = $false
)

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-ColorLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
}

# Compatible with old -Remove parameter
if ($Remove) {
    $Action = "remove"
}

# Show task status
function Show-TaskStatus {
    Write-Host ""
    Write-Host "========== Scheduled Task Status ==========" -ForegroundColor Cyan
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if (-not $task) {
        Write-Host "Task Name: $TaskName"
        Write-Host "Status: " -NoNewline
        Write-Host "Not Found" -ForegroundColor Yellow
        Write-Host "===========================================" -ForegroundColor Cyan
        return
    }
    
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    
    Write-Host "Task Name: $TaskName"
    Write-Host "Status: " -NoNewline
    
    switch ($task.State) {
        "Ready" { Write-Host "Ready" -ForegroundColor Green }
        "Running" { Write-Host "Running" -ForegroundColor Cyan }
        "Disabled" { Write-Host "Disabled" -ForegroundColor Yellow }
        default { Write-Host $task.State -ForegroundColor White }
    }
    
    Write-Host "Description: $($task.Description)"
    
    if ($taskInfo.LastRunTime -and $taskInfo.LastRunTime -ne [DateTime]::MinValue) {
        Write-Host "Last Run: $($taskInfo.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Host "Last Result: $($taskInfo.LastTaskResult)"
    } else {
        Write-Host "Last Run: Never"
    }
    
    if ($taskInfo.NextRunTime -and $taskInfo.NextRunTime -ne [DateTime]::MinValue) {
        Write-Host "Next Run: $($taskInfo.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    }
    
    Write-Host "Triggers: $($task.Triggers.Count)"
    
    Write-Host ""
    Write-Host "Management Commands:" -ForegroundColor Cyan
    Write-Host "  View Status: .\setup-scheduled-task.ps1 -Action status"
    Write-Host "  Run Now:     .\setup-scheduled-task.ps1 -Action run"
    Write-Host "  Stop Task:   .\setup-scheduled-task.ps1 -Action stop"
    Write-Host "  Remove Task: .\setup-scheduled-task.ps1 -Action remove"
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Stop running task
function Stop-RunningTask {
    Write-ColorLog "Stopping scheduled task: $TaskName" "INFO"
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if (-not $task) {
        Write-ColorLog "Task '$TaskName' does not exist" "WARNING"
        return
    }
    
    if ($task.State -ne "Running") {
        Write-ColorLog "Task is not running (State: $($task.State))" "WARNING"
        return
    }
    
    try {
        Stop-ScheduledTask -TaskName $TaskName
        Write-ColorLog "Task '$TaskName' stopped successfully" "SUCCESS"
    } catch {
        Write-ColorLog "Failed to stop task: $_" "ERROR"
    }
}

# Run task immediately
function Start-TaskNow {
    Write-ColorLog "Starting scheduled task: $TaskName" "INFO"
    
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if (-not $task) {
        Write-ColorLog "Task '$TaskName' does not exist" "ERROR"
        return
    }
    
    if ($task.State -eq "Running") {
        Write-ColorLog "Task is already running" "WARNING"
        return
    }
    
    try {
        Start-ScheduledTask -TaskName $TaskName
        Write-ColorLog "Task '$TaskName' started successfully" "SUCCESS"
    } catch {
        Write-ColorLog "Failed to start task: $_" "ERROR"
    }
}

# Remove task
function Remove-Task {
    Write-ColorLog "Removing scheduled task: $TaskName" "INFO"
    
    try {
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            # Stop if running
            if ($existingTask.State -eq "Running") {
                Write-ColorLog "Task is running, stopping first..." "INFO"
                Stop-ScheduledTask -TaskName $TaskName
                Start-Sleep -Seconds 2
            }
            
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-ColorLog "Task '$TaskName' removed successfully" "SUCCESS"
        } else {
            Write-ColorLog "Task '$TaskName' does not exist" "WARNING"
        }
    } catch {
        Write-ColorLog "Failed to remove task: $_" "ERROR"
        exit 1
    }
}

# Execute action
switch ($Action) {
    "remove" {
        Remove-Task
        exit 0
    }
    "status" {
        Show-TaskStatus
        exit 0
    }
    "stop" {
        Stop-RunningTask
        exit 0
    }
    "run" {
        Start-TaskNow
        exit 0
    }
    # "create" continues below
}

# Validate script path
if (-not $ScriptPath) {
    $ScriptPath = Join-Path $PSScriptRoot "auto-sys-test.ps1"
}

if (-not (Test-Path $ScriptPath)) {
    Write-ColorLog "Script file not found: $ScriptPath" "ERROR"
    Write-ColorLog "Please specify correct path with -ScriptPath parameter" "ERROR"
    exit 1
}

$ScriptPath = (Resolve-Path $ScriptPath).Path
$ScriptDir = Split-Path -Parent $ScriptPath

Write-ColorLog "========== Creating Scheduled Task ==========" "INFO"
Write-ColorLog "Script Path: $ScriptPath" "INFO"
Write-ColorLog "Target Branch: $Branch" "INFO"
Write-ColorLog "Task Name: $TaskName" "INFO"

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-ColorLog "Task '$TaskName' already exists, removing first" "WARNING"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-ColorLog "Old task removed" "INFO"
}

# Create triggers - 9:00 AM to 1:00 AM (next day), hourly
$triggers = @()

# 9:00 to 23:00
for ($hour = 9; $hour -le 23; $hour++) {
    $timeString = "{0:D2}:00:00" -f $hour
    $trigger = New-ScheduledTaskTrigger -Daily -At $timeString
    $triggers += $trigger
}

# 00:00 and 01:00
$triggers += New-ScheduledTaskTrigger -Daily -At "00:00:00"
$triggers += New-ScheduledTaskTrigger -Daily -At "01:00:00"

Write-ColorLog "Configured $($triggers.Count) trigger points (9:00-01:00, hourly)" "INFO"

# Create task action
$taskAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Branch `"$Branch`"" `
    -WorkingDirectory $ScriptDir

# Create task settings
$taskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Create task principal
$taskPrincipal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

# Register task
try {
    $newTask = Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $taskAction `
        -Trigger $triggers `
        -Settings $taskSettings `
        -Principal $taskPrincipal `
        -Description "Auto sync Git repository (Branch: $Branch)"
    
    Write-ColorLog "Task '$TaskName' created successfully!" "SUCCESS"
    Write-ColorLog "" "INFO"
    Write-ColorLog "========== Task Details ==========" "INFO"
    Write-ColorLog "Task Name: $TaskName" "INFO"
    Write-ColorLog "Script: $ScriptPath" "INFO"
    Write-ColorLog "Branch: $Branch" "INFO"
    Write-ColorLog "Schedule: Daily 9:00-01:00, hourly" "INFO"
    Write-ColorLog "User: $env:USERNAME" "INFO"
    Write-ColorLog "" "INFO"
    Write-ColorLog "Management Commands:" "INFO"
    Write-ColorLog "  View Status: .\setup-scheduled-task.ps1 -Action status" "INFO"
    Write-ColorLog "  Run Now:     .\setup-scheduled-task.ps1 -Action run" "INFO"
    Write-ColorLog "  Stop Task:   .\setup-scheduled-task.ps1 -Action stop" "INFO"
    Write-ColorLog "  Remove Task: .\setup-scheduled-task.ps1 -Action remove" "INFO"
    Write-ColorLog "==================================" "INFO"
    
} catch {
    Write-ColorLog "Failed to create task: $_" "ERROR"
    exit 1
}

exit 0
