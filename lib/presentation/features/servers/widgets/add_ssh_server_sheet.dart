import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/server_host_normalizer.dart';
import '../../../../core/widgets/app_toggle_switch.dart';
import '../../../../data/repositories_impl/server_repository_impl.dart';
import '../../../../data/services/ssh/ssh_connection.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../../domain/entities/panel_type.dart';
import '../../../../domain/entities/server.dart';
import '../../../../domain/entities/ssh_credentials.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/cupertino_grouped_form.dart';
import '../providers/servers_provider.dart';
import '../providers/ssh_servers_provider.dart';

class AddSshServerSheet extends ConsumerStatefulWidget {
  const AddSshServerSheet({super.key, this.server});

  final Server? server;

  static Future<void> show(BuildContext context) {
    return showActionSheet(
      context: context,
      expand: false,
      builder: (context) => const AddSshServerSheet(),
    );
  }

  static Future<void> edit(BuildContext context, Server server) {
    return showActionSheet(
      context: context,
      expand: false,
      builder: (context) => AddSshServerSheet(server: server),
    );
  }

  @override
  ConsumerState<AddSshServerSheet> createState() => _AddSshServerSheetState();
}

class _AddSshServerSheetState extends ConsumerState<AddSshServerSheet> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _userController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();

  SshAuthType _authType = SshAuthType.password;
  late SshAuthType _initialAuthType;
  SshCredentials? _existingCredentials;
  bool _obscurePassword = true;
  bool _loading = false;
  bool _credentialsLoading = false;
  bool _resetHostKey = false;

  bool get _isEditing => widget.server != null;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    if (server == null) {
      _initialAuthType = SshAuthType.password;
      return;
    }
    _nameController.text = server.name ?? '';
    _hostController.text = server.host;
    _portController.text = server.port.toString();
    _userController.text = server.sshUsername;
    _authType = server.sshAuthType;
    _initialAuthType = server.sshAuthType;
    _loadCredentials(server.id);
  }

  Future<void> _loadCredentials(int serverId) async {
    setState(() => _credentialsLoading = true);
    try {
      final credentials = await ref
          .read(serverRepositoryProvider)
          .getSshCredentials(serverId);
      if (!mounted) return;
      setState(() {
        _existingCredentials = credentials;
      });
    } catch (error) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.ssh_credentialsLoadFailed,
          description: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _credentialsLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _importPrivateKey() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (!mounted) return;
      _privateKeyController.text = text;
      setState(() => _authType = SshAuthType.privateKey);
      showAppSuccessToast(context.l10n.ssh_keyImported);
    } catch (error) {
      if (mounted) {
        showAppErrorToast(
          context.l10n.ssh_keyImportFailed,
          description: '$error',
        );
      }
    }
  }

  (String, int, String?, bool) _parseHostInput() {
    var raw = _hostController.text.trim();
    raw = raw.replaceFirst(RegExp(r'^ssh://', caseSensitive: false), '');
    String? inlineUser;
    final at = raw.lastIndexOf('@');
    if (at > 0) {
      inlineUser = raw.substring(0, at).trim();
      raw = raw.substring(at + 1);
    }
    final address = parseServerAddressInput(raw);
    final port =
        address.port ?? int.tryParse(_portController.text.trim()) ?? 22;
    return (address.host, port, inlineUser, address.isPortInvalid);
  }

  SshCredentials _credentialsForSubmit() {
    final sameAuthType =
        _isEditing &&
        _authType == _initialAuthType &&
        _existingCredentials != null;
    final password = _passwordController.text.isEmpty && sameAuthType
        ? _existingCredentials!.password
        : _passwordController.text;
    final privateKey = _privateKeyController.text.trim().isEmpty && sameAuthType
        ? _existingCredentials!.privateKey
        : _privateKeyController.text.trim();
    final passphrase = _passphraseController.text.isEmpty && sameAuthType
        ? _existingCredentials!.passphrase
        : _passphraseController.text;
    return SshCredentials(
      password: password,
      privateKey: privateKey,
      passphrase: passphrase,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final (host, port, inlineUser, hostPortInvalid) = _parseHostInput();
    final user = inlineUser?.isNotEmpty == true
        ? inlineUser!
        : _userController.text.trim();

    if (host.isEmpty) {
      showAppErrorToast(l10n.servers_hostRequired);
      return;
    }
    if (hostPortInvalid) {
      showAppErrorToast(l10n.servers_portInvalid);
      return;
    }
    if (user.isEmpty) {
      showAppErrorToast(l10n.ssh_userRequired);
      return;
    }
    if (port < 1 || port > 65535) {
      showAppErrorToast(l10n.servers_portInvalid);
      return;
    }
    final credentials = _credentialsForSubmit();
    if (_authType == SshAuthType.password && credentials.password.isEmpty) {
      showAppErrorToast(l10n.ssh_passwordRequired);
      return;
    }
    if (_authType == SshAuthType.privateKey && credentials.privateKey.isEmpty) {
      showAppErrorToast(l10n.ssh_privateKeyRequired);
      return;
    }

    final previous = widget.server;
    final hostChanged =
        previous == null || previous.host != host || previous.port != port;
    final expectedHostKey = previous == null || _resetHostKey
        ? ''
        : (hostChanged ? '' : previous.sshHostKey);

    setState(() => _loading = true);
    SshConnection? probeConnection;
    String? pinnedHostKey;
    try {
      final probeServer = Server()
        ..host = host
        ..port = port
        ..panelType = PanelType.bareMetal
        ..sshUsername = user
        ..sshAuthType = _authType
        ..sshHostKey = expectedHostKey;

      probeConnection = await SshConnection.connect(
        server: probeServer,
        credentials: credentials,
        onPinHostKey: (fingerprint) async {
          pinnedHostKey = fingerprint;
        },
      );
      final result = await probeConnection.run(
        'echo __ft_ssh_ok__',
        timeout: const Duration(seconds: 8),
      );
      if (!result.stdout.contains('__ft_ssh_ok__')) {
        throw SshConnectionException('服务器未返回预期结果', result.stderr.trim());
      }
      if (!mounted) return;

      final repository = ref.read(serverRepositoryProvider);
      final manager = ref.read(sshConnectionManagerProvider);
      final name = _nameController.text.trim();
      late int savedId;

      if (_isEditing) {
        final server = previous!
          ..name = name.isEmpty ? null : name
          ..host = host
          ..port = port
          ..panelType = PanelType.bareMetal
          ..sshUsername = user
          ..sshAuthType = _authType
          ..sshHostKey = pinnedHostKey ?? expectedHostKey;
        await repository.update(server);
        await repository.saveSshCredentials(server.id, credentials);
        savedId = server.id;
        manager.invalidate(server.id);
      } else {
        final server = await repository.addSsh(
          name: name.isEmpty ? null : name,
          host: host,
          port: port,
          username: user,
          authType: _authType,
          credentials: credentials,
          hostKey: pinnedHostKey ?? '',
        );
        savedId = server.id;
      }

      await probeConnection.close();
      probeConnection = null;
      ref.invalidate(sshDashboardSnapshotProvider(savedId));
      ref.invalidate(serversNotifierProvider);
      if (!mounted) return;
      showAppSuccessToast(_isEditing ? l10n.ssh_saved : l10n.ssh_added);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      if (error is SshHostKeyMismatchException) {
        showAppErrorToast(
          l10n.ssh_hostKeyMismatchTitle,
          description: l10n.ssh_hostKeyMismatchMessage,
        );
      } else {
        final detail = error is SshConnectionException
            ? error.toString()
            : '$error';
        showAppErrorToast(l10n.ssh_connectFailed, description: detail);
      }
    } finally {
      await probeConnection?.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ActionSheetScaffold(
      showHandle: false,
      isAdaptive: true,
      isFloating: true,
      hasHorizontalPadding: true,
      contentPadding: EdgeInsets.zero,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                child: Text(
                  l10n.common_cancel,
                  style: TextStyle(
                    color: _loading
                        ? AppColors.tertiaryLabel(context)
                        : AppColors.secondaryLabel(context),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Text(
              _loading
                  ? l10n.ssh_connecting
                  : (_isEditing ? l10n.ssh_editTitle : l10n.ssh_addTitle),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.label(context),
                letterSpacing: -0.4,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _loading || _credentialsLoading ? null : _submit,
                child: _loading
                    ? const CupertinoActivityIndicator(radius: 10)
                    : Text(
                        _isEditing ? l10n.common_save : l10n.common_create,
                        style: TextStyle(
                          color: CupertinoColors.activeBlue.resolveFrom(
                            context,
                          ),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCupertinoSectionHeader(title: l10n.ssh_connectionSection),
          AppCupertinoGroupedBox(
            children: [
              AppCupertinoFormTile(
                label: l10n.servers_name,
                child: _field(
                  controller: _nameController,
                  placeholder: l10n.servers_namePlaceholder,
                  textInputAction: TextInputAction.next,
                ),
              ),
              AppCupertinoFormTile(
                label: l10n.servers_host,
                child: _field(
                  controller: _hostController,
                  placeholder: l10n.ssh_hostPlaceholder,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
              ),
              AppCupertinoFormTile(
                label: l10n.servers_port,
                child: _field(
                  controller: _portController,
                  placeholder: '22',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                ),
              ),
              AppCupertinoFormTile(
                label: l10n.ssh_user,
                isLast: true,
                child: _field(
                  controller: _userController,
                  placeholder: l10n.ssh_userPlaceholder,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppCupertinoSectionHeader(title: l10n.ssh_authSection),
          AppCupertinoGroupedBox(
            children: [
              AppCupertinoFormTile(
                label: l10n.ssh_authMethod,
                child: _authTypeSelector(),
              ),
              if (_authType == SshAuthType.password)
                AppCupertinoFormTile(
                  label: l10n.ssh_password,
                  isLast: true,
                  child: _field(
                    controller: _passwordController,
                    placeholder: l10n.ssh_passwordPlaceholder,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    suffix: CupertinoButton(
                      padding: const EdgeInsets.only(right: 8),
                      minimumSize: Size.zero,
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        size: 18,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ),
                )
              else ...[
                AppCupertinoFormTile(
                  label: l10n.ssh_privateKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: CupertinoTextField(
                          controller: _privateKeyController,
                          placeholder: l10n.ssh_privateKeyPlaceholder,
                          maxLines: 5,
                          minLines: 5,
                          padding: const EdgeInsets.all(10),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Menlo',
                            color: AppColors.label(context),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryBackground(
                              context,
                            ).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          autocorrect: false,
                          enableSuggestions: false,
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.only(bottom: 10),
                        minimumSize: Size.zero,
                        onPressed: _loading ? null : _importPrivateKey,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.doc_text,
                              size: 15,
                              color: CupertinoColors.activeBlue.resolveFrom(
                                context,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n.ssh_importKey,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.activeBlue.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AppCupertinoFormTile(
                  label: l10n.ssh_passphrase,
                  isLast: true,
                  child: _field(
                    controller: _passphraseController,
                    placeholder: l10n.ssh_passphrasePlaceholder,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ],
          ),
          if (_isEditing &&
              _existingCredentials != null &&
              _authType == _initialAuthType)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                l10n.ssh_keepSecretHint,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
            ),
          if (_isEditing && previousHasHostKey) ...[
            const SizedBox(height: 12),
            AppCupertinoGroupedBox(
              children: [
                _HostKeyResetRow(
                  title: l10n.ssh_hostKeyReset,
                  subtitle: l10n.ssh_hostKeyResetHint,
                  value: _resetHostKey,
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _resetHostKey = value),
                  isLast: true,
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              l10n.ssh_hostKeyHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool get previousHasHostKey =>
      widget.server != null && widget.server!.sshHostKey.trim().isNotEmpty;

  Widget _field({
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return SizedBox(
      height: 44,
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        suffix: suffix,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(fontSize: 15, color: AppColors.label(context)),
        decoration: const BoxDecoration(),
        autocorrect: false,
        enableSuggestions: !obscureText,
      ),
    );
  }

  Widget _authTypeSelector() {
    final l10n = context.l10n;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.label(context),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: CupertinoSlidingSegmentedControl<SshAuthType>(
        groupValue: _authType,
        backgroundColor: AppColors.tertiaryBackground(
          context,
        ).withValues(alpha: 0.4),
        children: {
          SshAuthType.password: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            child: Text(l10n.ssh_authPassword, style: style),
          ),
          SshAuthType.privateKey: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            child: Text(l10n.ssh_authPrivateKey, style: style),
          ),
        },
        onValueChanged: (value) {
          if (_loading || value == null) return;
          setState(() => _authType = value);
        },
      ),
    );
  }
}

class _HostKeyResetRow extends StatelessWidget {
  const _HostKeyResetRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.label(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppToggleSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              height: 0.5,
              color: AppColors.separator(context).withValues(alpha: 0.1),
            ),
          ),
      ],
    );
  }
}
