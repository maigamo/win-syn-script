<p align="center">
  <img src="https://img.shields.io/badge/平台-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows"/>
  <img src="https://img.shields.io/badge/PowerShell-5.1+-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell"/>
  <img src="https://img.shields.io/badge/Git-自动同步-F05032?style=for-the-badge&logo=git&logoColor=white" alt="Git"/>
  <img src="https://img.shields.io/badge/开源协议-MIT-green?style=for-the-badge" alt="License"/>
</p>

<h1 align="center">🔄 Windows Git 自动同步工具</h1>

<p align="center">
  <b>告别手动拉取代码，让 Git 仓库自动保持最新</b>
</p>

<p align="center">
  <a href="#-功能特性">功能特性</a> •
  <a href="#-快速开始">快速开始</a> •
  <a href="#-配置说明">配置说明</a> •
  <a href="#-使用方法">使用方法</a> •
  <a href="#-定时任务">定时任务</a> •
  <a href="./README.md">English</a>
</p>

---

## 😫 你是否也有这些烦恼？

> *"每次都要手动 git pull，太麻烦了..."*
> 
> *"测试环境的代码总是忘记更新..."*
> 
> *"管理十几个仓库，每天光拉代码就要花半小时..."*

**如果你也有这些困扰，这个工具就是为你准备的！**

## ✨ 解决方案

**Windows Git 自动同步工具** 是一套轻量级 PowerShell 脚本，帮你：

- 🔄 **定时自动同步** Git 仓库
- 📦 **批量管理** 多个项目，一个配置文件搞定
- ⏰ **后台静默运行**，通过 Windows 计划任务自动执行
- 🎯 **自动复制构建产物** 到指定目录

---

## 🚀 功能特性

| 功能 | 说明 |
|------|------|
| 🔁 **多仓库同步** | 一条命令同步所有仓库 |
| ⏱️ **定时执行** | 设置后自动运行，每天 9:00-01:00 每小时执行 |
| 📋 **JSON 配置** | 简单易懂的配置文件 |
| 📝 **智能日志** | 自动轮转，不占用过多磁盘空间 |
| 🔔 **状态监控** | 随时查看同步状态 |
| 🛡️ **安全操作** | 非破坏性拉取，自动检测冲突 |

---

## 📦 快速开始

### 1️⃣ 下载脚本

```powershell
git clone https://github.com/yourusername/windows-git-auto-sync.git
cd windows-git-auto-sync
```

### 2️⃣ 配置你的项目

编辑 `projects-config.json`：

```json
{
    "projects": [
        {
            "name": "我的项目",
            "enabled": true,
            "projectDir": "D:\\workspace\\my-project",
            "targetDir": "D:\\deploy\\my-project\\dist",
            "branch": "main"
        }
    ]
}
```

### 3️⃣ 运行同步

```powershell
.\multi-project-sync.ps1
```

### 4️⃣ (可选) 设置定时任务

```powershell
# 以管理员身份运行 PowerShell
.\setup-multi-task.ps1 -TaskAction create
```

**搞定！** 🎉 你的仓库现在会自动同步了。

---

## ⚙️ 配置说明

### 配置字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 项目名称（用于显示和筛选） |
| `enabled` | boolean | 是否启用同步 |
| `projectDir` | string | Git 仓库路径 |
| `targetDir` | string | 构建产物复制目标路径 |
| `branch` | string | 要同步的分支 |

### 配置示例

```json
{
    "description": "多项目同步配置",
    "projects": [
        {
            "name": "前端应用",
            "enabled": true,
            "projectDir": "D:\\workspace\\frontend-app",
            "targetDir": "D:\\deploy\\frontend\\dist",
            "branch": "develop"
        },
        {
            "name": "后端接口",
            "enabled": true,
            "projectDir": "D:\\workspace\\backend-api",
            "targetDir": "D:\\deploy\\api",
            "branch": "main"
        },
        {
            "name": "小程序项目",
            "enabled": false,
            "projectDir": "D:\\workspace\\mini-program",
            "targetDir": "D:\\deploy\\mp-weixin",
            "branch": "test"
        }
    ]
}
```

> 💡 **提示**：将 `enabled` 设为 `false` 可以临时禁用某个项目的同步

---

## 📖 使用方法

### 🔄 同步所有项目

```powershell
.\multi-project-sync.ps1
```

### 🎯 同步指定项目

