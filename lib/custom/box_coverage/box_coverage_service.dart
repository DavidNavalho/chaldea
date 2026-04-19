import 'dart:math' as math;

import 'package:chaldea/models/gamedata/common.dart';

import 'box_coverage_data_source.dart';
import 'box_coverage_models.dart';
import 'box_coverage_np_gain.dart';

typedef BoxCoverageClassRelation = int Function(int attackerClassId, int defenderClassId);

abstract class BoxCoverageService {
  BoxCoveragePageModel build(BoxCoverageRequest request);
}

class ChaldeaBoxCoverageService implements BoxCoverageService {
  final BoxCoverageDataSource dataSource;
  final BoxCoverageNormalizer normalizer;
  final BoxCoverageAggregator aggregator;

  const ChaldeaBoxCoverageService({
    this.dataSource = const ChaldeaBoxCoverageDataSource(),
    this.normalizer = const BoxCoverageNormalizer(),
    this.aggregator = const BoxCoverageAggregator(),
  });

  @override
  BoxCoveragePageModel build(BoxCoverageRequest request) {
    final sourceServants = dataSource.loadOwnedServants();
    final servants = normalizer.normalizeServants(sourceServants);
    return aggregator.buildFromSnapshots(servants, request, classRelationRaw: dataSource.classRelation);
  }
}

class BoxCoverageNormalizer {
  const BoxCoverageNormalizer();

  List<BoxCoverageServantSnapshot> normalizeServants(List<BoxCoverageSourceServant> servants) {
    final snapshots = <BoxCoverageServantSnapshot>[];
    for (final servant in servants) {
      final snapshot = normalizeServant(servant);
      if (snapshot != null) {
        snapshots.add(snapshot);
      }
    }
    return snapshots;
  }

  BoxCoverageServantSnapshot? normalizeServant(BoxCoverageSourceServant servant) {
    final np = chooseOffensiveNp(servant);
    if (np == null) return null;
    return BoxCoverageServantSnapshot(
      collectionNo: servant.collectionNo,
      servantId: servant.servantId,
      name: servant.name,
      classId: servant.classId,
      rarity: servant.rarity,
      owned: true,
      npLevel: servant.npLevel,
      grailCount: servant.grailCount,
      totalNpGain: BoxCoverageNpGainCalculator.computeTotalNpGain(servant),
      npTarget: np.target,
      npCard: np.card,
      faceIcon: servant.faceIcon,
      classIcon: servant.classIcon,
    );
  }

  BoxCoverageSourceNp? chooseOffensiveNp(BoxCoverageSourceServant servant) {
    if (servant.offensiveNps.isEmpty) return null;
    return servant.offensiveNps.first;
  }
}

class BoxCoverageAggregator {
  const BoxCoverageAggregator();

  static final List<_ClassConfig> _rowClasses = [
    _ClassConfig(SvtClass.saber, 'Saber'),
    _ClassConfig(SvtClass.archer, 'Archer'),
    _ClassConfig(SvtClass.lancer, 'Lancer'),
    _ClassConfig(SvtClass.rider, 'Rider'),
    _ClassConfig(SvtClass.caster, 'Caster'),
    _ClassConfig(SvtClass.assassin, 'Assassin'),
    _ClassConfig(SvtClass.ruler, 'Ruler'),
    _ClassConfig(SvtClass.avenger, 'Avenger'),
    _ClassConfig(SvtClass.moonCancer, 'Moon Cancer'),
    _ClassConfig(SvtClass.berserker, 'Berserker'),
    _ClassConfig(SvtClass.foreigner, 'Foreigner'),
    _ClassConfig(SvtClass.alterego, 'Alter Ego'),
    _ClassConfig(SvtClass.pretender, 'Pretender'),
    _ClassConfig(SvtClass.beastAny, 'Beast'),
  ];

  static const List<CardType> _cardOrder = [CardType.buster, CardType.arts, CardType.quick];

  BoxCoveragePageModel buildFromSnapshots(
    List<BoxCoverageServantSnapshot> servants,
    BoxCoverageRequest request, {
    required BoxCoverageClassRelation classRelationRaw,
  }) {
    return BoxCoveragePageModel(
      generatedAt: DateTime.now(),
      ownedServantCount: servants.length,
      servants: List.unmodifiable(servants),
      targetCoverageTable: _buildTargetCoverageTable(servants, request, classRelationRaw),
      classCapabilityTable: _buildClassCapabilityTable(servants, request),
      multiplierTable: _buildMultiplierTable(servants, request, classRelationRaw),
    );
  }

