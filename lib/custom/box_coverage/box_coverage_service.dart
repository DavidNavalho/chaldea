import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:chaldea/models/models.dart';
import 'package:chaldea/utils/utils.dart';

import 'box_coverage_models.dart';

abstract class BoxCoverageService {
  BoxCoveragePageModel build(BoxCoverageRequest request);
}

class ChaldeaBoxCoverageService implements BoxCoverageService {
  final BoxCoverageNormalizer normalizer;
  final BoxCoverageAggregator aggregator;

  const ChaldeaBoxCoverageService({BoxCoverageNormalizer? normalizer, BoxCoverageAggregator? aggregator})
    : normalizer = normalizer ?? const BoxCoverageNormalizer(),
      aggregator = aggregator ?? const BoxCoverageAggregator();

  @override
  BoxCoveragePageModel build(BoxCoverageRequest request) {
    final servants = normalizer.normalizeOwnedServants();
    return aggregator.buildFromSnapshots(servants, request);
  }
}

class BoxCoverageNormalizer {
  const BoxCoverageNormalizer();

  List<BoxCoverageServantSnapshot> normalizeOwnedServants() {
    final servants = <BoxCoverageServantSnapshot>[];
    for (final entry in db.curUser.servants.entries) {
      final collectionNo = entry.key;
      final status = entry.value.cur;
      if (status.favorite != true) continue;
      final servant = db.gameData.servantsNoDup[collectionNo];
      if (servant == null) continue;
      final snapshot = normalizeServant(servant);
      if (snapshot != null) {
        servants.add(snapshot);
      }
    }
    return servants;
  }

  BoxCoverageServantSnapshot? normalizeServant(Servant servant) {
    final status = db.curUser.svtStatusOf(servant.collectionNo).cur;
    if (status.favorite != true) return null;
    final td = chooseOffensiveNp(servant);
    if (td == null) return null;
    final npTarget = normalizeNpTarget(td.damageType);
    if (!const {BoxCoverageNpTarget.single, BoxCoverageNpTarget.aoe}.contains(npTarget)) {
      return null;
    }
    final npCard = normalizeNpCard(td.svt.card);
    if (!const {CardType.arts, CardType.buster, CardType.quick}.contains(npCard)) {
      return null;
    }
    return BoxCoverageServantSnapshot(
      collectionNo: servant.collectionNo,
      servantId: servant.id,
      name: servant.lName.l,
      classId: servant.classId,
      rarity: servant.rarity,
      owned: true,
      npLevel: status.npLv,
      grailCount: status.grail,
      totalNpGain: computeTotalNpGain(servant),
      npTarget: npTarget,
      npCard: npCard,
      faceIcon: servant.icon,
      classIcon: SvtClassX.clsIcon(servant.classId, servant.rarity),
    );
  }

  NiceTd? chooseOffensiveNp(Servant servant) {
    final groupedTds = servant.groupedNoblePhantasms.values.expand((group) => group);
    final tds = groupedTds.isNotEmpty ? groupedTds : servant.noblePhantasms;
    return tds.firstWhereOrNull((td) {
      final target = normalizeNpTarget(td.damageType);
      return target == BoxCoverageNpTarget.single || target == BoxCoverageNpTarget.aoe;
    });
  }

  static BoxCoverageNpTarget normalizeNpTarget(TdEffectFlag damageType) {
    return switch (damageType) {
      TdEffectFlag.attackEnemyOne => BoxCoverageNpTarget.single,
      TdEffectFlag.attackEnemyAll => BoxCoverageNpTarget.aoe,
      TdEffectFlag.support => BoxCoverageNpTarget.support,
    };
  }

  static CardType normalizeNpCard(int rawCard) {
    if (CardType.isArts(rawCard)) return CardType.arts;
    if (CardType.isBuster(rawCard)) return CardType.buster;
    if (CardType.isQuick(rawCard)) return CardType.quick;
    return CardType.none;
  }

  @visibleForTesting
  static int computeTotalNpGain(Servant servant) {
    var totalRaw = 0;
    for (final slot in kActiveSkillNums) {
      totalRaw += maxDirectNpGainForSkillVariants(_collectSkillVariantsForSlot(servant, slot));
    }
    return scaleNpGainRaw(totalRaw);
  }