```powershell
.\multi-project-sync.ps1 -ProjectName "前端应用"
```

### 📋 查看所有项目

```powershell
.\multi-project-sync.ps1 -ListProjects
```

### 🔧 单项目同步（旧版）

```powershell
.\auto-sys-test.ps1 -Branch "main"
```

---

## ⏰ 定时任务

### 创建定时任务（每天 9:00-01:00，每小时执行）

```powershell
# 需要管理员权限
.\setup-multi-task.ps1 -TaskAction create
```

### 任务管理

| 命令 | 说明 |
|------|------|
| `.\setup-multi-task.ps1 -TaskAction status` | 📊 查看任务状态 |
| `.\setup-multi-task.ps1 -TaskAction run` | ▶️ 立即执行 |
| `.\setup-multi-task.ps1 -TaskAction stop` | ⏹️ 停止任务 |
| `.\setup-multi-task.ps1 -TaskAction remove` | 🗑️ 删除任务 |

---

## 🔐 Git 免密配置

自动同步需要配置 Git 免密认证，以下是三种方式：

### 方式一：Personal Access Token（推荐）

```powershell
# 在 GitLab/GitHub 生成 Token 后，设置远程地址
git remote set-url origin https://用户名:TOKEN@github.com/user/repo.git
```

**生成 Token 步骤：**
1. GitLab: 设置 → Access Tokens → 创建
2. GitHub: Settings → Developer settings → Personal access tokens

### 方式二：SSH 密钥

```powershell
# 生成 SSH 密钥
ssh-keygen -t ed25519 -C "your-email@example.com"

# 查看公钥
cat ~/.ssh/id_ed25519.pub

# 将公钥添加到 GitLab/GitHub，然后修改远程地址
git remote set-url origin git@github.com:user/repo.git
```

### 方式三：Windows 凭据管理器

```powershell
git config --global credential.helper manager-core
# 下次 git fetch 时输入凭据，会自动保存
```

---

## 📁 文件结构

```
📦 windows-git-auto-sync
├── 📄 auto-sys-test.ps1        # 单项目同步脚本
├── 📄 multi-project-sync.ps1   # 多项目同步脚本
├── 📄 setup-multi-task.ps1     # 多项目定时任务管理
├── 📄 setup-scheduled-task.ps1 # 单项目定时任务管理
├── 📄 auto-sync-daemon.ps1     # 守护进程（持续同步）
├── 📄 projects-config.json     # 项目配置文件
├── 📄 README.md                # 英文文档
└── 📄 README_CN.md             # 中文文档（你在这里！）
```

---

## 📋 环境要求

| 要求 | 版本 |
|------|------|
| 💻 Windows | 10 / Server 2016 及以上 |
| 🐚 PowerShell | 5.1 及以上 |
| 🔧 Git | 2.x 及以上 |
| 📦 Node.js | （可选，用于 npm 项目） |

---

## 🛠️ 常见问题

### ❓ 脚本无法执行？

```powershell
# 允许执行本地脚本
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ❓ Git 还是要求输入密码？

```powershell
# 检查远程地址是否包含凭据
git remote -v

# 重新设置（包含 Token）
git remote set-url origin https://用户名:token@github.com/user/repo.git
```

### ❓ 定时任务不执行？

1. 确保以管理员身份创建任务
2. 检查状态：`.\setup-multi-task.ps1 -TaskAction status`
3. 查看 Windows 事件查看器 → 任务计划程序日志

### ❓ 日志文件在哪里？

| 日志文件 | 说明 |
|----------|------|
| `build.log` | 单项目构建日志 |
| `multi-sync.log` | 多项目同步日志 |
| `daemon.log` | 守护进程日志 |

> 日志文件会自动轮转，不用担心占用过多磁盘空间

---

## 💡 使用场景

### 🖥️ 场景一：测试环境自动更新

开发人员提交代码后，测试环境自动拉取最新代码，无需手动部署。

### 📱 场景二：小程序开发

自动同步代码并复制构建产物到微信开发者工具目录，方便测试。

### 🏢 场景三：多项目管理

同时维护多个项目，一个脚本全部搞定，告别逐个手动拉取。

---

## 📄 开源协议

MIT License - 自由使用、修改和分发。

---

<p align="center">
  <b>⭐ 觉得好用？给个 Star 支持一下！</b>
</p>

<p align="center">
  为追求效率的开发者而生 ❤️
</p>

