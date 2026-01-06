#Requires -Version 5.1
<#
.SYNOPSIS
    自动构建和部署脚本

.DESCRIPTION
    监控 Git 仓库更新，自动拉取代码、安装依赖、复制构建文件

.PARAMETER Branch
    指定要拉取的分支名称，默认为 HEAD（当前分支）
    例如: .\auto-sys-test.ps1 -Branch "test"

.EXAMPLE
    .\auto-sys-test.ps1
    使用默认分支（当前分支）

.EXAMPLE
    .\auto-sys-test.ps1 -Branch "test"
    使用 test 分支

.EXAMPLE
    .\auto-sys-test.ps1 -Branch "main"
    使用 main 分支
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Branch = "HEAD"  # 默认使用当前分支
)

# 设置控制台输出编码为 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

<#  ==========  仅两处需要改  ==========  #>
$PROJECT_DIR = "F:\workspace\git_workspace\mc-after-sales-app\service-app"
$TARGET_DIR  = "F:\workspace\delivery\MiniProgram_Tester\after-sale-project\mp-weixin"
<#  ==========  配置结束  ==========  #>

# 日志配置
$LOG_FILE = Join-Path $PSScriptRoot "build.log"
$MAX_LOG_SIZE_MB = 10  # 日志文件最大大小（MB）
$MAX_LOG_BACKUPS = 5   # 保留的备份日志数量

$ErrorActionPreference = "Stop"

# 执行状态跟踪
$global:ExecutionSummary = @{
    StartTime = Get-Date
    EndTime = $null
    Status = "RUNNING"
    Steps = @()
    HasUpdate = $false
    ErrorMessage = $null
    Branch = $Branch
    LocalCommit = $null
    RemoteCommit = $null
}

# ==================== 日志管理函数 ====================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # 检查日志文件大小并轮转
    Rotate-LogFile
    
    # 写入日志
    $logMessage | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
    
    # 同时输出到控制台（带颜色）
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
}

function Rotate-LogFile {
    if (-not (Test-Path $LOG_FILE)) {
        return
    }
    
    $logFileInfo = Get-Item $LOG_FILE
    $fileSizeMB = $logFileInfo.Length / 1MB
    
    if ($fileSizeMB -ge $MAX_LOG_SIZE_MB) {
        Write-Host "[系统] 日志文件超过 ${MAX_LOG_SIZE_MB}MB，开始轮转..." -ForegroundColor Cyan
        
        # 删除最旧的备份
        $oldestBackup = "$LOG_FILE.$MAX_LOG_BACKUPS"
        if (Test-Path $oldestBackup) {
            Remove-Item $oldestBackup -Force
        }
        
        # 轮转现有备份
        for ($i = $MAX_LOG_BACKUPS - 1; $i -ge 1; $i--) {
            $oldFile = "$LOG_FILE.$i"
            $newFile = "$LOG_FILE.$($i + 1)"
            if (Test-Path $oldFile) {
                Move-Item $oldFile $newFile -Force
            }
        }
        
        # 重命名当前日志
        Move-Item $LOG_FILE "$LOG_FILE.1" -Force
        Write-Host "[系统] 日志轮转完成，旧日志备份为 build.log.1" -ForegroundColor Cyan
    }
}

function Add-ExecutionStep {
    param(
        [string]$StepName,
        [string]$Status,
        [string]$Message = ""
    )
    
    $global:ExecutionSummary.Steps += @{
        Name = $StepName
        Status = $Status
        Message = $Message
        Time = Get-Date -Format 'HH:mm:ss'
    }
}

