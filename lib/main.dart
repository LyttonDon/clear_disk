import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

/// Persists previously scanned paths to a local JSON file.
class ScanHistory {
  late final File _file;
  final Set<String> _paths = {};

  ScanHistory() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    _file = File('$exeDir${Platform.pathSeparator}scan_history.json');
  }

  Set<String> get paths => _paths;

  Future<void> load() async {
    try {
      if (_file.existsSync()) {
        final content = await _file.readAsString();
        final list = (jsonDecode(content) as List).cast<String>();
        _paths.addAll(list);
      }
    } catch (_) {
      // Ignore corrupt / unreadable file.
    }
  }

  Future<void> save() async {
    try {
      await _file.writeAsString(jsonEncode(_paths.toList()));
    } catch (_) {}
  }

  bool contains(String path) => _paths.contains(path);

  void add(String path) {
    _paths.add(path);
    save();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clear Disk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// Data model for a scanned build directory.
class BuildItem {
  final String path;
  final int sizeInBytes;

  BuildItem({required this.path, required this.sizeInBytes});

  String get formattedSize {
    if (sizeInBytes >= 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (sizeInBytes >= 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _pathController = TextEditingController();
  final ScanHistory _history = ScanHistory();
  List<BuildItem> _results = [];
  final Set<int> _selectedIndices = {};
  bool _isScanning = false;

  // ---------- Size filter ----------

  static const Map<String, int?> _filterOptions = {
    '无': null,
    '100 MB': 100 * 1024 * 1024,
    '200 MB': 200 * 1024 * 1024,
    '500 MB': 500 * 1024 * 1024,
    '1 GB': 1024 * 1024 * 1024,
  };
  String _sizeFilter = '无';

  int? get _sizeFilterBytes => _filterOptions[_sizeFilter];

  /// Indices into [_results] that pass the current size filter.
  List<int> get _visibleIndices {
    final threshold = _sizeFilterBytes;
    if (threshold == null) {
      return List.generate(_results.length, (i) => i);
    }
    return [
      for (int i = 0; i < _results.length; i++)
        if (_results[i].sizeInBytes >= threshold) i
    ];
  }

  @override
  void initState() {
    super.initState();
    _history.load();
  }

  // ---------- Scanning logic ----------

  Future<void> _scan() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      _showSnackBar('请输入磁盘路径');
      return;
    }
    final dir = Directory(path);
    if (!dir.existsSync()) {
      _showSnackBar('路径不存在');
      return;
    }

    // Check if this path was scanned before.
    if (_history.contains(path)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('该路径已经清除过，是否继续扫描？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() {
      _isScanning = true;
      _results = [];
      _selectedIndices.clear();
      _sizeFilter = '无';
    });

    try {
      final results = await _scanDirectory(dir);
      if (mounted) {
        setState(() {
          _results = results;
          _isScanning = false;
        });
        // Save path to history after a successful scan.
        _history.add(path);
        if (results.isEmpty) {
          _showSnackBar('未找到符合条件的目录');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        _showSnackBar('扫描出错: $e');
      }
    }
  }

  /// Recursively scan [dir]. If it contains both `android` and `build`
  /// subdirectories, record the build directory size and skip recursing into
  /// those two subdirectories. Continue recursing into other subdirectories.
  Future<List<BuildItem>> _scanDirectory(Directory dir) async {
    final results = <BuildItem>[];
    try {
      final children = await dir.list(followLinks: false).toList();

      final hasAndroid = children.any(
        (e) => e is Directory && _basename(e.path) == 'android',
      );
      final hasBuild = children.any(
        (e) => e is Directory && _basename(e.path) == 'build',
      );

      final hasLibs = children.any(
        (e) => e is Directory && _basename(e.path) == 'libs',
      );
      final hasSrc = children.any(
        (e) => e is Directory && _basename(e.path) == 'src',
      );
      final hasBuildGradle = children.any(
        (e) => e is File && _basename(e.path) == 'build.gradle',
      );

      final hasGradleProperties = children.any(
            (e) => e is File && _basename(e.path) == 'gradle.properties',
      );
      final hasGradle = children.any(
            (e) => e is Directory && _basename(e.path) == 'gradle',
      );

      if ((hasAndroid && hasBuild)
          || (hasLibs && hasSrc && hasBuildGradle && hasBuild)
          || (hasBuildGradle && hasBuild && hasGradleProperties && hasGradle)) {
        final buildDir = Directory('${dir.path}${Platform.pathSeparator}build');
        final size = await _calculateDirectorySize(buildDir);
        results.add(BuildItem(path: buildDir.path, sizeInBytes: size));
      }

      // Recurse into subdirectories (skip android/build to avoid duplication).
      for (final child in children) {
        if (child is Directory) {
          final name = _basename(child.path);
          if (name != 'android' && name != 'build') {
            results.addAll(await _scanDirectory(child));
          }
        }
      }
    } catch (_) {
      // Silently skip directories we can't access.
    }
    return results;
  }

  String _basename(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  Future<int> _calculateDirectorySize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  // ---------- Actions ----------

  void _toggleSelect(int index, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIndices.add(index);
      } else {
        _selectedIndices.remove(index);
      }
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIndices.addAll(_visibleIndices);
      } else {
        _selectedIndices.removeAll(_visibleIndices);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) {
      _showSnackBar('请先选择要删除的项目');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('是否确认删除选中项目的build目录？（共 ${_selectedIndices.length} 项）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final sortedIndices = _selectedIndices.toList()..sort();
    final total = sortedIndices.length;
    int successCount = 0;
    int failCount = 0;
    bool cancelled = false;
    bool deletionStarted = false;

    // Show a progress dialog while deleting.
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              // Only kick off deletion once.
              if (!deletionStarted) {
                deletionStarted = true;
                _runDeletion(
                  sortedIndices: sortedIndices,
                  isCancelled: () => cancelled,
                  onProgress: (done, succeeded, failed, currentPath) {
                    setDialogState(() {
                      successCount = succeeded;
                      failCount = failed;
                    });
                  },
                ).then((_) {
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                });
              }

              return AlertDialog(
                title: const Text('正在删除'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: total > 0
                          ? (successCount + failCount) / total
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '进度: ${successCount + failCount} / $total',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (failCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '失败: $failCount 项',
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      cancelled = true;
                    },
                    child: const Text('取消删除'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    // Show result after dialog closes.
    if (mounted) {
      final deletedCount = successCount;
      // Remove the items that were successfully deleted.
      if (deletedCount > 0) {
        final deletedIndices = <int>[];
        for (int i = 0; i < successCount; i++) {
          deletedIndices.add(sortedIndices[i]);
        }
        setState(() {
          for (final index in deletedIndices.reversed) {
            _results.removeAt(index);
          }
          _selectedIndices.clear();
        });
      }

      if (cancelled) {
        _showSnackBar('已取消删除，成功删除 $successCount 项');
      } else if (failCount > 0) {
        _showSnackBar('删除完成：成功 $successCount 项，失败 $failCount 项');
      } else {
        _showSnackBar('成功删除 $successCount 个build目录');
      }
    }
  }

  /// Perform the actual deletion and report progress via [onProgress].
  /// [isCancelled] is checked before each item; returns true if user pressed cancel.
  Future<void> _runDeletion({
    required List<int> sortedIndices,
    required bool Function() isCancelled,
    required void Function(int done, int succeeded, int failed, String currentPath)
        onProgress,
  }) async {
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < sortedIndices.length; i++) {
      // Stop if user cancelled.
      if (isCancelled()) break;

      final index = sortedIndices[i];
      final buildDir = Directory(_results[index].path);
      if (buildDir.existsSync()) {
        try {
          await buildDir.delete(recursive: true);
          successCount++;
        } catch (_) {
          failCount++;
        }
      } else {
        // Directory already gone — count as success.
        successCount++;
      }
      onProgress(i + 1, successCount, failCount, _results[index].path);
    }
  }

  void _openInExplorer(String path) {
    // Open Windows Explorer and select the folder.
    Process.run('explorer', [path]);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndices;
    final allSelected =
        visible.isNotEmpty && visible.every((i) => _selectedIndices.contains(i));

    return Scaffold(
      appBar: AppBar(title: const Text('Clear Disk - Build目录清理工具')),
      body: Column(
        children: [
          // -------- Top: path input --------
          _buildTopInput(),
          const Divider(height: 1),
          // -------- Size filter --------
          if (_results.isNotEmpty) _buildFilterBar(),
          // -------- Middle: result list --------
          Expanded(child: _buildResultList()),
          const Divider(height: 1),
          // -------- Bottom: select all + delete --------
          _buildBottomBar(allSelected),
        ],
      ),
    );
  }

  Widget _buildTopInput() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: '请输入磁盘绝对路径',
                hintText: '例如: D:\\Projects',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.folder_open),
              ),
              onSubmitted: (_) => _scan(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _isScanning ? null : _scan,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(_isScanning ? '扫描中...' : '开始扫描'),
          ),
        ],
      ),
    );
  }

  // ---------- Size filter UI ----------

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Text('文件大小筛选：', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sizeFilter,
              isDense: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: _filterOptions.keys.map((label) {
                return DropdownMenuItem(value: label, child: Text(label));
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _sizeFilter = v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Result list ----------

  Widget _buildResultList() {
    if (_isScanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描目录，请稍候...'),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          '请输入路径并点击"开始扫描"',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final visible = _visibleIndices;
    if (visible.isEmpty) {
      return const Center(
        child: Text(
          '没有符合当前筛选条件的项目',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final realIndex = visible[index];
        final item = _results[realIndex];
        final selected = _selectedIndices.contains(realIndex);

        return ListTile(
          leading: Checkbox(
            value: selected,
            onChanged: (v) => _toggleSelect(realIndex, v),
          ),
          title: Text(
            item.path,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('大小: ${item.formattedSize}'),
          trailing: IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.blue),
            tooltip: '在资源管理器中打开',
            onPressed: () => _openInExplorer(item.path),
          ),
          onTap: () => _toggleSelect(realIndex, !selected),
        );
      },
    );
  }

  Widget _buildBottomBar(bool allSelected) {
    final visible = _visibleIndices;
    final visibleSelectedCount =
        visible.where((i) => _selectedIndices.contains(i)).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: visible.isEmpty ? null : _toggleSelectAll,
          ),
          const Text('全选'),
          const SizedBox(width: 8),
          Text(
            '已选 $visibleSelectedCount / ${visible.length} 项',
            style: const TextStyle(color: Colors.grey),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _selectedIndices.isEmpty ? null : _deleteSelected,
            icon: const Icon(Icons.delete),
            label: const Text('删除选中'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
