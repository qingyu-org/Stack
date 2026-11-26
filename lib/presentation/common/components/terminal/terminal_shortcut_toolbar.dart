import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:xterm/xterm.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';

class TerminalShortcutToolbar extends StatelessWidget {
  const TerminalShortcutToolbar({
    super.key,
    required this.enabled,
    required this.onKey,
    required this.onCopy,
    required this.onPaste,
    this.includeBottomSafeArea = true,
  });

  final bool enabled;
  final void Function(TerminalKey key, {bool ctrl, bool alt, bool shift}) onKey;
  final VoidCallback onCopy;
  final VoidCallback onPaste;

  /// 页面底部已有标签栏/键盘处理安全区时设为 false，避免重复留白。
  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : CupertinoColors.black.withValues(alpha: 0.08);
    final backgroundColor = AppColors.secondaryBackground(
      context,
    ).withValues(alpha: isDark ? 0.78 : 0.9);

    return SafeArea(
      top: false,
      bottom: includeBottomSafeArea,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            _ShortcutButton.icon(
              icon: CupertinoIcons.doc_on_doc,
              tooltip: context.l10n.terminal_copySelection,
              enabled: enabled,
              onPressed: onCopy,
            ),
            _ShortcutButton.icon(
              icon: CupertinoIcons.doc_on_clipboard,
              tooltip: context.l10n.terminal_pasteToTerminal,
              enabled: enabled,
              onPressed: onPaste,
            ),
            _ShortcutButton.text(
              label: 'Enter',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.enter),
            ),
            _ShortcutButton.text(
              label: 'Esc',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.escape),
            ),
            _ShortcutButton.text(
              label: 'Tab',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.tab),
            ),
            _ShortcutButton.text(
              label: 'Ctrl+C',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.keyC, ctrl: true),
            ),
            _ShortcutButton.text(
              label: 'Ctrl+D',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.keyD, ctrl: true),
            ),
            _ShortcutButton.text(
              label: 'Ctrl+L',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.keyL, ctrl: true),
            ),
            _ShortcutButton.icon(
              icon: CupertinoIcons.arrow_left,
              tooltip: 'Left',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowLeft),
            ),
            _ShortcutButton.icon(
              icon: CupertinoIcons.arrow_down,
              tooltip: 'Down',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowDown),
            ),
            _ShortcutButton.icon(
              icon: CupertinoIcons.arrow_up,
              tooltip: 'Up',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowUp),
            ),
            _ShortcutButton.icon(
              icon: CupertinoIcons.arrow_right,
              tooltip: 'Right',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.arrowRight),
            ),
            _ShortcutButton.text(
              label: 'Home',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.home),
            ),
            _ShortcutButton.text(
              label: 'End',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.end),
            ),
            _ShortcutButton.text(
              label: 'Del',
              enabled: enabled,
              onPressed: () => onKey(TerminalKey.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton.text({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) : this._(
         label: label,
         tooltip: label,
         enabled: enabled,
         onPressed: onPressed,
       );

  const _ShortcutButton.icon({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) : this._(
         icon: icon,
         tooltip: tooltip,
         enabled: enabled,
         onPressed: onPressed,
       );

  const _ShortcutButton._({
    this.label,
    this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = enabled
        ? AppColors.label(context)
        : AppColors.tertiaryLabel(context);
    final backgroundColor = AppColors.tertiaryBackground(
      context,
    ).withValues(alpha: enabled ? 0.88 : 0.45);

    final child = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: label == null ? const Size(36, 36) : const Size(0, 36),
      borderRadius: BorderRadius.circular(8),
      color: backgroundColor,
      disabledColor: backgroundColor,
      onPressed: enabled ? onPressed : null,
      child: SizedBox(
        height: 36,
        width: label == null ? 36 : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
          child: Center(
            child: icon == null
                ? Text(
                    label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      color: foregroundColor,
                    ),
                  )
                : Icon(icon, size: 17, color: foregroundColor),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(message: tooltip, child: child),
    );
  }
}
