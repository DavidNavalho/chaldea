import 'package:flutter_test/flutter_test.dart';

import 'package:chaldea/custom/box_coverage/box_coverage_models.dart';
import 'package:chaldea/custom/box_coverage/box_coverage_service.dart';
import 'package:chaldea/models/gamedata/common.dart';
import 'package:chaldea/models/gamedata/func.dart';
import 'package:chaldea/models/gamedata/skill.dart';
import 'package:chaldea/models/gamedata/vals.dart';

import '../../test_init.dart';

void main() {
  setUpAll(() async {
    await initiateForTest();
  });

  group('BoxCoverageNormalizer', () {
    test('maxDirectNpGainForSkillVariants keeps the largest direct gainNp value at level 10', () {
      final baseSkill = NiceSkill(
        id: 1001,
        type: SkillType.active,
        skillSvts: [SkillSvt(svtId: 1, num: 1)],
        functions: [_gainNpFunction(2000), _gainNpFunction(2500)],
      );
      final upgradedSkill = NiceSkill(
        id: 1002,
        type: SkillType.active,
        skillSvts: [SkillSvt(svtId: 1, num: 1)],
        functions: [
          _gainNpFunction(3000),
          _gainNpFunction(9000, funcType: FuncType.gainNpFromTargets),
        ],
      );

      expect(BoxCoverageNormalizer.maxDirectNpGainForSkillVariants([baseSkill, upgradedSkill]), 3000);
      expect(BoxCoverageNormalizer.scaleNpGainRaw(3000), 30);
    });
  });

  group('BoxCoverageAggregator', () {
    test('builds target coverage, capability, and multiplier tables from normalized snapshots', () {
      final aggregator = const BoxCoverageAggregator();
      final model = aggregator.buildFromSnapshots([
        _snapshot(
          collectionNo: 1,
          servantId: 101,
          name: 'Euryale',
          classId: SvtClass.archer.value,
          rarity: 5,
          npLevel: 2,
          totalNpGain: 20,
          npTarget: BoxCoverageNpTarget.aoe,
          npCard: CardType.buster,
        ),
        _snapshot(
          collectionNo: 2,
          servantId: 102,
          name: 'Gilgamesh',
          classId: SvtClass.archer.value,
          rarity: 5,
          npLevel: 1,
          totalNpGain: 30,
          npTarget: BoxCoverageNpTarget.aoe,
          npCard: CardType.arts,
        ),
        _snapshot(
          collectionNo: 3,
          servantId: 103,
          name: 'Bedivere',
          classId: SvtClass.saber.value,
          rarity: 4,
          npLevel: 5,
          totalNpGain: 10,
          npTarget: BoxCoverageNpTarget.single,
          npCard: CardType.arts,
        ),
      ], const BoxCoverageRequest.defaults());

      final targetCoverageCell = _findCell(
        table: model.targetCoverageTable,
        rowClassId: SvtClass.saber.value,
        npTarget: BoxCoverageNpTarget.aoe,
        rarity: 5,
      );
      expect(targetCoverageCell.count, 2);
      expect(targetCoverageCell.maxNpGain, 30);
      expect(targetCoverageCell.contributors.map((contributor) => contributor.name), ['Gilgamesh', 'Euryale']);

      final capabilityCell = _findCell(
        table: model.classCapabilityTable,
        rowClassId: SvtClass.archer.value,
        npTarget: BoxCoverageNpTarget.aoe,
        rarity: 5,
        npCard: CardType.buster,
      );
      expect(capabilityCell.count, 1);
      expect(capabilityCell.maxNpGain, 20);
      expect(capabilityCell.contributors.single.name, 'Euryale');

      final multiplierCell = _findCell(
        table: model.multiplierTable,
        rowClassId: SvtClass.saber.value,
        npTarget: BoxCoverageNpTarget.aoe,
        rarity: 5,
      );
      expect(multiplierCell.bestMultiplier, 2.0);
      expect(multiplierCell.count, 2);
      expect(multiplierCell.maxNpGain, 30);
      expect(multiplierCell.contributors.map((contributor) => contributor.name), ['Gilgamesh', 'Euryale']);
    });
  });
}

NiceFunction _gainNpFunction(int finalValue, {FuncType funcType = FuncType.gainNp}) {
  return NiceFunction(
    funcId: finalValue,
    funcType: funcType,
    funcTargetType: FuncTargetType.self,
    svals: List.generate(
      10,
      (index) => DataVals({'Value': ((finalValue / 10).round()) * (index + 1)}),
      growable: false,
    ),
  );
}

BoxCoverageServantSnapshot _snapshot({
  required int collectionNo,
  required int servantId,
  required String name,
  required int classId,
  required int rarity,
  required int npLevel,
  required int totalNpGain,
  required BoxCoverageNpTarget npTarget,
  required CardType npCard,
}) {
  return BoxCoverageServantSnapshot(
    collectionNo: collectionNo,
    servantId: servantId,
    name: name,
    classId: classId,
    rarity: rarity,
    owned: true,
    npLevel: npLevel,
    grailCount: 0,
    totalNpGain: totalNpGain,
    npTarget: npTarget,
    npCard: npCard,
    faceIcon: null,
    classIcon: null,
  );
}

BoxCoverageCellModel _findCell({
  required BoxCoverageTableModel table,
  required int rowClassId,
  required BoxCoverageNpTarget npTarget,
  required int rarity,
  CardType? npCard,
}) {
  final row = table.rows.firstWhere((row) => row.classId == rowClassId);
  final columnIndex = table.columns.indexWhere(
    (column) => column.npTarget == npTarget && column.rarity == rarity && column.npCard == npCard,
  );
  return row.cells[columnIndex];
}