  BoxCoverageTableModel _buildTargetCoverageTable(
    List<BoxCoverageServantSnapshot> servants,
    BoxCoverageRequest request,
    BoxCoverageClassRelation classRelationRaw,
  ) {
    final columnGroups = _buildBasicColumnGroups(request);
    final columns = columnGroups.expand((group) => group.columns).toList(growable: false);
    final rows = _rowClasses
        .map((rowClass) {
          final cells = columns
              .map((column) {
                final matching = servants.where((servant) {
                  if (servant.npTarget != column.npTarget) return false;
                  if (servant.rarity != column.rarity) return false;
                  return classRelationRaw(servant.classId, rowClass.classId) > 1000;
                }).toList();
                return _buildCountCell(
                  id: '${rowClass.label}:${column.id}',
                  servants: matching,
                  comparator: _compareCoverageContributors,
                );
              })
              .toList(growable: false);
          return BoxCoverageRowModel(
            id: rowClass.label.toLowerCase().replaceAll(' ', '_'),
            label: rowClass.label,
            classId: rowClass.classId,
            classIcon: rowClass.classIcon,
            cells: cells,
          );
        })
        .toList(growable: false);

    return BoxCoverageTableModel(
      kind: BoxCoverageTableKind.targetCoverage,
      title: 'Target Coverage Overview',
      columnGroups: columnGroups,
      rows: rows,
    );
  }

  BoxCoverageTableModel _buildClassCapabilityTable(
    List<BoxCoverageServantSnapshot> servants,
    BoxCoverageRequest request,
  ) {
    final columnGroups = _buildCapabilityColumnGroups(request);
    final columns = columnGroups.expand((group) => group.columns).toList(growable: false);
    final rows = _rowClasses
        .map((rowClass) {
          final cells = columns
              .map((column) {
                final matching = servants.where((servant) {
                  return servant.classId == rowClass.classId &&
                      servant.npTarget == column.npTarget &&
                      servant.npCard == column.npCard &&
                      servant.rarity == column.rarity;
                }).toList();
                return _buildCountCell(
                  id: '${rowClass.label}:${column.id}',
                  servants: matching,
                  comparator: _compareCoverageContributors,
                );
              })
              .toList(growable: false);
          return BoxCoverageRowModel(
            id: rowClass.label.toLowerCase().replaceAll(' ', '_'),
            label: rowClass.label,
            classId: rowClass.classId,
            classIcon: rowClass.classIcon,
            cells: cells,
          );
        })
        .toList(growable: false);

    return BoxCoverageTableModel(
      kind: BoxCoverageTableKind.classCapability,
      title: 'Owned Capability Checklist',
      columnGroups: columnGroups,
      rows: rows,
    );
  }

  BoxCoverageTableModel _buildMultiplierTable(
    List<BoxCoverageServantSnapshot> servants,
    BoxCoverageRequest request,
    BoxCoverageClassRelation classRelationRaw,
  ) {
    final columnGroups = _buildBasicColumnGroups(request);
    final columns = columnGroups.expand((group) => group.columns).toList(growable: false);
    final rows = _rowClasses
        .map((rowClass) {
          final cells = columns
              .map((column) {
                final candidates = servants
                    .where((servant) => servant.npTarget == column.npTarget && servant.rarity == column.rarity)
                    .map(
                      (servant) => _MultiplierCandidate(
                        servant: servant,
                        multiplierRaw: classRelationRaw(servant.classId, rowClass.classId),
                      ),
                    )
                    .toList(growable: false);
                return _buildMultiplierCell(id: '${rowClass.label}:${column.id}', candidates: candidates);
              })
              .toList(growable: false);
          return BoxCoverageRowModel(
            id: rowClass.label.toLowerCase().replaceAll(' ', '_'),
            label: rowClass.label,
            classId: rowClass.classId,
            classIcon: rowClass.classIcon,
            cells: cells,
          );
        })
        .toList(growable: false);

    return BoxCoverageTableModel(
      kind: BoxCoverageTableKind.multiplier,
      title: 'Highest Multiplier by Target Class',
      columnGroups: columnGroups,
      rows: rows,
    );
  }

