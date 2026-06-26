import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// =============================================================================
// Localization
// =============================================================================

class AppStrings {
  static const Map<String, Map<String, String>> _strings = {
    'zh': {
      'appTitle': 'Clear Disk',
      'pageTitle': 'Clear Disk - Build目录清理工具',
      'enterPath': '请输入磁盘路径',
      'pathNotFound': '路径不存在',
      'pathAlreadyScanned': '该路径已经清除过，是否继续扫描？',
      'tip': '提示',
      'cancel': '取消',
      'confirm': '确定',
      'noResults': '未找到符合条件的目录',
      'scanError': '扫描出错: {error}',
      'none': '无',
      'sizeFilterLabel': '文件大小筛选：',
      'scanning': '正在扫描目录，请稍候...',
      'enterPathHint': '请输入路径并点击"开始扫描"',
      'noFilterResults': '没有符合当前筛选条件的项目',
      'sizeLabel': '大小',
      'openInExplorer': '在资源管理器中打开',
      'selectItemsFirst': '请先选择要删除的项目',
      'confirmDelete': '确认删除',
      'confirmDeleteMsg': '是否确认删除选中项目的build目录？（共 {count} 项）',
      'deleting': '正在删除',
      'progress': '进度: {done} / {total}',
      'failed': '失败: {count} 项',
      'cancelDelete': '取消删除',
      'cancelledMsg': '已取消删除，成功删除 {count} 项',
      'deleteCompleteMsg': '删除完成：成功 {success} 项，失败 {fail} 项',
      'deleteSuccessMsg': '成功删除 {count} 个build目录',
      'selectAll': '全选',
      'selectedCount': '已选 {selected} / {total} 项',
      'deleteSelected': '删除选中',
      'inputLabel': '请输入磁盘绝对路径',
      'inputHint': '例如: D:\\Projects',
      'startScan': '开始扫描',
      'scanningBtn': '扫描中...',
    },
    'en': {
      'appTitle': 'Clear Disk',
      'pageTitle': 'Clear Disk - Build Directory Cleaner',
      'enterPath': 'Please enter a disk path',
      'pathNotFound': 'Path does not exist',
      'pathAlreadyScanned': 'This path has been scanned before. Continue scanning?',
      'tip': 'Notice',
      'cancel': 'Cancel',
      'confirm': 'OK',
      'noResults': 'No matching directories found',
      'scanError': 'Scan error: {error}',
      'none': 'None',
      'sizeFilterLabel': 'Size filter:',
      'scanning': 'Scanning directories, please wait...',
      'enterPathHint': 'Enter a path and click "Start Scan"',
      'noFilterResults': 'No items match the current filter',
      'sizeLabel': 'Size',
      'openInExplorer': 'Open in Explorer',
      'selectItemsFirst': 'Please select items to delete first',
      'confirmDelete': 'Confirm Delete',
      'confirmDeleteMsg': 'Delete build directories for selected items? ({count} items)',
      'deleting': 'Deleting',
      'progress': 'Progress: {done} / {total}',
      'failed': 'Failed: {count}',
      'cancelDelete': 'Cancel Delete',
      'cancelledMsg': 'Deletion cancelled. {count} items deleted.',
      'deleteCompleteMsg': 'Done: {success} succeeded, {fail} failed',
      'deleteSuccessMsg': 'Successfully deleted {count} build directories',
      'selectAll': 'Select All',
      'selectedCount': '{selected} / {total} selected',
      'deleteSelected': 'Delete Selected',
      'inputLabel': 'Enter an absolute disk path',
      'inputHint': 'e.g. D:\\Projects',
      'startScan': 'Start Scan',
      'scanningBtn': 'Scanning...',
    },
  };

  static String of(BuildContext context, String key, [Map<String, String>? params]) {
    final code = LocaleProvider.of(context).locale.languageCode;
    String value = _strings[code]?[key] ?? _strings['zh']![key] ?? key;
    if (params != null) {
      params.forEach((k, v) => value = value.replaceAll('{$k}', v));
    }
    return value;
  }
}

class LocaleProvider extends InheritedWidget {
  final Locale locale;
  final void Function(Locale) setLocale;

  const LocaleProvider({
    super.key,
    required this.locale,
    required this.setLocale,
    required super.child,
  });

  static LocaleProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleProvider>()!;
  }

  @override
  bool updateShouldNotify(LocaleProvider oldWidget) =>
      locale != oldWidget.locale;
}

// =============================================================================
// App
// =============================================================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('zh');

  @override
  Widget build(BuildContext context) {
    return LocaleProvider(
      locale: _locale,
      setLocale: (locale) => setState(() => _locale = locale),
      child: MaterialApp(
        title: 'Clear Disk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        locale: _locale,
        home: const HomePage(),
      ),
    );
  }
}

// =============================================================================
// Scan history persistence
// =============================================================================

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
    } catch (_) {}
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

// =============================================================================
// Data model
// =============================================================================

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

