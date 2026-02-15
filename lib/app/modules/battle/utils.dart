import 'dart:math';

import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:chaldea/app/api/atlas.dart';
import 'package:chaldea/app/app.dart';
import 'package:chaldea/app/battle/interactions/_delegate.dart';
import 'package:chaldea/app/battle/models/battle.dart';
import 'package:chaldea/generated/l10n.dart';
import 'package:chaldea/models/models.dart';
import 'package:chaldea/utils/utils.dart';
import 'battle_simulation.dart';

void replaySimulation({required BattleShareData detail, int? replayTeamId}) async {
  final questInfo = detail.quest;
  if (questInfo == null) {
    return EasyLoading.showError('invalid quest info');
  }
  EasyLoading.show();
  final questPhase = await AtlasApi.questPhase(
    questInfo.id,
    questInfo.phase,
    hash: questInfo.enemyHash,
    region: Region.jp,
  );
  EasyLoading.dismiss();

  if (questPhase == null) {
    EasyLoading.showError('${S.current.not_found}: quest ${questInfo.toUrl()}');
    return;
  }
  if (detail.actions.isEmpty) {
    EasyLoading.showError('No replay action found');
    return;
  }

  final questCopy = QuestPhase.fromJson(questPhase.toJson());

  final options = BattleOptions();
  options.fromShareData(detail.options);
  final formation = detail.formation;
  for (int index = 0; index < max(6, formation.svts.length); index++) {
    options.formation.svts[index] = await PlayerSvtData.fromStoredData(formation.svts.getOrNull(index));
  }

  options.formation.mysticCodeData.loadStoredData(formation.mysticCode);

  if (options.disableEvent) {
    questCopy.warId = 0;
    questCopy.removeEventQuestIndividuality();
  }
  if (questCopy.isLaplaceNeedAi) {
    // should always turn on
    options.simulateAi = true;
  }

  router.push(
    url: Routes.laplaceBattle,
    child: BattleSimulationPage(
      questPhase: questCopy,
      region: Region.jp,
      options: options,
      replayActions: detail,
      replayTeamId: replayTeamId,
    ),
  );
}

Future<PlayerSvtData> _buildMyBoxSvtDataFromShared(
  SvtSaveData? savedData, {
  required Region region,
}) async {
  if (savedData == null || (savedData.svtId ?? 0) <= 0) {
    return PlayerSvtData.base();
  }
  if (savedData.supportType.isSupport) {
    // Keep support slots as published team data.
    return PlayerSvtData.fromStoredData(savedData);
  }

  final dbSvt = db.gameData.servantsById[savedData.svtId];
  if (dbSvt == null) {
    return PlayerSvtData.fromStoredData(savedData);
  }

  final status = db.curUser.svtStatusOf(dbSvt.collectionNo);
  if (!status.cur.favorite) {
    return PlayerSvtData.fromStoredData(savedData);
  }

  final player = PlayerSvtData.svt(dbSvt);
  player.onSelectServant(dbSvt, source: PreferPlayerSvtDataSource.current, region: region);
  player.supportType = SupportSvtType.none;

  final ceId = savedData.equip1.id;
  if ((ceId ?? 0) > 0) {
    final ce = db.gameData.craftEssencesById[ceId] ?? await AtlasApi.ce(ceId!);
    if (ce != null && db.curUser.ceStatusOf(ce.collectionNo).status == CraftStatus.owned) {
      player.onSelectCE(ce, SvtEquipTarget.normal);
    }
  }

  return player;
}

Future<BattleOptions> _buildMyBoxOptionsFromShared({
  required BattleShareData detail,
  required Region region,
}) async {
  final options = BattleOptions();
  options.fromShareData(detail.options);
  final formation = detail.formation;
  for (int index = 0; index < max(6, formation.svts.length); index++) {
    final slot = formation.svts.getOrNull(index);
    options.formation.svts[index] = await _buildMyBoxSvtDataFromShared(slot, region: region);
  }
  options.formation.mysticCodeData.loadStoredData(formation.mysticCode);
  final mcId = options.formation.mysticCodeData.mysticCode?.id;
  if ((mcId ?? 0) > 0) {
    final userLv = db.curUser.mysticCodes[mcId];
    if ((userLv ?? 0) > 0) {
      options.formation.mysticCodeData.level = userLv!;
    }
  }
  return options;
}

