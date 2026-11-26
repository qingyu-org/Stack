import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:xterm/xterm.dart';

import '../../../../core/localization/l10n_x.dart';

import '../../../../data/services/ssh/ssh_connection.dart';
import '../../../../data/services/ssh/ssh_connection_manager.dart';
import '../../../common/components/terminal/terminal_shortcut_toolbar.dart';

class SshTerminalTab extends ConsumerStatefulWidget {
  const SshTerminalTab({
    super.key,
    required this.serverId,
    required this.isActive,
  });

  final int serverId;
  final bool isActive;

  @override
  ConsumerState<SshTerminalTab> createState() => _SshTerminalTabState();
}

enum _TerminalStatus { connecting, connected, disconnected }

class _SshTerminalTabState extends ConsumerState<SshTerminalTab> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  final TerminalController _terminalController = TerminalController();
  final FocusNode _focusNode = FocusNode();

  SSHSession? _session;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  _TerminalStatus _status = _TerminalStatus.connecting;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = _handleOutput;
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      try {
        _session?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      } catch (_) {
        // 会话关闭时的尺寸更新忽略即可。
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connect();
    });
  }

  @override
  void dispose() {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _session?.close();
    _terminalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleOutput(String data) {
    final session = _session;
    if (session == null || _status != _TerminalStatus.connected) return;
    try {
      session.stdin.add(Uint8List.fromList(utf8.encode(data)));
    } catch (_) {
      // 会话刚好断开时忽略按键输入。
    }
  }

  Future<void> _connect() async {
    setState(() {
      _status = _TerminalStatus.connecting;
      _error = '';
    });

    try {
      final manager = ref.read(sshConnectionManagerProvider);
      final connection = await manager.get(widget.serverId);
      final session = await connection.openShell(
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
      );
      if (!mounted) {
        session.close();
        return;
      }
      _session = session;
      try {
        session.resizeTerminal(_terminal.viewWidth, _terminal.viewHeight);
      } catch (_) {
        // 旧服务端可能拒绝窗口尺寸变更，保持默认尺寸即可。
      }
      _stdoutSubscription = _terminalDecodedStream(
        session.stdout,
      ).listen(_terminal.write);
      _stderrSubscription = _terminalDecodedStream(
        session.stderr,
      ).listen(_terminal.write);
      session.done.then(
        (_) {
          if (!mounted || !identical(_session, session)) return;
          setState(() {
            _status = _TerminalStatus.disconnected;
            _error = '';
          });
        },
        onError: (Object error) {
          if (!mounted || !identical(_session, session)) return;
          setState(() {
            _status = _TerminalStatus.disconnected;
            _error = '$error';
          });
        },
      );
      setState(() => _status = _TerminalStatus.connected);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _TerminalStatus.disconnected;
        _error = error is SshConnectionException ? error.toString() : '$error';
      });
      _terminal.write('\r\n${context.l10n.ssh_terminal_failed}: $_error\r\n');
    }
  }

  Stream<String> _terminalDecodedStream(Stream<Uint8List> stream) {
    return const Utf8Decoder(allowMalformed: true).bind(stream);
  }

  Future<void> _reconnect() async {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _session?.close();
    _session = null;
    ref.read(sshConnectionManagerProvider).invalidate(widget.serverId);
    _terminal.write('\r\n\x1b[2J\x1b[H');
    await _connect();
    _focusNode.requestFocus();
  }

  Future<void> _copy() async {
    final selection = _terminalController.selection;
    final text = selection != null
        ? _terminal.buffer.getText(selection)
        : _terminal.buffer.getText();
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _terminal.paste(text);
  }

  void _sendKey(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    _focusNode.requestFocus();
    _terminal.keyInput(key, ctrl: ctrl, alt: alt, shift: shift);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          if (_status != _TerminalStatus.connected)
            _TerminalStatusBar(
              status: _status,
              error: _error,
              onRetry: _reconnect,
            ),
          Expanded(
            child: TerminalView(
              _terminal,
              controller: _terminalController,
              focusNode: _focusNode,
              textStyle: const TerminalStyle(fontSize: 14, fontFamily: 'Menlo'),
              deleteDetection: true,
              theme: isDark ? TerminalThemes.defaultTheme : _brightTheme,
            ),
          ),
          TerminalShortcutToolbar(
            enabled: _status == _TerminalStatus.connected,
            includeBottomSafeArea: false,
            onKey: _sendKey,
            onCopy: _copy,
            onPaste: _paste,
          ),
        ],
      ),
    );
  }
}

class _TerminalStatusBar extends StatelessWidget {
  const _TerminalStatusBar({
    required this.status,
    required this.error,
    required this.onRetry,
  });

  final _TerminalStatus status;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isConnecting = status == _TerminalStatus.connecting;
    final color = isConnecting
        ? CupertinoColors.systemOrange.resolveFrom(context)
        : CupertinoColors.systemRed.resolveFrom(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          if (isConnecting)
            const SizedBox(
              width: 12,
              height: 12,
              child: CupertinoActivityIndicator(radius: 6),
            )
          else
            Icon(TablerIcons.alert_circle, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isConnecting
                  ? l10n.ssh_terminal_connecting
                  : (error.isEmpty ? l10n.ssh_terminal_disconnected : error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: color),
            ),
          ),
          if (!isConnecting)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              onPressed: onRetry,
              child: Text(
                l10n.ssh_terminal_retry,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _brightTheme = TerminalTheme(
  cursor: Color(0xFF000000),
  selection: Color(0x44000000),
  foreground: Color(0xFF000000),
  background: Color(0xFFF7F7F9),
  black: Color(0xFF000000),
  red: Color(0xFFCD3131),
  green: Color(0xFF0DBC79),
  yellow: Color(0xFF949400),
  blue: Color(0xFF0451A5),
  magenta: Color(0xFFBC05BC),
  cyan: Color(0xFF0598BC),
  white: Color(0xFF555555),
  brightBlack: Color(0xFF666666),
  brightRed: Color(0xFFCD3131),
  brightGreen: Color(0xFF14CE14),
  brightYellow: Color(0xFFB5BA00),
  brightBlue: Color(0xFF0451A5),
  brightMagenta: Color(0xFFBC05BC),
  brightCyan: Color(0xFF0598BC),
  brightWhite: Color(0xFFA5A5A5),
  searchHitBackground: Color(0xFFFFFF00),
  searchHitBackgroundCurrent: Color(0xFFFF9600),
  searchHitForeground: Color(0xFF000000),
);