// =============================================================================
// Home page
// =============================================================================

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
      _showSnackBar(AppStrings.of(context, 'enterPath'));
      return;
    }
    final dir = Directory(path);
    if (!dir.existsSync()) {
      _showSnackBar(AppStrings.of(context, 'pathNotFound'));
      return;
    }

    if (_history.contains(path)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.of(context, 'tip')),
          content: Text(AppStrings.of(context, 'pathAlreadyScanned')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.of(context, 'cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.of(context, 'confirm')),
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
        _history.add(path);
        if (results.isEmpty) {
          _showSnackBar(AppStrings.of(context, 'noResults'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        _showSnackBar(AppStrings.of(context, 'scanError', {'error': '$e'}));
      }
    }
  }

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

      if ((hasAndroid && hasBuild) ||
          (hasLibs && hasSrc && hasBuildGradle && hasBuild) ||
          (hasBuildGradle && hasBuild && hasGradleProperties && hasGradle)) {
        final buildDir =
            Directory('${dir.path}${Platform.pathSeparator}build');
        final size = await _calculateDirectorySize(buildDir);
        results.add(BuildItem(path: buildDir.path, sizeInBytes: size));
      }

      for (final child in children) {
        if (child is Directory) {
          final name = _basename(child.path);
          if (name != 'android' && name != 'build') {
            results.addAll(await _scanDirectory(child));
          }
        }
      }
    } catch (_) {}
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
      _showSnackBar(AppStrings.of(context, 'selectItemsFirst'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context, 'confirmDelete')),
        content: Text(AppStrings.of(context, 'confirmDeleteMsg',
            {'count': '${_selectedIndices.length}'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.of(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.of(context, 'confirm'),
                style: const TextStyle(color: Colors.red)),
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

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
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
                title: Text(AppStrings.of(context, 'deleting')),
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
                      AppStrings.of(context, 'progress', {
                        'done': '${successCount + failCount}',
                        'total': '$total',
                      }),
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (failCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          AppStrings.of(context, 'failed', {'count': '$failCount'}),
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      cancelled = true;
                    },
                    child: Text(AppStrings.of(context, 'cancelDelete')),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    if (mounted) {
      final deletedCount = successCount;
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
        _showSnackBar(
            AppStrings.of(context, 'cancelledMsg', {'count': '$successCount'}));
      } else if (failCount > 0) {
        _showSnackBar(AppStrings.of(context, 'deleteCompleteMsg',
            {'success': '$successCount', 'fail': '$failCount'}));
      } else {
        _showSnackBar(
            AppStrings.of(context, 'deleteSuccessMsg', {'count': '$successCount'}));
      }
    }
  }

  Future<void> _runDeletion({
    required List<int> sortedIndices,
    required bool Function() isCancelled,
    required void Function(
            int done, int succeeded, int failed, String currentPath)
        onProgress,
  }) async {
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < sortedIndices.length; i++) {
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
        successCount++;
      }
      onProgress(i + 1, successCount, failCount, _results[index].path);
    }
  }

  void _openInExplorer(String path) {
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

    final localeProvider = LocaleProvider.of(context);
    final currentCode = localeProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context, 'pageTitle')),
        actions: [
          // Language toggle
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: 'Language',
            onSelected: (code) {
              localeProvider.setLocale(Locale(code));
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'zh',
                child: Row(
                  children: [
                    if (currentCode == 'zh')
                      const Icon(Icons.check, size: 18, color: Colors.blue),
                    if (currentCode == 'zh') const SizedBox(width: 8),
                    const Text('中文'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    if (currentCode == 'en')
                      const Icon(Icons.check, size: 18, color: Colors.blue),
                    if (currentCode == 'en') const SizedBox(width: 8),
                    const Text('English'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopInput(),
          const Divider(height: 1),
          if (_results.isNotEmpty) _buildFilterBar(),
          Expanded(child: _buildResultList()),
          const Divider(height: 1),
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
              decoration: InputDecoration(
                labelText: AppStrings.of(context, 'inputLabel'),
                hintText: AppStrings.of(context, 'inputHint'),
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.folder_open),
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
            label: Text(_isScanning
                ? AppStrings.of(context, 'scanningBtn')
                : AppStrings.of(context, 'startScan')),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final localeCode = LocaleProvider.of(context).locale.languageCode;
    // Build display labels based on current locale.
    final filterLabels = <String, String>{
      '无': localeCode == 'en' ? 'None' : '无',
      '100 MB': '100 MB',
      '200 MB': '200 MB',
      '500 MB': '500 MB',
      '1 GB': '1 GB',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(AppStrings.of(context, 'sizeFilterLabel'),
              style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sizeFilter,
              isDense: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: _filterOptions.keys.map((key) {
                return DropdownMenuItem(
                  value: key,
                  child: Text(filterLabels[key] ?? key),
                );
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

  Widget _buildResultList() {
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppStrings.of(context, 'scanning')),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          AppStrings.of(context, 'enterPathHint'),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final visible = _visibleIndices;
    if (visible.isEmpty) {
      return Center(
        child: Text(
          AppStrings.of(context, 'noFilterResults'),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
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
          subtitle: Text(
              '${AppStrings.of(context, 'sizeLabel')}: ${item.formattedSize}'),
          trailing: IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.blue),
            tooltip: AppStrings.of(context, 'openInExplorer'),
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
          Text(AppStrings.of(context, 'selectAll')),
          const SizedBox(width: 8),
          Text(
            AppStrings.of(context, 'selectedCount',
                {'selected': '$visibleSelectedCount', 'total': '${visible.length}'}),
            style: const TextStyle(color: Colors.grey),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _selectedIndices.isEmpty ? null : _deleteSelected,
            icon: const Icon(Icons.delete),
            label: Text(AppStrings.of(context, 'deleteSelected')),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