  static List<NiceSkill> _collectSkillVariantsForSlot(Servant servant, int slot) {
    final variants = <NiceSkill>[];
    final seenSkillIds = <int>{};
    final queue = Queue<int>();
    final baseSkills = servant.groupedActiveSkills[slot] ?? const <NiceSkill>[];

    for (final skill in baseSkills) {
      if (seenSkillIds.add(skill.id)) {
        variants.add(skill);
        queue.add(skill.id);
      }
    }

    final rankUpMap = servant.script?.skillRankUp ?? const <int, List<int>>{};
    while (queue.isNotEmpty) {
      final skillId = queue.removeFirst();
      for (final upgradedId in rankUpMap[skillId] ?? const <int>[]) {
        if (!seenSkillIds.add(upgradedId)) continue;
        final upgraded = db.gameData.baseSkills[upgradedId]?.toNice();
        if (upgraded != null) {
          variants.add(upgraded);
          queue.add(upgradedId);
        }
      }
    }
    return variants;
  }

  @visibleForTesting
  static int maxDirectNpGainForSkillVariants(Iterable<NiceSkill> variants) {
    var maxRaw = 0;
    for (final skill in variants) {
      maxRaw = math.max(maxRaw, maxDirectNpGainForSkill(skill));
    }
    return maxRaw;
  }

  @visibleForTesting
  static int maxDirectNpGainForSkill(NiceSkill skill) {
    var maxRaw = 0;
    for (final function in skill.functions) {
      if (function.funcType != FuncType.gainNp) continue;
      maxRaw = math.max(maxRaw, directGainNpValueAtLevel10(function));
    }
    return maxRaw;
  }

  @visibleForTesting
  static int directGainNpValueAtLevel10(NiceFunction function) {
    if (function.svals.isEmpty) return 0;
    final valueAtLevel10 = function.svals.length >= 10 ? function.svals[9].Value : function.svals.last.Value;
    return valueAtLevel10 ?? 0;
  }

  @visibleForTesting
  static int scaleNpGainRaw(int rawValue) {
    if (rawValue <= 0) return 0;
    return (rawValue / 100).round();
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

  BoxCoveragePageModel buildFromSnapshots(List<BoxCoverageServantSnapshot> servants, BoxCoverageRequest request) {
    return BoxCoveragePageModel(
      generatedAt: DateTime.now(),
      ownedServantCount: servants.length,
      servants: List.unmodifiable(servants),
      targetCoverageTable: _buildTargetCoverageTable(servants, request),
      classCapabilityTable: _buildClassCapabilityTable(servants, request),
      multiplierTable: _buildMultiplierTable(servants, request),
    );
  }

  BoxCoverageTableModel _buildTargetCoverageTable(
    List<BoxCoverageServantSnapshot> servants,
    BoxCoverageRequest request,
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
                  return _classRelationRaw(servant.classId, rowClass.classId) > 1000;
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

  BoxCoverageTableModel _buildMultiplierTable(List<BoxCoverageServantSnapshot> servants, BoxCoverageRequest request) {
    final columnGroups = _buildBasicColumnGroups(request);
    final columns = columnGroups.expand((group) => group.columns).toList(growable: false);
    final rows = _rowClasses
        .map((rowClass) {
          final cells = columns
              .map((column) {
                final candidates = servants
                    .where((servant) {
                      return servant.npTarget == column.npTarget && servant.rarity == column.rarity;
                    })
                    .map(
                      (servant) => _MultiplierCandidate(
                        servant: servant,
                        multiplierRaw: _classRelationRaw(servant.classId, rowClass.classId),
                      ),
                    )
                    .toList();
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
    final contributors = servants.map(BoxCoverageContributor.fromSnapshot).toList()..sort(comparator);
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
            .toList()
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
              .map((rarity) {
                return BoxCoverageColumn(
                  id: '${target.name}_$rarity',
                  label: '$rarity-star',
                  rarity: rarity,
                  npTarget: target,
                  npCard: null,
                );
              })
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

  static int _classRelationRaw(int attackerClassId, int defenderClassId) {
    return db.gameData.constData.getClassIdRelation(attackerClassId, defenderClassId);
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
