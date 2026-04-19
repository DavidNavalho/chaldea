import 'package:flutter/material.dart';

import 'package:chaldea/models/db.dart';

import '../box_coverage_models.dart';
import 'coverage_cell_sheet.dart';

class CoverageTable extends StatelessWidget {
  final BoxCoverageTableModel table;

  const CoverageTable({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final columns = table.columns;
    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(180),
      for (var index = 0; index < columns.length; index++) index + 1: const FixedColumnWidth(110),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(table.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(color: Theme.of(context).dividerColor),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: columnWidths,
                  children: [
                    _buildGroupHeaderRow(context),
                    _buildColumnHeaderRow(context),
                    for (final row in table.rows) _buildDataRow(context, row, columns),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildGroupHeaderRow(BuildContext context) {
    final cells = <Widget>[_headerCell(context, '')];
    for (final group in table.columnGroups) {
      for (var index = 0; index < group.columns.length; index++) {
        cells.add(_headerCell(context, index == 0 ? group.label : ''));
      }
    }
    return TableRow(children: cells);
  }

  TableRow _buildColumnHeaderRow(BuildContext context) {
    final cells = <Widget>[
      _headerCell(context, switch (table.kind) {
        BoxCoverageTableKind.classCapability => 'Class',
        _ => 'Target',
      }),
    ];
    for (final group in table.columnGroups) {
      for (final column in group.columns) {
        cells.add(_headerCell(context, column.label));
      }
    }
    return TableRow(children: cells);
  }

  TableRow _buildDataRow(BuildContext context, BoxCoverageRowModel row, List<BoxCoverageColumn> columns) {
    final cells = <Widget>[_rowLabelCell(context, row)];
    for (var index = 0; index < row.cells.length; index++) {
      final cell = row.cells[index];
      final column = columns[index];
      cells.add(_dataCell(context, row, column, cell));
    }
    return TableRow(children: cells);
  }

  Widget _headerCell(BuildContext context, String text) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _rowLabelCell(BuildContext context, BoxCoverageRowModel row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          db.getIconImage(row.classIcon, width: 22, height: 22, aspectRatio: 1),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCell(BuildContext context, BoxCoverageRowModel row, BoxCoverageColumn column, BoxCoverageCellModel cell) {
    final background = _cellColor(cell);
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _primaryValue(cell),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text('NP ${cell.maxNpGain}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black87)),
      ],
    );

    return InkWell(
      onTap: cell.hasData
          ? () => CoverageCellSheet.show(
              context: context,
              tableTitle: table.title,
              rowLabel: row.label,
              columnLabel: _columnLabel(column),
              cell: cell,
            )
          : null,
      child: Container(
        height: 72,
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Center(child: content),
      ),
    );
  }

  String _primaryValue(BoxCoverageCellModel cell) {
    if (table.kind == BoxCoverageTableKind.multiplier) {
      if (cell.bestMultiplier == null) return '-';
      return 'x${_formatMultiplier(cell.bestMultiplier!)}';
    }
    return cell.count.toString();
  }

  String _columnLabel(BoxCoverageColumn column) {
    final target = column.npTarget?.label;
    return target == null ? column.label : '$target • ${column.label}';
  }

  Color _cellColor(BoxCoverageCellModel cell) {
    if (table.kind == BoxCoverageTableKind.multiplier) {
      final multiplier = cell.bestMultiplier;
      if (multiplier == null || multiplier < 1.0) {
        return const Color(0xFFF4B4B4);
      }
      if (multiplier == 1.0) {
        return const Color(0xFFF7E39A);
      }
      if (multiplier == 1.5) {
        return const Color(0xFFB9D9FF);
      }
      return const Color(0xFFBDE7A3);
    }
    if (cell.count == 0) {
      return const Color(0xFFF4B4B4);
    }
    return const Color(0xFFBDE7A3);
  }

  static String _formatMultiplier(double multiplier) {
    return multiplier.toStringAsFixed(multiplier.truncateToDouble() == multiplier ? 1 : 2);
  }
}