Future<void> _replayActionOnBattleData(BattleData data, BattleRecordData action) async {
  if (action.type == BattleRecordDataType.skill) {
    if (action.skill == null) return;
    if (action.svt == null) {
      await data.activateMysticCodeSkill(action.skill!);
    } else {
      await data.activateSvtSkill(action.svt!, action.skill!);
    }
    return;
  }

  if (action.type != BattleRecordDataType.attack || action.attacks == null) return;

  final List<CombatAction> actions = [];
  for (final attackRecord in action.attacks!) {
    final svt = data.onFieldAllyServants.getOrNull(attackRecord.svt);
    if (svt == null) continue;

    final cardIndex = attackRecord.card;
    CommandCardData? card;
    if (attackRecord.isTD) {
      card = svt.getNPCard();
    } else if (cardIndex != null) {
      final cards = svt.getCards();
      if (cardIndex >= 0 && cardIndex < cards.length) {
        card = cards[cardIndex];
      }
    }
    if (card == null) continue;
    card.critical = attackRecord.critical;
    actions.add(CombatAction(svt, card));
  }

  await data.playerTurn(actions);
}

class MyBoxReplayRunResult {
  final bool win;
  final String? error;

  const MyBoxReplayRunResult({required this.win, this.error});
}

Future<MyBoxReplayRunResult> simulateSharedTeamWithMyBox({
  required BattleShareData detail,
  required QuestPhase questPhase,
  Region region = Region.jp,
}) async {
  if (detail.actions.isEmpty) {
    return const MyBoxReplayRunResult(win: false, error: 'No replay action found');
  }

  try {
    final questCopy = QuestPhase.fromJson(questPhase.toJson());
    final options = await _buildMyBoxOptionsFromShared(detail: detail, region: region);
    if (options.disableEvent) {
      questCopy.warId = 0;
      questCopy.removeEventQuestIndividuality();
    }
    if (questCopy.isLaplaceNeedAi) {
      options.simulateAi = true;
    }

    final runtime = BattleRuntime(
      battleData: BattleData(),
      region: region,
      originalOptions: options.copy(),
      originalQuest: questCopy,
    );
    runtime.originalOptions.validate(isUseGrandBoard: questCopy.isUseGrandBoard);
    final data = runtime.battleData;
    data.options = runtime.originalOptions.copy();
    data.options.manualAllySkillTarget = false;
    await data.init(
      questCopy,
      runtime.originalOptions.formation.svts,
      runtime.originalOptions.formation.mysticCodeData,
    );

    data.delegate = BattleReplayDelegate(detail.delegate ?? BattleReplayDelegateData());
    try {
      for (final action in detail.actions) {
        data.playerTargetIndex = action.options.playerTarget;
        data.enemyTargetIndex = action.options.enemyTarget;
        data.updateTargetedIndex();
        data.options.random = action.options.random;
        data.options.threshold = action.options.threshold;
        data.options.tailoredExecution = action.options.tailoredExecution;
        await _replayActionOnBattleData(data, action);
        if (data.isBattleWin) break;
      }
    } finally {
      data.delegate = null;
    }

    return MyBoxReplayRunResult(win: data.isBattleWin);
  } catch (e) {
    return MyBoxReplayRunResult(win: false, error: '$e');
  }
}

void replaySimulationWithMyBox({required BattleShareData detail, int? replayTeamId}) async {
  final questInfo = detail.quest;
  if (questInfo == null) {
    return EasyLoading.showError('invalid quest info');
  }
  EasyLoading.show();
  final questPhase = await AtlasApi.questPhase(
    questInfo.id,
    questInfo.phase,
    hash: questInfo.enemyHash,
    region: Region.jp,
  );
  EasyLoading.dismiss();

  if (questPhase == null) {
    EasyLoading.showError('${S.current.not_found}: quest ${questInfo.toUrl()}');
    return;
  }
  if (detail.actions.isEmpty) {
    EasyLoading.showError('No replay action found');
    return;
  }

  final questCopy = QuestPhase.fromJson(questPhase.toJson());

  final options = await _buildMyBoxOptionsFromShared(detail: detail, region: Region.jp);

  if (options.disableEvent) {
    questCopy.warId = 0;
    questCopy.removeEventQuestIndividuality();
  }
  if (questCopy.isLaplaceNeedAi) {
    options.simulateAi = true;
  }

  router.push(
    url: Routes.laplaceBattle,
    child: BattleSimulationPage(
      questPhase: questCopy,
      region: Region.jp,
      options: options,
      replayActions: detail,
      replayTeamId: replayTeamId,
    ),
  );
}
