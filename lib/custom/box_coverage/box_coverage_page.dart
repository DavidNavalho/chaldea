import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'box_coverage_models.dart';
import 'box_coverage_service.dart';
import 'widgets/coverage_table.dart';

class BoxCoveragePage extends StatefulWidget {
  const BoxCoveragePage({super.key});

  @override
  State<BoxCoveragePage> createState() => _BoxCoveragePageState();
}

class _BoxCoveragePageState extends State<BoxCoveragePage> {
  static const _request = BoxCoverageRequest.defaults();

  final BoxCoverageService _service = const ChaldeaBoxCoverageService();
  late BoxCoveragePageModel _model;

  @override
  void initState() {
    super.initState();
    _model = _service.build(_request);
  }

  void _refresh() {
    setState(() {
      _model = _service.build(_request);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Box Coverage'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Rebuild coverage')],
      ),
      body: _model.ownedServantCount == 0
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No owned servants were found in the current Chaldea data.', textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryCard(model: _model),
                const SizedBox(height: 16),
                CoverageTable(table: _model.targetCoverageTable),
                const SizedBox(height: 16),
                CoverageTable(table: _model.classCapabilityTable),
                const SizedBox(height: 16),
                CoverageTable(table: _model.multiplierTable),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final BoxCoveragePageModel model;

  const _SummaryCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd HH:mm').format(model.generatedAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            Text('Owned servants: ${model.ownedServantCount}', style: Theme.of(context).textTheme.titleSmall),
            Text('Generated: $dateText', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