function Show-ExecutionSummary {
    # 恢复到原始目录
    if ($ORIGINAL_DIR) {
        Set-Location $ORIGINAL_DIR -ErrorAction SilentlyContinue
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "==================== 执行摘要 ====================" -ForegroundColor Cyan
    
    $duration = ($global:ExecutionSummary.EndTime - $global:ExecutionSummary.StartTime).TotalSeconds
    
    Write-Host "开始时间: " -NoNewline
    Write-Host $global:ExecutionSummary.StartTime.ToString('yyyy-MM-dd HH:mm:ss') -ForegroundColor White
    
    Write-Host "结束时间: " -NoNewline
    Write-Host $global:ExecutionSummary.EndTime.ToString('yyyy-MM-dd HH:mm:ss') -ForegroundColor White
    
    Write-Host "执行耗时: " -NoNewline
    Write-Host "$([Math]::Round($duration, 2)) 秒" -ForegroundColor White
    
    Write-Host "目标分支: " -NoNewline
    Write-Host $global:ExecutionSummary.Branch -ForegroundColor Cyan
    
    if ($global:ExecutionSummary.LocalCommit) {
        Write-Host "本地版本: " -NoNewline
        Write-Host $global:ExecutionSummary.LocalCommit -ForegroundColor Gray
    }
    
    if ($global:ExecutionSummary.RemoteCommit) {
        Write-Host "远程版本: " -NoNewline
        Write-Host $global:ExecutionSummary.RemoteCommit -ForegroundColor Gray
    }
    
    Write-Host "最终状态: " -NoNewline
    switch ($global:ExecutionSummary.Status) {
        "SUCCESS" { Write-Host $global:ExecutionSummary.Status -ForegroundColor Green }
        "FAILED"  { Write-Host $global:ExecutionSummary.Status -ForegroundColor Red }
        "NO_UPDATE" { Write-Host $global:ExecutionSummary.Status -ForegroundColor Yellow }
        default { Write-Host $global:ExecutionSummary.Status -ForegroundColor White }
    }
    
    if ($global:ExecutionSummary.HasUpdate) {
        Write-Host "代码更新: " -NoNewline
        Write-Host "是" -ForegroundColor Green
    } else {
        Write-Host "代码更新: " -NoNewline
        Write-Host "否" -ForegroundColor Gray
    }
    
    Write-Host "`n步骤详情:" -ForegroundColor Cyan
    foreach ($step in $global:ExecutionSummary.Steps) {
        Write-Host "  [$($step.Time)] " -NoNewline -ForegroundColor Gray
        Write-Host "$($step.Name): " -NoNewline
        
        switch ($step.Status) {
            "SUCCESS" { Write-Host "✓ " -NoNewline -ForegroundColor Green; Write-Host $step.Status -ForegroundColor Green }
            "FAILED"  { Write-Host "✗ " -NoNewline -ForegroundColor Red; Write-Host $step.Status -ForegroundColor Red }
            "SKIPPED" { Write-Host "○ " -NoNewline -ForegroundColor Yellow; Write-Host $step.Status -ForegroundColor Yellow }
            default   { Write-Host $step.Status -ForegroundColor White }
        }
        
        if ($step.Message) {
            Write-Host "    └─ $($step.Message)" -ForegroundColor Gray
        }
    }
    
    if ($global:ExecutionSummary.ErrorMessage) {
        Write-Host "`n错误信息:" -ForegroundColor Red
        Write-Host "  $($global:ExecutionSummary.ErrorMessage)" -ForegroundColor Red
    }
    
    Write-Host "==================================================" -ForegroundColor Cyan
    
    # 同时写入日志
    "`n==================== 执行摘要 ====================" | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
    "开始时间: $($global:ExecutionSummary.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
    "结束时间: $($global:ExecutionSummary.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
    "执行耗时: $([Math]::Round($duration, 2)) 秒" | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
    "最终状态: $($global:ExecutionSummary.Status)" | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
    "代码更新: $(if ($global:ExecutionSummary.HasUpdate) { '是' } else { '否' })" | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
    "==================================================" | Out-File -Append -FilePath $LOG_FILE -Encoding UTF8
}

# ==================== 主流程 ====================

# 保存当前目录，以便执行完成后恢复
$ORIGINAL_DIR = Get-Location

Write-Log "===== 轮询开始 =====" "INFO"
Write-Log "项目目录: $PROJECT_DIR" "INFO"
Write-Log "目标目录: $TARGET_DIR" "INFO"
Write-Log "目标分支: $Branch" "INFO"

# 步骤1: 进入仓库
try {
    Set-Location $PROJECT_DIR
    Write-Log "成功切换到项目目录" "INFO"
    Add-ExecutionStep -StepName "切换项目目录" -Status "SUCCESS"
}
catch {
    Write-Log "项目目录不存在：$PROJECT_DIR" "ERROR"
    Add-ExecutionStep -StepName "切换项目目录" -Status "FAILED" -Message $_.Exception.Message
    $global:ExecutionSummary.Status = "FAILED"
    $global:ExecutionSummary.ErrorMessage = "项目目录不存在"
    $global:ExecutionSummary.EndTime = Get-Date
    Show-ExecutionSummary
    exit 1
}

# 步骤2: 检查远程更新
Write-Log "检查远程仓库更新..." "INFO"
try {
    # 根据分支参数确定要检查的引用
    if ($Branch -eq "HEAD") {
        # 获取当前分支名称
        $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1 | Out-String
        $currentBranch = $currentBranch.Trim()
        $gitRef = "refs/heads/$currentBranch"
        $targetBranch = $currentBranch
        Write-Log "使用当前分支: $currentBranch" "INFO"
    } else {
        $gitRef = "refs/heads/$Branch"
        $targetBranch = $Branch
        Write-Log "使用指定分支: $Branch" "INFO"
    }
    
    # 先执行 git fetch 更新远程跟踪分支
    # 使用 cmd /c 执行，将 stderr 合并到 stdout，避免 PowerShell 误判为错误
    Write-Log "正在获取远程更新..." "INFO"
    
    # 临时关闭错误停止
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    $fetchOutput = cmd /c "git fetch origin $targetBranch 2>&1"
    $fetchExitCode = $LASTEXITCODE
    
    # 记录 fetch 的输出
    if ($fetchOutput) {
        $fetchOutput | ForEach-Object { 
            $line = $_.ToString().Trim()
            if ($line) {
                Write-Log $line "INFO"
            }
        }
    }
    
    $ErrorActionPreference = $oldErrorAction
    
    # 只有在 fetch 真正失败时才报错（退出码非0）
    if ($fetchExitCode -ne 0) {
        Write-Log "Git fetch 失败，退出码: $fetchExitCode" "ERROR"
        throw "Git fetch 失败，退出码: $fetchExitCode"
    }
    
    # 获取远程 commit - 使用 git rev-parse 获取 fetch 后的远程跟踪分支
    # 这比 ls-remote 更可靠，因为它使用的是本地缓存的远程引用
    $REMOTE = git rev-parse "origin/$targetBranch" 2>&1 | Out-String
    $REMOTE = $REMOTE.Trim()
    
    if (-not $REMOTE -or $REMOTE -match "fatal:" -or $REMOTE -match "unknown revision") {
        # 如果 rev-parse 失败，回退到 ls-remote
        Write-Log "使用 ls-remote 获取远程版本..." "INFO"
        $lsRemoteOutput = git ls-remote origin $gitRef 2>&1 | Out-String
        if ($lsRemoteOutput -and $lsRemoteOutput.Trim()) {
            $REMOTE = ($lsRemoteOutput.Trim().Split("`t")[0]).Trim()
        }
    }
    
    if (-not $REMOTE -or $REMOTE.Length -lt 7) {
        throw "无法获取远程分支的信息，请检查分支名称是否正确"
    }
    
    # 获取本地 HEAD 的 commit（当前工作目录的实际版本）
    # 注意：不管指定什么分支，都应该获取当前 HEAD，因为这才是实际的本地状态
    $LOCAL = git rev-parse HEAD 2>&1 | Out-String
    $LOCAL = $LOCAL.Trim()
    
    # 保存到执行摘要（保存完整hash）
    $global:ExecutionSummary.LocalCommit = $LOCAL
    $global:ExecutionSummary.RemoteCommit = $REMOTE
    
    Write-Log "本地版本: $LOCAL" "INFO"
    Write-Log "远程版本: $REMOTE" "INFO"
    Add-ExecutionStep -StepName "检查远程更新" -Status "SUCCESS" -Message "本地:$LOCAL 远程:$REMOTE"
}
catch {
    Write-Log "Git 命令执行失败: $_" "ERROR"
    Add-ExecutionStep -StepName "检查远程更新" -Status "FAILED" -Message $_.Exception.Message
    $global:ExecutionSummary.Status = "FAILED"
    $global:ExecutionSummary.ErrorMessage = "Git 命令执行失败"
    $global:ExecutionSummary.EndTime = Get-Date
    Show-ExecutionSummary
    exit 1
}

# 步骤3: 判断是否有更新
if ($REMOTE -eq $LOCAL) {
    Write-Log "已是最新版本，无需构建" "SUCCESS"
    Add-ExecutionStep -StepName "版本检查" -Status "SKIPPED" -Message "无需更新"
    $global:ExecutionSummary.Status = "NO_UPDATE"
    $global:ExecutionSummary.EndTime = Get-Date
    Write-Log "===== 轮询结束 =====" "INFO"
    Show-ExecutionSummary
    exit 0
}

$global:ExecutionSummary.HasUpdate = $true

# 步骤4: 拉取代码
Write-Log "发现新提交，开始拉取..." "INFO"

try {
    # 临时关闭错误停止
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    # 获取 git 仓库根目录
    $gitRoot = git rev-parse --show-toplevel 2>&1 | Out-String
    $gitRoot = $gitRoot.Trim()
    Write-Log "Git 仓库根目录: $gitRoot" "INFO"
    
    # 检查当前分支
    $currentBranchName = git rev-parse --abbrev-ref HEAD 2>&1 | Out-String
    $currentBranchName = $currentBranchName.Trim()
    Write-Log "当前分支: $currentBranchName" "INFO"
    
    # 如果指定了分支且不是当前分支，先切换到该分支
    if ($Branch -ne "HEAD" -and $currentBranchName -ne $Branch) {
        Write-Log "需要从 $currentBranchName 切换到目标分支: $Branch" "INFO"
        
        # 先检查本地是否有该分支
        $localBranchCheck = cmd /c "git rev-parse --verify $Branch 2>&1"
        if ($LASTEXITCODE -ne 0) {
            # 本地分支不存在，从远程创建
            Write-Log "本地分支 $Branch 不存在，从远程创建..." "INFO"
            $checkoutOutput = cmd /c "git checkout -b $Branch origin/$Branch 2>&1"
        } else {
            # 本地分支存在，直接切换
            Write-Log "切换到本地分支 $Branch..." "INFO"
            $checkoutOutput = cmd /c "git checkout $Branch 2>&1"
        }
        
        if ($checkoutOutput) {
            $checkoutOutput | ForEach-Object { 
                $line = $_.ToString().Trim()
                if ($line) { Write-Log $line "INFO" }
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "切换分支失败"
        }
        
        # 验证切换是否成功
        $newBranchName = git rev-parse --abbrev-ref HEAD 2>&1 | Out-String
        $newBranchName = $newBranchName.Trim()
        Write-Log "切换后当前分支: $newBranchName" "INFO"
    } else {
        Write-Log "已在目标分支 $currentBranchName 上" "INFO"
    }
    
    # 执行 git pull（强制使用 rebase 或 merge 来更新本地分支）
    if ($Branch -eq "HEAD") {
        Write-Log "执行: git pull origin HEAD" "INFO"
        $pullOutput = cmd /c "git pull origin HEAD 2>&1"
    } else {
        # 先重置本地分支到远程分支（确保同步）
        Write-Log "执行: git reset --hard origin/$Branch" "INFO"
        $resetOutput = cmd /c "git reset --hard origin/$Branch 2>&1"
        if ($resetOutput) {
            $resetOutput | ForEach-Object { 
                $line = $_.ToString().Trim()
                if ($line) { Write-Log $line "INFO" }
            }
        }
    }
    $pullExitCode = $LASTEXITCODE
    
    $ErrorActionPreference = $oldErrorAction
    
    # 检查退出码
    if ($pullExitCode -ne 0) {
        throw "Git 操作返回非零退出码: $pullExitCode"
    }
    
    # 验证更新后的版本
    $newLocalCommit = git rev-parse HEAD 2>&1 | Out-String
    $newLocalCommit = $newLocalCommit.Trim()
    Write-Log "更新后本地版本: $newLocalCommit" "INFO"
    
    # 更新执行摘要中的本地版本
    $global:ExecutionSummary.LocalCommit = $newLocalCommit
    
    Write-Log "代码拉取成功" "SUCCESS"
    Add-ExecutionStep -StepName "拉取代码" -Status "SUCCESS"
}
catch {
    $ErrorActionPreference = $oldErrorAction
    Write-Log "代码拉取失败: $_" "ERROR"
    Add-ExecutionStep -StepName "拉取代码" -Status "FAILED" -Message $_.Exception.Message
    $global:ExecutionSummary.Status = "FAILED"
    $global:ExecutionSummary.ErrorMessage = "代码拉取失败"
    $global:ExecutionSummary.EndTime = Get-Date
    Show-ExecutionSummary
    exit 1
}

# 步骤5: 安装依赖
Write-Log "开始安装 npm 依赖..." "INFO"

# 检查是否需要清理旧的依赖（当 package-lock.json 有变化或 node_modules 损坏时）
$nodeModulesPath = Join-Path (Get-Location) "node_modules"

# 可选：检测是否需要清理依赖（根据 git diff 检查 package-lock.json 是否有变化）
$packageLockChanged = $false
$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $diffOutput = git diff --name-only HEAD~1 HEAD 2>&1 | Out-String
    if ($diffOutput -match "package-lock\.json" -or $diffOutput -match "package\.json") {
        $packageLockChanged = $true
        Write-Log "检测到 package.json 或 package-lock.json 有变化" "INFO"
    }
} catch {
    # 忽略错误，继续安装
}
$ErrorActionPreference = $oldErrorAction

# 如果依赖文件有变化，先清理旧的 node_modules
if ($packageLockChanged -and (Test-Path $nodeModulesPath)) {
    Write-Log "清理旧的 node_modules 目录..." "INFO"
    try {
        Remove-Item -Path $nodeModulesPath -Recurse -Force -ErrorAction Stop
        Write-Log "node_modules 清理完成" "INFO"
    } catch {
        Write-Log "清理 node_modules 失败: $_" "WARNING"
        # 继续执行，不中断流程
    }
}

# 使用 cmd /c 执行 npm 命令，将 stderr 合并到 stdout，避免 PowerShell 误判警告为错误
Write-Log "执行: npm install --legacy-peer-deps" "INFO"

# 临时关闭错误停止，因为 npm 的警告会输出到 stderr
$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"

# 使用 cmd /c 执行，2>&1 将 stderr 合并到 stdout
$npmOutput = cmd /c "npm install --legacy-peer-deps 2>&1"
$npmExitCode = $LASTEXITCODE

# 记录输出
if ($npmOutput) {
    $npmOutput | ForEach-Object { 
        $line = $_.ToString().Trim()
        if ($line) {
            if ($line -match "ERR!") {
                Write-Log $line "ERROR"
            } elseif ($line -match "warn|WARN") {
                Write-Log $line "WARNING"
            } else {
                Write-Log $line "INFO"
            }
        }
    }
}

# 只根据退出码判断是否失败
if ($npmExitCode -ne 0) {
    $ErrorActionPreference = $oldErrorAction
    Write-Log "npm install 失败，退出码: $npmExitCode" "ERROR"
    Add-ExecutionStep -StepName "安装依赖" -Status "FAILED" -Message "退出码: $npmExitCode"
    $global:ExecutionSummary.Status = "FAILED"
    $global:ExecutionSummary.ErrorMessage = "npm install 失败"
    $global:ExecutionSummary.EndTime = Get-Date
    Show-ExecutionSummary
    exit 1
}

# 安装额外的特定依赖
Write-Log "执行: npm install --legacy-peer-deps uni-simple-router uni-read-pages" "INFO"
$npmExtraOutput = cmd /c "npm install --legacy-peer-deps uni-simple-router uni-read-pages 2>&1"
$npmExtraExitCode = $LASTEXITCODE

# 记录输出
if ($npmExtraOutput) {
    $npmExtraOutput | ForEach-Object { 
        $line = $_.ToString().Trim()
        if ($line) {
            if ($line -match "ERR!") {
                Write-Log $line "ERROR"
            } elseif ($line -match "warn|WARN") {
                Write-Log $line "WARNING"
            } else {
                Write-Log $line "INFO"
            }
        }
    }
}

# 恢复错误处理设置
$ErrorActionPreference = $oldErrorAction

if ($npmExtraExitCode -ne 0) {
    Write-Log "npm install uni-simple-router uni-read-pages 失败，退出码: $npmExtraExitCode" "ERROR"
    Add-ExecutionStep -StepName "安装依赖" -Status "FAILED" -Message "退出码: $npmExtraExitCode"
    $global:ExecutionSummary.Status = "FAILED"
    $global:ExecutionSummary.ErrorMessage = "npm install 失败"
    $global:ExecutionSummary.EndTime = Get-Date
    Show-ExecutionSummary
    exit 1
}

Write-Log "依赖安装成功" "SUCCESS"
Add-ExecutionStep -StepName "安装依赖" -Status "SUCCESS"

# 步骤6: 检测并复制构建目录
$BUILD_DIR = Join-Path $PROJECT_DIR "unpackage\dist\dev\mp-weixin"
Write-Log "检测构建目录：$BUILD_DIR" "INFO"

$shouldCopy = $true

if (-not (Test-Path $BUILD_DIR)) {
    Write-Log "构建目录不存在，跳过复制" "WARNING"
    Add-ExecutionStep -StepName "复制构建目录" -Status "SKIPPED" -Message "构建目录不存在"
    $shouldCopy = $false
}

if ($shouldCopy) {
    Write-Log "获取构建目录最新修改时间..." "INFO"
    $LATEST_FILE = Get-ChildItem -Path $BUILD_DIR -Recurse -File -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1

    if (-not $LATEST_FILE) {
        Write-Log "无法获取目录修改时间，跳过复制" "WARNING"
        Add-ExecutionStep -StepName "复制构建目录" -Status "SKIPPED" -Message "无法获取修改时间"
        $shouldCopy = $false
    }
}

if ($shouldCopy) {
    $LAST_MODIFIED = $LATEST_FILE.LastWriteTime
    Write-Log "构建目录最新修改时间：$($LAST_MODIFIED.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"

    $diffHours = ([DateTime]::Now - $LAST_MODIFIED).TotalHours
    Write-Log "距离上次修改已过: $([Math]::Round($diffHours, 2)) 小时" "INFO"
    
    if ($diffHours -le 24) {
        Write-Log "构建目录在24小时内有更新，开始复制..." "INFO"

        if (-not (Test-Path $TARGET_DIR)) {
            Write-Log "创建目标目录：$TARGET_DIR" "INFO"
            New-Item -ItemType Directory -Path $TARGET_DIR | Out-Null
        }

        Write-Log "执行 robocopy 复制..." "INFO"
        $robocopyOutput = robocopy $BUILD_DIR $TARGET_DIR /E /IS /IT /PURGE /NFL /NDL /NP 2>&1
        $ROBOCOPY_CODE = $LASTEXITCODE

        if ($ROBOCOPY_CODE -ge 8) {
            Write-Log "复制失败，robocopy 返回码：$ROBOCOPY_CODE" "ERROR"
            $robocopyOutput | ForEach-Object { Write-Log $_ "ERROR" }
            Add-ExecutionStep -StepName "复制构建目录" -Status "FAILED" -Message "robocopy 返回码: $ROBOCOPY_CODE"
            $global:ExecutionSummary.Status = "FAILED"
            $global:ExecutionSummary.ErrorMessage = "文件复制失败"
            $global:ExecutionSummary.EndTime = Get-Date
            Show-ExecutionSummary
            exit 1
        }
        
        $copyStatus = switch ($ROBOCOPY_CODE) {
            0 { "无变化" }
            1 { "成功复制" }
            2 { "发现额外文件" }
            3 { "复制+额外文件" }
            default { "返回码: $ROBOCOPY_CODE" }
        }
        
        Write-Log "robocopy 返回码：$ROBOCOPY_CODE ($copyStatus)" "INFO"
        Write-Log "已复制构建目录到：$TARGET_DIR" "SUCCESS"
        Add-ExecutionStep -StepName "复制构建目录" -Status "SUCCESS" -Message $copyStatus
    }
    else {
        Write-Log "构建目录超过24小时未更新，跳过复制" "WARNING"
        Add-ExecutionStep -StepName "复制构建目录" -Status "SKIPPED" -Message "超过24小时未更新"
    }
}

# 完成
$global:ExecutionSummary.Status = "SUCCESS"
$global:ExecutionSummary.EndTime = Get-Date
Write-Log "===== 构建流程完成 =====" "SUCCESS"

# 显示执行摘要
Show-ExecutionSummary

exit 0
