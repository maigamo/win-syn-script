<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows"/>
  <img src="https://img.shields.io/badge/PowerShell-5.1+-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell"/>
  <img src="https://img.shields.io/badge/Git-Auto%20Sync-F05032?style=for-the-badge&logo=git&logoColor=white" alt="Git"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License"/>
</p>

<h1 align="center">🔄 Windows Git Auto Sync</h1>

<p align="center">
  <b>Automate your Git workflow. Sync multiple repositories effortlessly.</b>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-configuration">Configuration</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-scheduled-tasks">Scheduled Tasks</a> •
  <a href="./README_CN.md">中文文档</a>
</p>

---

## 😫 The Problem

> *"I'm tired of manually pulling code every time..."*
> 
> *"The test environment is always out of sync with the latest code..."*
> 
> *"I manage 10+ repositories and it's a nightmare to keep them updated..."*

**Sound familiar?** You're not alone.

## ✨ The Solution

**Windows Git Auto Sync** is a lightweight PowerShell toolkit that:

- 🔄 **Auto-syncs** your Git repositories on schedule
- 📦 **Batch manages** multiple projects with a single config file
- ⏰ **Runs silently** via Windows Task Scheduler
- 🎯 **Copies build outputs** to your target directories automatically

---

## 🚀 Features

| Feature | Description |
|---------|-------------|
| 🔁 **Multi-Repo Sync** | Sync unlimited repositories with one command |
| ⏱️ **Scheduled Execution** | Set it and forget it - runs hourly from 9AM to 1AM |
| 📋 **JSON Configuration** | Easy-to-edit project settings |
| 📝 **Smart Logging** | Auto-rotating logs with size limits |
| 🔔 **Status Monitoring** | Check sync status anytime |
| 🛡️ **Safe Operations** | Non-destructive pulls with conflict detection |

---

## 📦 Quick Start

### 1️⃣ Clone This Repository

```powershell
git clone https://github.com/yourusername/windows-git-auto-sync.git
cd windows-git-auto-sync
```

### 2️⃣ Configure Your Projects

Edit `projects-config.json`:

```json
{
    "projects": [
        {
            "name": "my-awesome-app",
            "enabled": true,
            "projectDir": "C:\\Projects\\my-awesome-app",
            "targetDir": "C:\\Deploy\\my-awesome-app\\dist",
            "branch": "main"
        }
    ]
}
```

### 3️⃣ Run Your First Sync

```powershell
.\multi-project-sync.ps1
```

### 4️⃣ (Optional) Set Up Scheduled Task

```powershell
# Run as Administrator
.\setup-multi-task.ps1 -TaskAction create
```

**Done!** 🎉 Your repositories will now sync automatically.

---

## ⚙️ Configuration

### Project Config Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Project identifier (for display & filtering) |
| `enabled` | boolean | Toggle sync on/off |
| `projectDir` | string | Path to your Git repository |
| `targetDir` | string | Where to copy build outputs |
| `branch` | string | Branch to sync |

### Example Configuration

```json
{
    "description": "Multi-project sync configuration",
    "projects": [
        {
            "name": "frontend-app",
            "enabled": true,
            "projectDir": "D:\\workspace\\frontend-app",
            "targetDir": "D:\\deploy\\frontend\\dist",
            "branch": "develop"
        },
        {
            "name": "backend-api",
            "enabled": true,
            "projectDir": "D:\\workspace\\backend-api",
            "targetDir": "D:\\deploy\\api",
            "branch": "main"
        }
    ]
}
```

---

## 📖 Usage

### 🔄 Sync All Projects

```powershell
.\multi-project-sync.ps1
```

### 🎯 Sync Specific Project

```powershell
.\multi-project-sync.ps1 -ProjectName "frontend-app"
```

### 📋 List All Projects

```powershell
.\multi-project-sync.ps1 -ListProjects
```

### 🔧 Single Project Sync (Legacy)

```powershell
.\auto-sys-test.ps1 -Branch "main"
```

---

## ⏰ Scheduled Tasks

### Create Task (Runs 9AM - 1AM, Hourly)

```powershell
# Requires Administrator privileges
.\setup-multi-task.ps1 -TaskAction create
```

### Manage Tasks

| Command | Description |
|---------|-------------|
| `.\setup-multi-task.ps1 -TaskAction status` | 📊 View task status |
| `.\setup-multi-task.ps1 -TaskAction run` | ▶️ Run immediately |
| `.\setup-multi-task.ps1 -TaskAction stop` | ⏹️ Stop running task |
| `.\setup-multi-task.ps1 -TaskAction remove` | 🗑️ Remove task |

---

## 🔐 Git Authentication Setup

For automated sync, configure passwordless Git access:

### Option 1: Personal Access Token (Recommended)

```powershell
# Set remote URL with token
git remote set-url origin https://username:TOKEN@github.com/user/repo.git
```

### Option 2: SSH Keys

```powershell
# Generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Add to your Git provider, then:
git remote set-url origin git@github.com:user/repo.git
```

### Option 3: Git Credential Manager

```powershell
git config --global credential.helper manager-core
```

---

## 📁 File Structure

```
📦 windows-git-auto-sync
├── 📄 auto-sys-test.ps1        # Single project sync script
├── 📄 multi-project-sync.ps1   # Multi-project sync script
├── 📄 setup-multi-task.ps1     # Multi-project task scheduler
├── 📄 setup-scheduled-task.ps1 # Single project task scheduler
├── 📄 auto-sync-daemon.ps1     # Daemon process for continuous sync
├── 📄 projects-config.json     # Project configuration
└── 📄 README.md                # You are here!
```

---

## 📋 Requirements

| Requirement | Version |
|-------------|---------|
| 💻 Windows | 10 / Server 2016+ |
| 🐚 PowerShell | 5.1+ |
| 🔧 Git | 2.x+ |
| 📦 Node.js | (Optional, for npm projects) |

---

## 🛠️ Troubleshooting

### Script Execution Disabled?

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Git Still Asking for Password?

```powershell
# Verify remote URL includes credentials
git remote -v

# Re-set with token
git remote set-url origin https://user:token@github.com/user/repo.git
```

### Task Not Running?

1. Ensure created with Administrator privileges
2. Check status: `.\setup-multi-task.ps1 -TaskAction status`
3. Review Windows Event Viewer → Task Scheduler logs

---

## 📄 License

MIT License - Feel free to use, modify, and distribute.

---

<p align="center">
  <b>⭐ Star this repo if it saved you time!</b>
</p>

<p align="center">
  Made with ❤️ for developers who value automation
</p>

