# Clear Disk

> 一款基于 Flutter 构建的 Windows 桌面工具，用于查找并清理 android/flutter 项目中的 `build` 目录。

[![Flutter](https://img.shields.io/badge/Flutter-3.24-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?logo=windows)](https://www.microsoft.com/windows)

[English](README.md)

---

## 简介

在开发 Android / Gradle / Flutter 项目时，`build` 目录会随时间积累大量磁盘空间。**Clear Disk** 可以扫描指定的根目录，找到所有包含 `build` 文件夹的项目，展示其大小，并支持批量删除——所有操作均通过简洁的图形界面完成。

## 功能特性

| 功能 | 说明 |
|---|---|
| **递归扫描** | 输入任意绝对路径，应用会递归查找所有包含 `build` 文件夹的子目录（支持多种项目识别模式）。 |
| **大小展示** | 每个 `build` 目录的大小以可读格式显示（KB / MB / GB）。 |
| **大小筛选** | 通过下拉菜单按阈值筛选——*无*、*100 MB*、*200 MB*、*500 MB* 或 *1 GB*。 |
| **打开资源管理器** | 每行提供一个 📁 按钮，点击可在 Windows 资源管理器中定位到对应目录。 |
| **扫描历史** | 已扫描的路径会本地保存，重复扫描时弹出确认提示。 |
| **批量删除** | 勾选一个或多个项目（支持全选），一键删除对应的 `build` 目录。 |
| **删除进度** | 删除过程中显示实时进度条弹窗，支持随时点击 **取消** 按钮中止操作。 |
| **确认弹窗** | 删除前弹出确认对话框，防止误操作。 |

## 项目识别模式

当一个目录匹配以下**任一**模式时，会被识别为"项目"并列出其 `build` 文件夹：

1. 同时包含 `android/` 和 `build/` 子目录。
2. 包含 `libs/`、`src/`、`build.gradle` 和 `build/`。
3. 包含 `build.gradle`、`build/`、`gradle.properties` 和 `gradle/`。

## 快速开始

### 环境要求

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.24.5** 或更高版本
- Windows 10 / 11

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/<your-username>/clear_disk.git
cd clear_disk

# 安装依赖
flutter pub get

# 调试模式运行
flutter run -d windows

# 构建发布版本
flutter build windows
```

构建产物位于：

```
build\windows\x64\runner\Release\clear_disk.exe
```

## 使用方法

1. **输入路径** — 在顶部输入框中填写绝对路径（如 `D:\Projects`）。
2. **点击"开始扫描"** — 应用递归搜索符合条件的项目。
3. **浏览结果** — 中间区域列出所有找到的 `build` 目录及其大小。
4. **大小筛选**（可选）— 使用下拉菜单仅显示大于指定阈值的项目。
5. **打开资源管理器**（可选）— 点击任意行的 📁 图标，在资源管理器中打开该目录。
6. **选择项目** — 勾选单个复选框，或使用底部的 **全选** 复选框。
7. **删除** — 点击 **删除选中**，在弹窗中确认，然后查看进度条。
8. **取消**（可选）— 在进度弹窗中点击 **取消删除** 可中途停止；已删除的项目不会恢复。

## 项目结构

```
lib/
├── main.dart          # 单文件应用（UI + 逻辑）
```

### 核心类

| 类名 | 职责 |
|---|---|
| `MyApp` | 根组件，配置 Material 3 主题。 |
| `HomePage` | 主页面——有状态组件，承载所有 UI 和业务逻辑。 |
| `BuildItem` | 数据模型，表示一个已扫描的 `build` 目录（路径 + 大小）。 |
| `ScanHistory` | 将扫描历史持久化到可执行文件同目录下的 `scan_history.json`。 |

## 技术栈

- **Flutter 3.24** — 跨平台 UI 框架
- **Dart 3.x** — 编程语言
- **Material 3** — 设计系统（`useMaterial3: true`）
- **dart:io** — 文件系统操作（`Directory`、`File`、`Process`）
- **dart:convert** — JSON 编解码，用于历史记录持久化

除 Flutter SDK 自身外，无需任何第三方依赖。

## 许可

本项目仅供个人 / 内部使用，可自由修改和分发。
