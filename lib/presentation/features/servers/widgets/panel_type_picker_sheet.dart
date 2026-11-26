import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/panel_type.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_meta_chip.dart';

/// 面板类型的展示信息与选择弹窗。
///
/// 目前只开放 1Panel，宝塔与纯服务器以「即将支持」占位，后续接入新的
/// 面板实现时只需翻转 [PanelType.supported] 并补充对应的连接表单。
extension PanelTypePresentation on PanelType {
  String label(AppLocalizations l10n) => switch (this) {
    PanelType.onePanel => l10n.servers_panelType_onePanel,
    PanelType.baota => l10n.servers_panelType_baota,
    PanelType.bareMetal => l10n.servers_panelType_bareMetal,
  };

  String description(AppLocalizations l10n) => switch (this) {
    PanelType.onePanel => l10n.servers_panelType_onePanelDescription,
    PanelType.baota => l10n.servers_panelType_baotaDescription,
    PanelType.bareMetal => l10n.servers_panelType_bareMetalDescription,
  };

  IconData get icon => switch (this) {
    PanelType.onePanel => TablerIcons.layout_dashboard,
    PanelType.baota => TablerIcons.server_cog,
    PanelType.bareMetal => TablerIcons.terminal,
  };

  Color color(BuildContext context) => switch (this) {
    PanelType.onePanel => CupertinoColors.activeBlue.resolveFrom(context),
    PanelType.baota => CupertinoColors.systemGreen.resolveFrom(context),
    PanelType.bareMetal => CupertinoColors.systemOrange.resolveFrom(context),
  };
}

/// 打开面板类型选择器，返回用户选择的类型；取消时返回 `null`。
Future<PanelType?> showPanelTypePicker(BuildContext context) {
  return showActionSheet<PanelType>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _PanelTypePickerSheet(),
  );
}

class _PanelTypePickerSheet extends StatelessWidget {
  const _PanelTypePickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: false,
      isFloating: true,
      contentPadding: EdgeInsets.zero,
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 10, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.servers_choosePanelTypeTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label(context),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.common_cancel,
                style: TextStyle(
                  color: AppColors.secondaryLabel(context),
                  fontSize: 15,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Text(
              l10n.servers_choosePanelTypeSubtitle,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ),
          for (final type in PanelType.values)
            _PanelTypeTile(
              type: type,
              onTap: () => Navigator.of(context).pop(type),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PanelTypeTile extends StatelessWidget {
  const _PanelTypeTile({required this.type, required this.onTap});

  final PanelType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = type.supported;
    final color = type.color(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground(
              context,
            ).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.separator(context).withValues(alpha: 0.14),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(type.icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label(l10n),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.description(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!enabled)
                AppMetaChip(
                  label: l10n.servers_comingSoon,
                  color: AppColors.secondaryLabel(context),
                  height: 20,
                  fontSize: 10,
                )
              else
                Icon(
                  TablerIcons.chevron_right,
                  size: 16,
                  color: AppColors.tertiaryLabel(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
