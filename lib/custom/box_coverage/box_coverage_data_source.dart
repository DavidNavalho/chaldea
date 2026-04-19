import 'dart:collection';

import 'package:chaldea/models/models.dart';

import 'box_coverage_models.dart';

enum BoxCoverageSourceFunctionKind { directNpGain, other }

class BoxCoverageSourceFunction {
  final BoxCoverageSourceFunctionKind kind;
  final List<int?> levelValues;

  const BoxCoverageSourceFunction({required this.kind, required this.levelValues});
}

class BoxCoverageSourceSkill {
  final int slot;
  final List<BoxCoverageSourceFunction> functions;

  const BoxCoverageSourceSkill({required this.slot, required this.functions});
}

class BoxCoverageSourceNp {
  final BoxCoverageNpTarget target;
  final CardType card;

  const BoxCoverageSourceNp({required this.target, required this.card});
}

class BoxCoverageSourceServant {
  final int collectionNo;
  final int servantId;
  final String name;
  final int classId;
  final int rarity;
  final int npLevel;
  final int grailCount;
  final String? faceIcon;
  final String? classIcon;
  final List<BoxCoverageSourceNp> offensiveNps;
  final Map<int, List<BoxCoverageSourceSkill>> activeSkillsBySlot;

  const BoxCoverageSourceServant({
    required this.collectionNo,
    required this.servantId,
    required this.name,
    required this.classId,
    required this.rarity,
    required this.npLevel,
    required this.grailCount,
    required this.faceIcon,
    required this.classIcon,
    required this.offensiveNps,
    required this.activeSkillsBySlot,
  });
}

abstract class BoxCoverageDataSource {
  List<BoxCoverageSourceServant> loadOwnedServants();

  int classRelation(int attackerClassId, int defenderClassId);
}

class ChaldeaBoxCoverageDataSource implements BoxCoverageDataSource {
  const ChaldeaBoxCoverageDataSource();

  @override
  List<BoxCoverageSourceServant> loadOwnedServants() {
    final servants = <BoxCoverageSourceServant>[];
    for (final entry in db.curUser.servants.entries) {
      final collectionNo = entry.key;
      final status = entry.value.cur;
      if (status.favorite != true) continue;
      final servant = db.gameData.servantsNoDup[collectionNo];
      if (servant == null) continue;
      servants.add(
        BoxCoverageSourceServant(
          collectionNo: servant.collectionNo,
          servantId: servant.id,
          name: servant.lName.l,
          classId: servant.classId,
          rarity: servant.rarity,
          npLevel: status.npLv,
          grailCount: status.grail,
          faceIcon: servant.icon,
          classIcon: SvtClassX.clsIcon(servant.classId, servant.rarity),
          offensiveNps: _buildOffensiveNps(servant),
          activeSkillsBySlot: _buildActiveSkillsBySlot(servant),
        ),
      );
    }
    return servants;
  }

  @override
  int classRelation(int attackerClassId, int defenderClassId) {
    return db.gameData.constData.getClassIdRelation(attackerClassId, defenderClassId);
  }

  List<BoxCoverageSourceNp> _buildOffensiveNps(Servant servant) {
    final groupedNps = servant.groupedNoblePhantasms.values.expand((group) => group);
    final tds = groupedNps.isNotEmpty ? groupedNps : servant.noblePhantasms;
    final offensiveNps = <BoxCoverageSourceNp>[];
    for (final td in tds) {
      final target = _normalizeNpTarget(td.damageType);
      if (!const {BoxCoverageNpTarget.single, BoxCoverageNpTarget.aoe}.contains(target)) continue;
      final card = _normalizeNpCard(td.svt.card);
      if (!const {CardType.arts, CardType.buster, CardType.quick}.contains(card)) continue;
      offensiveNps.add(BoxCoverageSourceNp(target: target, card: card));
    }
    return offensiveNps;
  }

  Map<int, List<BoxCoverageSourceSkill>> _buildActiveSkillsBySlot(Servant servant) {
    return {for (final slot in kActiveSkillNums) slot: _collectSkillVariantsForSlot(servant, slot)};
  }

  List<BoxCoverageSourceSkill> _collectSkillVariantsForSlot(Servant servant, int slot) {
    final variants = <BoxCoverageSourceSkill>[];
    final seenSkillIds = <int>{};
    final queue = Queue<int>();
    final baseSkills = servant.groupedActiveSkills[slot] ?? const <NiceSkill>[];

    for (final skill in baseSkills) {
      if (seenSkillIds.add(skill.id)) {
        variants.add(_toSourceSkill(skill, slot));
        queue.add(skill.id);
      }
    }

    final rankUpMap = servant.script?.skillRankUp ?? const <int, List<int>>{};
    while (queue.isNotEmpty) {
      final skillId = queue.removeFirst();
      for (final upgradedId in rankUpMap[skillId] ?? const <int>[]) {
        if (!seenSkillIds.add(upgradedId)) continue;
        final upgraded = db.gameData.baseSkills[upgradedId]?.toNice();
        if (upgraded == null) continue;
        variants.add(_toSourceSkill(upgraded, slot));
        queue.add(upgradedId);
      }
    }
    return variants;
  }

  BoxCoverageSourceSkill _toSourceSkill(NiceSkill skill, int slot) {
    return BoxCoverageSourceSkill(
      slot: slot,
      functions: skill.functions.map(_toSourceFunction).toList(growable: false),
    );
  }

  BoxCoverageSourceFunction _toSourceFunction(NiceFunction function) {
    return BoxCoverageSourceFunction(
      kind: function.funcType == FuncType.gainNp
          ? BoxCoverageSourceFunctionKind.directNpGain
          : BoxCoverageSourceFunctionKind.other,
      levelValues: [for (final values in function.svals) values.Value],
    );
  }

  static BoxCoverageNpTarget _normalizeNpTarget(TdEffectFlag damageType) {
    return switch (damageType) {
      TdEffectFlag.attackEnemyOne => BoxCoverageNpTarget.single,
      TdEffectFlag.attackEnemyAll => BoxCoverageNpTarget.aoe,
      TdEffectFlag.support => BoxCoverageNpTarget.support,
    };
  }

  static CardType _normalizeNpCard(int rawCard) {
    if (CardType.isArts(rawCard)) return CardType.arts;
    if (CardType.isBuster(rawCard)) return CardType.buster;
    if (CardType.isQuick(rawCard)) return CardType.quick;
    return CardType.none;
  }
}
