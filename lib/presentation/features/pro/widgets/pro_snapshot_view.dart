import 'package:flutter/cupertino.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/api/pro_api.dart';
import '../utils/pro_data_utils.dart';

class ProSnapshotView extends StatelessWidget {
  const ProSnapshotView({
    super.key,
    required this.snapshot,
    required this.sectionTitles,
    this.sectionOrder = const [],
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final ProSnapshot? snapshot;
  final Map<String, String> sectionTitles;
  final List<String> sectionOrder;
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (loading && data == null) {
      return const _ProLoadingCard();
    }
    if (data == null) {
      if (error != null) {
        return ProUnavailableView(description: '${error!}', onRetry: onRetry);
      }
      return const _ProEmptyCard();
    }
    if (!data.anySuccess) {
      return ProUnavailableView(onRetry: onRetry);
    }

    final labels = sectionOrder.isNotEmpty
        ? sectionOrder
        : data.sections.keys.toList(growable: false);
    final cards = <Widget>[
      for (final label in labels)
        if (data.sections.containsKey(label))
          ProSectionCard(
            title: sectionTitles[label] ?? _fallbackTitle(label),
            child: ProDataValue(data: data.sections[label]),
          ),
    ];
    if (cards.isEmpty) return const _ProEmptyCard();
    return Column(children: cards);
  }

  String _fallbackTitle(String label) {
    return label.isEmpty ? '-' : label[0].toUpperCase() + label.substring(1);
  }
}

class ProSectionCard extends StatelessWidget {
  const ProSectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.14),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class ProMetricGrid extends StatelessWidget {
  const ProMetricGrid({super.key, required this.metrics});

  final Map<String, num> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in metrics.entries)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryBackground(
                      context,
                    ).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatProValue(entry.value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppColors.label(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ProDataValue extends StatelessWidget {
  const ProDataValue({super.key, required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Text(
        context.l10n.pro_empty,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.secondaryLabel(context),
        ),
      );
    }
    final rows = extractProRows(data);
    if (data is Map) {
      final scalars = flattenProScalars(data);
      final metrics = <String, num>{};
      final info = <MapEntry<String, String>>[];
      for (final entry in scalars.entries) {
        final value = entry.value;
        if (value is num) {
          if (_isMetaKey(entry.key)) continue;
          final label = proMetricLabel(context, entry.key);
          metrics[label] = value;
        } else if (value is String || value is bool) {
          if (info.length >= 6) continue;
          final text = value.toString().trim();
          if (text.isEmpty || _isMetaKey(entry.key)) continue;
          info.add(MapEntry(entry.key, text));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metrics.isNotEmpty) ProMetricGrid(metrics: metrics),
          if (metrics.isNotEmpty && rows.isNotEmpty) const SizedBox(height: 12),
          if (rows.isNotEmpty) ProRowsList(rows: rows),
          if ((metrics.isNotEmpty || rows.isNotEmpty) && info.isNotEmpty)
            const SizedBox(height: 8),
          if (info.isNotEmpty) _ProInfoRows(rows: info),
          if (metrics.isEmpty && rows.isEmpty && info.isEmpty)
            Text(
              context.l10n.pro_empty,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryLabel(context),
              ),
            ),
        ],
      );
    }
    if (data is List) {
      if (rows.isEmpty) {
        return Text(
          formatProValue(data),
          style: TextStyle(fontSize: 12, color: AppColors.label(context)),
        );
      }
      return ProRowsList(rows: rows);
    }
    return Text(
      formatProValue(data),
      style: TextStyle(fontSize: 12, color: AppColors.label(context)),
    );
  }

  bool _isMetaKey(String key) {
    final normalized = key.toLowerCase().replaceAll('_', '');
    return const {
      'id',
      'code',
      'page',
      'pagesize',
      'statuscode',
      'websiteid',
      'nodeid',
      'groupid',
      'websitegroupid',
      'appid',
      'databaseid',
    }.contains(normalized);
  }
}

class ProRowsList extends StatelessWidget {
  const ProRowsList({super.key, required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        context.l10n.pro_empty,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.secondaryLabel(context),
        ),
      );
    }
    final visible = rows.take(20).toList(growable: false);
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0)
            Container(
              height: 0.5,
              color: AppColors.separator(context).withValues(alpha: 0.1),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proRowTitle(visible[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.label(context),
                        ),
                      ),
                      if (proRowSubtitle(visible[i]).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          proRowSubtitle(visible[i]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (rows.length > visible.length) ...[
          const SizedBox(height: 6),
          Text(
            proText(
              context,
              zh: '仅显示前 ${visible.length} 条 / ${rows.length} 条',
              en: 'Showing first ${visible.length} of ${rows.length}',
            ),
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.tertiaryLabel(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProInfoRows extends StatelessWidget {
  const _ProInfoRows({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.label(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ProUnavailableView extends StatelessWidget {
  const ProUnavailableView({super.key, this.description, this.onRetry});

  final String? description;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ProSectionCard(
      title: l10n.pro_unavailableTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons.lock_shield,
                size: 18,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description ?? l10n.pro_unavailableDescription,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onRetry,
              child: Text(l10n.nodes_retry),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProLoadingCard extends StatelessWidget {
  const _ProLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}

class _ProEmptyCard extends StatelessWidget {
  const _ProEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          context.l10n.pro_empty,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryLabel(context),
          ),
        ),
      ),
    );
  }
}
