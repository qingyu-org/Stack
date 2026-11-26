import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatter.dart';
import '../../../../data/services/ssh/ssh_connection.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../../data/services/ssh/ssh_files.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_info_card.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/skeleton_item.dart';

class SshFilesTab extends ConsumerStatefulWidget {
  const SshFilesTab({
    super.key,
    required this.serverId,
    required this.isActive,
  });

  final int serverId;
  final bool isActive;

  @override
  ConsumerState<SshFilesTab> createState() => _SshFilesTabState();
}

class _SshFilesTabState extends ConsumerState<SshFilesTab> {
  final SshFileService _service = SshFileService();
  final TextEditingController _searchController = TextEditingController();

  String _path = '.';
  List<SshRemoteFile> _files = const [];
  final Set<String> _selectedPaths = {};
  bool _initializing = true;
  bool _loading = false;
  bool _busy = false;
  bool _searching = false;
  String _query = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SshRemoteFile> get _visibleFiles {
    if (_query.isEmpty) return _files;
    final query = _query.toLowerCase();
    return _files
        .where((file) => file.name.toLowerCase().contains(query))
        .toList();
  }

  bool get _selectionMode => _selectedPaths.isNotEmpty;

  Future<void> _initialize() async {
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      final home = await _service.home(connection);
      if (!mounted) return;
      setState(() {
        _path = home;
        _initializing = false;
      });
      await _load(showLoading: true);
    } catch (error) {
      if (!mounted) return;
      ref.read(sshConnectionManagerProvider).invalidateIfIdle(widget.serverId);
      setState(() {
        _initializing = false;
        _error = error;
      });
    }
  }

  Future<void> _load({bool showLoading = false}) async {
    // 目录可能在加载期间被切换；只把当前目录的结果写回界面。
    final path = _path;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      final files = await _service.list(connection, path);
      if (!mounted || path != _path) return;
      setState(() {
        _files = files;
        _selectedPaths.removeWhere(
          (selected) => !files.any((file) => file.path == selected),
        );
        _loading = false;
        _error = null;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted || path != _path) return;
      ref.read(sshConnectionManagerProvider).invalidateIfIdle(widget.serverId);
      setState(() {
        _loading = false;
        _error = error;
        _initializing = false;
      });
    }
  }

  Future<void> _navigateTo(String path) async {
    if (path == _path) return;
    setState(() {
      _path = path;
      _files = const [];
      _selectedPaths.clear();
      _query = '';
      _searching = false;
      _searchController.clear();
      _loading = true;
      _error = null;
    });
    await _load();
  }

  void _toggleSelection(SshRemoteFile file) {
    setState(() {
      if (!_selectedPaths.add(file.path)) {
        _selectedPaths.remove(file.path);
      }
    });
  }

  void _clearSelection() {
    if (_selectedPaths.isEmpty) return;
    setState(_selectedPaths.clear);
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
      _selectedPaths.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_busy || _selectedPaths.isEmpty) return;
    final selected = _files
        .where((file) => _selectedPaths.contains(file.path))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.ssh_files_deleteSelectedTitle),
        content: Text(l10n.ssh_files_deleteSelectedConfirm(selected.length)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.ssh_files_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    var deleted = 0;
    Object? firstError;
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      for (final file in selected) {
        try {
          await _service.delete(connection, file);
          deleted++;
        } catch (error) {
          firstError ??= error;
        }
      }
      if (!mounted) return;
      _selectedPaths.clear();
      await _load();
      if (!mounted) return;
      if (firstError != null) {
        _showError(l10n.ssh_files_actionFailed, firstError);
      } else {
        showAppSuccessToast(l10n.ssh_files_deletedCount(deleted));
      }
    } catch (error) {
      if (mounted) _showError(l10n.ssh_files_actionFailed, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFile(SshRemoteFile file) async {
    final action = await showActionSheet<String>(
      context: context,
      builder: (_) => _SshFileActionsSheet(file: file),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'download':
        await _download(file);
      case 'edit':
        await _edit(file);
      case 'rename':
        await _rename(file);
      case 'delete':
        await _delete(file);
    }
  }

  Future<void> _edit(SshRemoteFile file) async {
    if (file.size > SshFileService.maxEditBytes) {
      showAppErrorToast(context.l10n.ssh_files_tooLarge);
      return;
    }
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      final bytes = await _service.readBytes(connection, file.path);
      if (bytes.take(8192).contains(0)) {
        if (mounted) showAppErrorToast(context.l10n.ssh_files_binary);
        return;
      }
      final String content;
      try {
        content = utf8.decode(bytes);
      } on FormatException {
        if (mounted) {
          showAppErrorToast(
            context.l10n.ssh_files_binary,
            description: context.l10n.ssh_files_encodingUnsupported,
          );
        }
        return;
      }
      if (!mounted) return;
      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : null;
      var saved = false;
      await showAppCodeEditorSheet(
        context,
        title: file.name,
        subtitle: file.path,
        initialContent: content,
        language: extension,
        onSave: (updated) async {
          final connection = await ref
              .read(sshConnectionManagerProvider)
              .get(widget.serverId);
          await _service.writeBytes(
            connection,
            file.path,
            utf8.encode(updated),
          );
          saved = true;
          return true;
        },
      );
      if (saved && mounted) await _load();
    } catch (error) {
      if (mounted) _showError(context.l10n.ssh_files_actionFailed, error);
    }
  }

  Future<void> _download(SshRemoteFile file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      final directory = await getTemporaryDirectory();
      final safeName = file.name.replaceAll(RegExp(r'[/\\]'), '_');
      final localPath =
          '${directory.path}/ssh_share_'
          '${DateTime.now().microsecondsSinceEpoch}_$safeName';
      await _service.downloadTo(connection, file.path, localPath);
      // 分享目标可能稍后才读取文件，延迟清理而不是立即删除。
      unawaited(
        Future<void>.delayed(const Duration(minutes: 1), () async {
          try {
            await File(localPath).delete();
          } catch (_) {
            // 临时文件可能已被系统清理。
          }
        }),
      );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(subject: file.name, files: [XFile(localPath)]),
      );
    } catch (error) {
      if (mounted) _showError(context.l10n.ssh_files_actionFailed, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_busy) return;
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      final file = files.first;
      final length = await file.length();
      if (!mounted) return;
      if (length != null && length > 64 * 1024 * 1024) {
        if (mounted) showAppErrorToast(context.l10n.ssh_files_uploadTooLarge);
        return;
      }
      final uploadName = file.name.split(RegExp(r'[/\\]')).last;
      final exists = _files.any(
        (entry) => !entry.isDirectory && entry.name == uploadName,
      );
      if (exists) {
        final l10n = context.l10n;
        final overwrite = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text(l10n.ssh_files_overwriteTitle),
            content: Text(l10n.ssh_files_overwriteConfirm(uploadName)),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.common_cancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.ssh_files_overwriteAction),
              ),
            ],
          ),
        );
        if (overwrite != true || !mounted) return;
      }
      setState(() => _busy = true);
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      await _service.uploadBytes(
        connection,
        await file.readAsBytes(),
        sshJoinPath(_path, uploadName),
      );
      if (!mounted) return;
      showAppSuccessToast(context.l10n.ssh_files_uploaded);
      await _load();
    } catch (error) {
      if (mounted) _showError(context.l10n.ssh_files_uploadFailed, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createFolder() async {
    final name = await _promptName(context.l10n.ssh_files_newFolderTitle);
    if (name == null || !mounted) return;
    if (!_isValidName(name)) {
      showAppErrorToast(context.l10n.ssh_files_invalidName);
      return;
    }
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      await _service.createDirectory(connection, sshJoinPath(_path, name));
      if (!mounted) return;
      showAppSuccessToast(context.l10n.ssh_files_folderCreated);
      await _load();
    } catch (error) {
      if (mounted) _showError(context.l10n.ssh_files_actionFailed, error);
    }
  }

  Future<void> _rename(SshRemoteFile file) async {
    final name = await _promptName(
      context.l10n.ssh_files_renameTitle,
      initial: file.name,
    );
    if (name == null || name.isEmpty || name == file.name || !mounted) return;
    if (!_isValidName(name)) {
      showAppErrorToast(context.l10n.ssh_files_invalidName);
      return;
    }
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      await _service.rename(connection, file.path, sshJoinPath(_path, name));
      if (!mounted) return;
      showAppSuccessToast(context.l10n.ssh_files_renamed);
      await _load();
    } catch (error) {
      if (mounted) _showError(context.l10n.ssh_files_actionFailed, error);
    }
  }

  Future<void> _delete(SshRemoteFile file) async {
    final l10n = context.l10n;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.ssh_files_deleteTitle),
        content: Text(l10n.ssh_files_deleteConfirm(file.name)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.ssh_files_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final connection = await ref
          .read(sshConnectionManagerProvider)
          .get(widget.serverId);
      await _service.delete(connection, file);
      if (!mounted) return;
      showAppSuccessToast(l10n.ssh_files_deleted);
      await _load();
    } catch (error) {
      if (mounted) _showError(l10n.ssh_files_actionFailed, error);
    }
  }

  bool _isValidName(String name) => isValidSshEntryName(name);

  Future<String?> _promptName(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    try {
      return await showCupertinoDialog<String>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: dialogContext.l10n.ssh_files_namePlaceholder,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value.trim()),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.common_cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(dialogContext.l10n.common_done),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _showError(String title, Object error) {
    showAppErrorToast(
      title,
      description: error is SshConnectionException
          ? error.toString()
          : '$error',
    );
  }

  Future<void> _showActionsMenu() async {
    final l10n = context.l10n;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(_displayPath()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _upload();
            },
            child: Text(l10n.ssh_files_upload),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _createFolder();
            },
            child: Text(l10n.ssh_files_newFolder),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.common_cancel),
        ),
      ),
    );
  }

  String _displayPath() {
    if (_path == '.' || _path.isEmpty) return context.l10n.ssh_files_home;
    return _path;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isRoot = _path == '/' || _path == '.' || _path.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground(
                context,
              ).withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.separator(context).withValues(alpha: 0.14),
                width: 0.5,
              ),
            ),
            child: _searching
                ? Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: CupertinoSearchTextField(
                            controller: _searchController,
                            autofocus: true,
                            placeholder: l10n.files_searchPlaceholder,
                            backgroundColor: AppColors.tertiaryBackground(
                              context,
                            ).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(11),
                            placeholderStyle: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.tertiaryLabel(context),
                            ),
                            itemColor: AppColors.secondaryLabel(context),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.label(context),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value.trim()),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(48, 34),
                        onPressed: _toggleSearch,
                        child: Text(
                          l10n.common_cancel,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        onPressed: isRoot
                            ? null
                            : () => _navigateTo(sshParentPath(_path)),
                        child: Icon(
                          TablerIcons.arrow_up,
                          size: 17,
                          color: isRoot
                              ? AppColors.tertiaryLabel(context)
                              : AppColors.label(context),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _PathBreadcrumb(
                            path: _path,
                            onNavigate: _navigateTo,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(34, 36),
                        onPressed: _selectionMode ? null : _toggleSearch,
                        child: Icon(
                          TablerIcons.search,
                          size: 17,
                          color: _selectionMode
                              ? AppColors.tertiaryLabel(context)
                              : AppColors.secondaryLabel(context),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(34, 36),
                        onPressed: _loading
                            ? null
                            : () => _load(showLoading: true),
                        child: Icon(
                          TablerIcons.refresh,
                          size: 17,
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(34, 36),
                        onPressed: _busy ? null : _showActionsMenu,
                        child: _busy
                            ? const CupertinoActivityIndicator(radius: 8)
                            : Icon(
                                TablerIcons.dots_vertical,
                                size: 17,
                                color: AppColors.secondaryLabel(context),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
        Expanded(child: _buildBody(l10n)),
        if (_selectionMode)
          _SelectionBar(
            count: _selectedPaths.length,
            allSelected:
                _visibleFiles.isNotEmpty &&
                _visibleFiles.every(
                  (file) => _selectedPaths.contains(file.path),
                ),
            onClose: _clearSelection,
            onSelectAll: () {
              setState(() {
                if (_visibleFiles.every(
                  (file) => _selectedPaths.contains(file.path),
                )) {
                  _selectedPaths.clear();
                } else {
                  _selectedPaths
                    ..clear()
                    ..addAll(_visibleFiles.map((file) => file.path));
                }
              });
            },
            onDelete: _deleteSelected,
          ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_initializing || (_loading && _files.isEmpty && _error == null)) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 2, bottom: 24),
        itemCount: 8,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SkeletonItem(width: double.infinity, height: 54),
        ),
      );
    }
    if (_error != null && _files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.06),
          AppEmptyState(
            icon: TablerIcons.alert_triangle,
            title: l10n.ssh_files_loadFailed,
            subtitle: '$_error',
            actionLabel: l10n.common_retry,
            onAction: () => _load(showLoading: true),
          ),
        ],
      );
    }

    final visible = _visibleFiles;
    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          AppEmptyState(
            icon: _query.isEmpty ? TablerIcons.folder_open : TablerIcons.search,
            title: _query.isEmpty
                ? l10n.ssh_files_empty
                : l10n.files_noSearchResultsTitle,
            subtitle: _query.isEmpty
                ? null
                : l10n.files_noSearchResultsSubtitle,
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverPadding(
          padding: const EdgeInsets.only(top: 2, bottom: 24),
          sliver: SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final file = visible[index];
              return _FileRow(
                file: file,
                selected: _selectedPaths.contains(file.path),
                selectionMode: _selectionMode,
                onTap: () {
                  if (_selectionMode) {
                    _toggleSelection(file);
                  } else if (file.isDirectory) {
                    _navigateTo(file.path);
                  } else {
                    _openFile(file);
                  }
                },
                onLongPress: () => _toggleSelection(file),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PathBreadcrumb extends StatelessWidget {
  const _PathBreadcrumb({required this.path, required this.onNavigate});

  final String path;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (path == '.' || path.isEmpty) {
      return Text(
        l10n.ssh_files_home,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryLabel(context),
        ),
      );
    }
    final segments = sshPathSegments(path);
    final items = <Widget>[_crumb(context, '/', '/', isFirst: true)];
    var built = '';
    for (var i = 0; i < segments.length; i++) {
      built = '$built/${segments[i]}';
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            TablerIcons.chevron_right,
            size: 12,
            color: AppColors.tertiaryLabel(context),
          ),
        ),
      );
      items.add(
        _crumb(context, segments[i], built, isLast: i == segments.length - 1),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }

  Widget _crumb(
    BuildContext context,
    String label,
    String target, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: isLast ? null : () => onNavigate(target),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
            color: isLast
                ? AppColors.label(context)
                : AppColors.secondaryLabel(context),
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final SshRemoteFile file;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final color = file.isDirectory
        ? CupertinoColors.systemOrange.resolveFrom(context)
        : _fileColor(context, file.name);
    final icon = file.isDirectory ? TablerIcons.folder : _fileIcon(file.name);
    final meta = <String>[
      if (file.modifiedAt != null)
        DateFormat('MM-dd HH:mm').format(file.modifiedAt!),
      if (file.isDirectory && file.permissions.isNotEmpty) file.permissions,
      if (!file.isDirectory) Formatter.adaptiveBytes(file.size),
    ];

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? CupertinoColors.activeBlue.withValues(
                  alpha: isDark ? 0.15 : 0.08,
                )
              : null,
          border: Border(
            bottom: BorderSide(
              color: AppColors.separator(context).withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              _SelectionIndicator(selected: selected),
              const SizedBox(width: 14),
            ],
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label(context),
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta.join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!selectionMode)
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.tertiaryLabel(context),
              ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    return switch (extension) {
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'svg' => TablerIcons.photo,
      'dart' ||
      'js' ||
      'ts' ||
      'py' ||
      'go' ||
      'rs' ||
      'sh' ||
      'yml' ||
      'yaml' ||
      'json' ||
      'conf' ||
      'ini' => TablerIcons.file_code,
      'zip' || 'tar' || 'gz' || '7z' || 'rar' => TablerIcons.file_zip,
      _ => TablerIcons.file,
    };
  }

  Color _fileColor(BuildContext context, String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    if (const {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'svg',
    }.contains(extension)) {
      return CupertinoColors.systemPink.resolveFrom(context);
    }
    if (const {
      'dart',
      'js',
      'ts',
      'py',
      'go',
      'rs',
      'sh',
      'yml',
      'yaml',
      'json',
      'conf',
      'ini',
    }.contains(extension)) {
      return CupertinoColors.systemBlue.resolveFrom(context);
    }
    if (const {'zip', 'tar', 'gz', '7z', 'rar'}.contains(extension)) {
      return CupertinoColors.systemPurple.resolveFrom(context);
    }
    return AppColors.secondaryLabel(context);
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? CupertinoColors.activeBlue : null,
        border: Border.all(
          color: selected
              ? CupertinoColors.activeBlue
              : AppColors.separator(context).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(
              CupertinoIcons.checkmark,
              size: 14,
              color: CupertinoColors.white,
            )
          : null,
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.allSelected,
    required this.onClose,
    required this.onSelectAll,
    required this.onDelete,
  });

  final int count;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.separator(context).withValues(alpha: 0.14),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: onClose,
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.files_selectedCount(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label(context),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              onPressed: onSelectAll,
              child: Text(
                allSelected ? l10n.files_clearSelection : l10n.files_selectAll,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: onDelete,
              child: Icon(
                TablerIcons.trash,
                size: 19,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SshFileActionsSheet extends StatelessWidget {
  const _SshFileActionsSheet({required this.file});

  final SshRemoteFile file;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = file.isDirectory
        ? CupertinoColors.systemOrange.resolveFrom(context)
        : CupertinoColors.activeBlue.resolveFrom(context);
    final details = [
      if (!file.isDirectory) Formatter.adaptiveBytes(file.size),
      if (file.permissions.isNotEmpty) file.permissions,
    ].join('  ·  ');

    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      infoCard: ActionSheetInfoCard(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            file.isDirectory ? TablerIcons.folder : TablerIcons.file,
            size: 30,
            color: color,
          ),
        ),
        title: file.name,
        subtitle: details.isEmpty ? '--' : details,
        trailing: const SizedBox.shrink(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: AppActionGroup(
          children: [
            AppActionRow(
              icon: TablerIcons.download,
              iconColor: CupertinoColors.activeBlue,
              title: l10n.ssh_files_download,
              subtitle: Text(l10n.ssh_files_downloadHint),
              enabled: !file.isDirectory,
              onTap: () => Navigator.of(context).pop('download'),
            ),
            AppActionRow(
              icon: TablerIcons.edit,
              iconColor: CupertinoColors.activeBlue,
              title: l10n.ssh_files_edit,
              subtitle: Text(l10n.ssh_files_editHint),
              enabled: !file.isDirectory,
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            AppActionRow(
              icon: TablerIcons.cursor_text,
              iconColor: CupertinoColors.systemOrange,
              title: l10n.ssh_files_rename,
              subtitle: Text(l10n.ssh_files_renameHint),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            AppActionRow(
              icon: TablerIcons.trash,
              iconColor: CupertinoColors.systemRed,
              title: l10n.ssh_files_delete,
              subtitle: Text(l10n.ssh_files_deleteHint),
              isDestructive: true,
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
  }
}