  BoxCoverageCellModel _buildCountCell({
    required String id,
    required List<BoxCoverageServantSnapshot> servants,
    required int Function(BoxCoverageContributor a, BoxCoverageContributor b) comparator,
  }) {
    if (servants.isEmpty) return BoxCoverageCellModel.empty(id);
    final contributors = servants.map(BoxCoverageContributor.fromSnapshot).toList(growable: false)..sort(comparator);
    return BoxCoverageCellModel(
      id: id,
      count: contributors.length,
      maxNpGain: contributors.map((contributor) => contributor.totalNpGain).fold(0, math.max),
      bestMultiplier: null,
      contributors: List.unmodifiable(contributors),
    );
  }

  BoxCoverageCellModel _buildMultiplierCell({required String id, required List<_MultiplierCandidate> candidates}) {
    if (candidates.isEmpty) return BoxCoverageCellModel.empty(id);
    final bestRaw = candidates.map((candidate) => candidate.multiplierRaw).fold(0, math.max);
    final contributors =
        candidates
            .where((candidate) => candidate.multiplierRaw == bestRaw)
            .map(
              (candidate) => BoxCoverageContributor.fromSnapshot(candidate.servant, multiplier: candidate.multiplier),
            )
            .toList(growable: false)
          ..sort(_compareMultiplierContributors);
    return BoxCoverageCellModel(
      id: id,
      count: contributors.length,
      maxNpGain: contributors.map((contributor) => contributor.totalNpGain).fold(0, math.max),
      bestMultiplier: bestRaw / 1000,
      contributors: List.unmodifiable(contributors),
    );
  }

  List<BoxCoverageColumnGroup> _buildBasicColumnGroups(BoxCoverageRequest request) {
    return request.allowedTargets
        .map((target) {
          final columns = request.allowedRarities
              .map(
                (rarity) => BoxCoverageColumn(
                  id: '${target.name}_$rarity',
                  label: '$rarity-star',
                  rarity: rarity,
                  npTarget: target,
                  npCard: null,
                ),
              )
              .toList(growable: false);
          return BoxCoverageColumnGroup(label: target.label, columns: columns);
        })
        .toList(growable: false);
  }

  List<BoxCoverageColumnGroup> _buildCapabilityColumnGroups(BoxCoverageRequest request) {
    return request.allowedTargets
        .map((target) {
          final columns = <BoxCoverageColumn>[];
          for (final card in _cardOrder) {
            for (final rarity in request.allowedRarities) {
              columns.add(
                BoxCoverageColumn(
                  id: '${target.name}_${card.name}_$rarity',
                  label: '${_cardLabel(card)} $rarity-star',
                  rarity: rarity,
                  npTarget: target,
                  npCard: card,
                ),
              );
            }
          }
          return BoxCoverageColumnGroup(label: target.label, columns: columns);
        })
        .toList(growable: false);
  }

  static int _compareCoverageContributors(BoxCoverageContributor a, BoxCoverageContributor b) {
    final npGain = b.totalNpGain.compareTo(a.totalNpGain);
    if (npGain != 0) return npGain;
    final rarity = b.rarity.compareTo(a.rarity);
    if (rarity != 0) return rarity;
    final npLevel = b.npLevel.compareTo(a.npLevel);
    if (npLevel != 0) return npLevel;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _compareMultiplierContributors(BoxCoverageContributor a, BoxCoverageContributor b) {
    final multiplier = (b.multiplier ?? 0).compareTo(a.multiplier ?? 0);
    if (multiplier != 0) return multiplier;
    return _compareCoverageContributors(a, b);
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

class _ClassConfig {
  final int classId;
  final String label;

  _ClassConfig(SvtClass cls, this.label) : classId = cls.value;

  String get classIcon => SvtClassX.clsIcon(classId, 5);
}

class _MultiplierCandidate {
  final BoxCoverageServantSnapshot servant;
  final int multiplierRaw;

  const _MultiplierCandidate({required this.servant, required this.multiplierRaw});

  double get multiplier => multiplierRaw / 1000;
}
