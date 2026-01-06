#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Setup Windows Scheduled Task for Multi-Project Sync

.DESCRIPTION
    Create Windows scheduled task to run multi-project-sync.ps1:
    - Daily 9:00 AM to 1:00 AM, hourly
    - Sync all enabled projects in projects-config.json

.PARAMETER TaskAction
    Action: create, remove, status, stop, run
    Default: create

.PARAMETER TaskName
    Task name, default: AutoMultiProjectSync

.EXAMPLE
    .\setup-multi-task.ps1 -TaskAction create

.EXAMPLE
    .\setup-multi-task.ps1 -TaskAction status

.EXAMPLE
    .\setup-multi-task.ps1 -TaskAction remove
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("create", "remove", "status", "stop", "run")]
    [string]$TaskAction = "create",
    
    [Parameter(Mandatory=$false)]
    [string]$TaskName = "AutoMultiProjectSync"
)

# Set console encoding
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
    Write-Host "  View Status: .\setup-multi-task.ps1 -TaskAction status"
    Write-Host "  Run Now:     .\setup-multi-task.ps1 -TaskAction run"
    Write-Host "  Stop Task:   .\setup-multi-task.ps1 -TaskAction stop"
    Write-Host "  Remove Task: .\setup-multi-task.ps1 -TaskAction remove"
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
switch ($TaskAction) {
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
}

# Create task
$ScriptPath = Join-Path $PSScriptRoot "multi-project-sync.ps1"
$ScriptDir = $PSScriptRoot

if (-not (Test-Path $ScriptPath)) {
    Write-ColorLog "Script not found: $ScriptPath" "ERROR"
    exit 1
}

Write-ColorLog "========== Creating Multi-Project Scheduled Task ==========" "INFO"
Write-ColorLog "Script Path: $ScriptPath" "INFO"
Write-ColorLog "Task Name: $TaskName" "INFO"

# Check if task exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-ColorLog "Task '$TaskName' already exists, removing first" "WARNING"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-ColorLog "Old task removed" "INFO"
}

# Create triggers - 9:00 AM to 1:00 AM, hourly
$triggers = @()

for ($hour = 9; $hour -le 23; $hour++) {
    $timeString = "{0:D2}:00:00" -f $hour
    $trigger = New-ScheduledTaskTrigger -Daily -At $timeString
    $triggers += $trigger
}

$triggers += New-ScheduledTaskTrigger -Daily -At "00:00:00"
$triggers += New-ScheduledTaskTrigger -Daily -At "01:00:00"

Write-ColorLog "Configured $($triggers.Count) trigger points (9:00-01:00, hourly)" "INFO"

# Create action
$schedAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
    -WorkingDirectory $ScriptDir

# Create settings
$schedSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

# Create principal
$schedPrincipal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

# Register task
try {
    $newTask = Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $schedAction `
        -Trigger $triggers `
        -Settings $schedSettings `
        -Principal $schedPrincipal `
        -Description "Auto sync multiple Git repositories (9:00-01:00, hourly)"
    
    Write-ColorLog "Task '$TaskName' created successfully!" "SUCCESS"
    Write-ColorLog "" "INFO"
    Write-ColorLog "========== Task Details ==========" "INFO"
    Write-ColorLog "Task Name: $TaskName" "INFO"
    Write-ColorLog "Script: $ScriptPath" "INFO"
    Write-ColorLog "Schedule: Daily 9:00-01:00, hourly" "INFO"
    Write-ColorLog "User: $env:USERNAME" "INFO"
    Write-ColorLog "" "INFO"
    Write-ColorLog "To configure projects, edit: projects-config.json" "INFO"
    Write-ColorLog "" "INFO"
    Write-ColorLog "Management Commands:" "INFO"
    Write-ColorLog "  View Status:    .\setup-multi-task.ps1 -TaskAction status" "INFO"
    Write-ColorLog "  Run Now:        .\setup-multi-task.ps1 -TaskAction run" "INFO"
    Write-ColorLog "  Stop Task:      .\setup-multi-task.ps1 -TaskAction stop" "INFO"
    Write-ColorLog "  Remove Task:    .\setup-multi-task.ps1 -TaskAction remove" "INFO"
    Write-ColorLog "  List Projects:  .\multi-project-sync.ps1 -ListProjects" "INFO"
    Write-ColorLog "==================================" "INFO"
    
} catch {
    Write-ColorLog "Failed to create task: $_" "ERROR"
    exit 1
}

exit 0

