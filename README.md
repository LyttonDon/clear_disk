# Clear Disk

> A Windows desktop tool built with Flutter to find and clean up `build` directories in your android/flutter projects.

[![Flutter](https://img.shields.io/badge/Flutter-3.24-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?logo=windows)](https://www.microsoft.com/windows)

[中文文档](README_ZH.md)

---

## Overview

When working on Android / Gradle-based projects, the `build` directory can accumulate a large amount of disk space over time. **Clear Disk** scans a given root directory, locates every project that contains a `build` folder, displays its size, and lets you batch-delete the ones you no longer need — all through a simple graphical interface.

## Features

| Feature | Description |
|---|---|
| **Recursive Scan** | Enter any absolute path and the app recursively finds all sub-directories that contain a `build` folder (detected by multiple project patterns). |
| **Size Display** | Each `build` directory size is displayed in human-readable units (KB / MB / GB). |
| **Size Filter** | A dropdown filter lets you show only items above a threshold — *None*, *100 MB*, *200 MB*, *500 MB*, or *1 GB*. |
| **Open in Explorer** | Each row has a folder icon button that opens Windows File Explorer at that location. |
| **Scan History** | Previously scanned paths are saved locally. Re-scanning a known path prompts a confirmation dialog. |
| **Batch Delete** | Select one or more items (with select-all support) and delete their `build` directories in one click. |
| **Delete Progress** | A progress dialog with a real-time progress bar is shown during deletion, with a **Cancel** button to abort at any time. |
| **Confirmation Dialog** | A confirmation prompt appears before any deletion to prevent accidental data loss. |

## Project Detection Patterns

A directory is considered a "project" (and its `build` folder is listed) when it matches **any** of the following patterns:

1. Contains both `android/` and `build/` sub-directories.
2. Contains `libs/`, `src/`, `build.gradle`, and `build/`.
3. Contains `build.gradle`, `build/`, `gradle.properties`, and `gradle/`.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.24.5** or later
- Windows 10 / 11

### Install & Run

```bash
# Clone the repository
git clone https://github.com/<your-username>/clear_disk.git
cd clear_disk

# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build a release executable
flutter build windows
```

The release binary will be located at:

```
build\windows\x64\runner\Release\clear_disk.exe
```

## Usage

1. **Enter a path** — type an absolute directory path (e.g. `D:\Projects`) in the top input field.
2. **Click "开始扫描" (Start Scan)** — the app recursively searches for matching projects.
3. **Browse results** — the middle area lists every found `build` directory with its size.
4. **Filter by size** *(optional)* — use the dropdown to show only items above a certain threshold.
5. **Open in Explorer** *(optional)* — click the 📁 icon on any row to open that folder in Windows Explorer.
6. **Select items** — tick individual checkboxes or use the **全选 (Select All)** checkbox at the bottom.
7. **Delete** — click **删除选中 (Delete Selected)**, confirm in the dialog, and watch the progress bar.
8. **Cancel** *(optional)* — click **取消删除 (Cancel)** in the progress dialog to stop midway; already-deleted items remain deleted.

## Project Structure

```
lib/
├── main.dart          # Single-file app (UI + logic)
```

### Key Classes

| Class | Purpose |
|---|---|
| `MyApp` | Root widget with Material 3 theme. |
| `HomePage` | Main page — stateful widget holding all UI and business logic. |
| `BuildItem` | Data model for a scanned `build` directory (path + size). |
| `ScanHistory` | Persists scanned paths to `scan_history.json` next to the executable. |

## Tech Stack

- **Flutter 3.24** — cross-platform UI framework
- **Dart 3.x** — language
- **Material 3** — design system (`useMaterial3: true`)
- **dart:io** — file system operations (`Directory`, `File`, `Process`)
- **dart:convert** — JSON encoding / decoding for history persistence

No third-party packages are required beyond the Flutter SDK itself.

## License

This project is for personal / internal use. Feel free to modify and distribute as needed.
