import 'package:flutter/material.dart';

import 'package:chaldea/app/app.dart';
import 'package:chaldea/models/db.dart';
import 'package:chaldea/models/gamedata/common.dart';

import '../box_coverage_models.dart';

class CoverageCellSheet extends StatelessWidget {
  final String tableTitle;
  final String rowLabel;
  final String columnLabel;
  final BoxCoverageCellModel cell;

  const CoverageCellSheet({
    super.key,
    required this.tableTitle,
    required this.rowLabel,
    required this.columnLabel,
    required this.cell,
  });

  static Future<void> show({
    required BuildContext context,
    required String tableTitle,
    required String rowLabel,
    required String columnLabel,
    required BoxCoverageCellModel cell,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          CoverageCellSheet(tableTitle: tableTitle, rowLabel: rowLabel, columnLabel: columnLabel, cell: cell),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tableTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('$rowLabel • $columnLabel', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(_summaryText(cell), style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: cell.contributors.isEmpty
                  ? Center(child: Text('No matching servants.', style: theme.textTheme.bodyLarge))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) => _ContributorTile(contributor: cell.contributors[index]),
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemCount: cell.contributors.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _summaryText(BoxCoverageCellModel cell) {
    final leading = cell.bestMultiplier == null
        ? '${cell.count} servant${cell.count == 1 ? '' : 's'}'
        : 'Best multiplier x${_formatMultiplier(cell.bestMultiplier!)}';
    return '$leading • Max NP charge ${cell.maxNpGain}%';
  }

  static String _formatMultiplier(double multiplier) {
    return multiplier.toStringAsFixed(multiplier.truncateToDouble() == multiplier ? 1 : 2);
  }
}

class _ContributorTile extends StatelessWidget {
  final BoxCoverageContributor contributor;

  const _ContributorTile({required this.contributor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 60,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contributor.classIcon != null)
              db.getIconImage(contributor.classIcon, width: 20, height: 20, aspectRatio: 1),
            if (contributor.classIcon != null) const SizedBox(width: 6),
            Expanded(child: db.getIconImage(contributor.faceIcon, width: 34, height: 34, aspectRatio: 132 / 144)),
          ],
        ),
      ),
      title: Text(contributor.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(contributor), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: contributor.multiplier == null
          ? null
          : Text(
              'x${CoverageCellSheet._formatMultiplier(contributor.multiplier!)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
      onTap: () {
        Navigator.of(context).pop();
        router.push(url: Routes.servantI(contributor.servantId));
      },
    );
  }

  static String _subtitle(BoxCoverageContributor contributor) {
    final parts = <String>[
      '${contributor.rarity}-star',
      _classLabel(contributor.classId),
      contributor.npTarget.label,
      _cardLabel(contributor.npCard),
      'NP${contributor.npLevel}',
      'Charge ${contributor.totalNpGain}%',
    ];
    if (contributor.multiplier != null) {
      parts.add('x${CoverageCellSheet._formatMultiplier(contributor.multiplier!)}');
    }
    return parts.join(' • ');
  }

  static String _classLabel(int classId) {
    return switch (SvtClass.fromInt(classId) ?? SvtClass.none) {
      SvtClass.alterego => 'Alter Ego',
      SvtClass.moonCancer => 'Moon Cancer',
      SvtClass.beastAny || SvtClass.beastDoraco => 'Beast',
      _ => (SvtClass.fromInt(classId) ?? SvtClass.none).name,
    };
  }

  static String _cardLabel(CardType cardType) {
    return switch (cardType) {
      CardType.arts => 'Arts',
      CardType.buster => 'Buster',
      CardType.quick => 'Quick',
      _ => cardType.name,
    };
  }
}
