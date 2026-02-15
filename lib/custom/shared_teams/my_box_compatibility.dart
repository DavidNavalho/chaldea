import 'dart:math';

import 'package:chaldea/models/models.dart';

enum TeamBoxMatchStrictness {
  strict,
  relaxed;

  String get shownName => switch (this) {
    strict => 'Strict',
    relaxed => 'Relaxed',
  };
}

class TeamBoxMatchScore {
  final int hardMismatch;
  final int npDeficit;
  final int skillDeficit;
  final int appendDeficit;
  final int appendDeficitFarmable;
  final int servantLevelDeficit;
  final int ceMlbMissing;
  final int ceLevelDeficit;
  final int mcLevelDeficit;
  final int usedServantSlots;

  const TeamBoxMatchScore({
    required this.hardMismatch,
    required this.npDeficit,
    required this.skillDeficit,
    required this.appendDeficit,
    required this.appendDeficitFarmable,
    required this.servantLevelDeficit,
    required this.ceMlbMissing,
    required this.ceLevelDeficit,
    required this.mcLevelDeficit,
    required this.usedServantSlots,
  });

  int get requirementDeficit =>
      npDeficit +
      skillDeficit +
      appendDeficit +
      appendDeficitFarmable +
      servantLevelDeficit +
      ceMlbMissing +
      ceLevelDeficit +
      mcLevelDeficit;

  int get weightedPenalty =>
      (npDeficit * 60) +
      (ceMlbMissing * 45) +
      (appendDeficit * 8) +
      (skillDeficit * 5) +
      (appendDeficitFarmable * 3) +
      (servantLevelDeficit * 2) +
      (ceLevelDeficit * 2) +
      (mcLevelDeficit * 1);

  bool matches(TeamBoxMatchStrictness strictness) {
    if (hardMismatch > 0) return false;
    if (strictness == TeamBoxMatchStrictness.strict && requirementDeficit > 0) return false;
    return true;
  }
}

TeamBoxMatchScore evaluateMyBoxScore(BattleShareData data) {
  int hardMismatch = 0;
  int npDeficit = 0;
  int skillDeficit = 0;
  int appendDeficit = 0;
  int appendDeficitFarmable = 0;
  int servantLevelDeficit = 0;
  int ceMlbMissing = 0;
  int ceLevelDeficit = 0;
  int mcLevelDeficit = 0;
  int usedServantSlots = 0;

  for (final svtData in data.formation.svts) {
    final svtId = svtData?.svtId ?? 0;
    if (svtData == null || svtId <= 0) continue;
    usedServantSlots += 1;

    final isSupport = svtData.supportType.isSupport;
    if (isSupport) continue;

    final dbSvt = db.gameData.servantsById[svtId];
    final svtCollectionNo = dbSvt?.collectionNo;
    final isOwned = svtCollectionNo != null && db.curUser.svtStatusOf(svtCollectionNo).cur.favorite;
    if (!isOwned || dbSvt == null) {
      hardMismatch += 1;
      continue;
    }

    final userStatus = db.curUser.svtStatusOf(svtCollectionNo);
    final userPlan = userStatus.cur;
    npDeficit += max(0, svtData.tdLv - userPlan.npLv);
    for (int i = 0; i < svtData.skillLvs.length && i < userPlan.skills.length; i++) {
      skillDeficit += max(0, svtData.skillLvs[i] - userPlan.skills[i]);
    }
    final appendIsFarmable = userPlan.npLv >= 2 || userStatus.bond >= 6;
    for (int i = 0; i < svtData.appendLvs.length && i < userPlan.appendSkills.length; i++) {
      final diff = max(0, svtData.appendLvs[i] - userPlan.appendSkills[i]);
      if (appendIsFarmable) {
        appendDeficitFarmable += diff;
      } else {
        appendDeficit += diff;
      }
    }
    final userLv = dbSvt.grailedLv(userPlan.grail);
    servantLevelDeficit += max(0, svtData.lv - userLv);

    final ceId = svtData.equip1.id ?? 0;
    if (ceId <= 0) continue;
    final dbCe = db.gameData.craftEssencesById[ceId];
    final ceCollectionNo = dbCe?.collectionNo;
    final ceOwned = ceCollectionNo != null && db.curUser.ceStatusOf(ceCollectionNo).status == CraftStatus.owned;
    if (!ceOwned || dbCe == null) {
      hardMismatch += 1;
      continue;
    }
    final ceStatus = db.curUser.ceStatusOf(ceCollectionNo);
    if (svtData.equip1.limitBreak && ceStatus.limitCount < 4) {
      ceMlbMissing += 1;
    }
    ceLevelDeficit += max(0, svtData.equip1.lv - ceStatus.lv);
  }

  final mcId = data.formation.mysticCode.mysticCodeId ?? 0;
  if (mcId > 0 && data.hasUsedMCSkills()) {
    final userMcLv = db.curUser.mysticCodes[mcId] ?? 0;
    if (userMcLv <= 0) {
      hardMismatch += 1;
    }
    mcLevelDeficit += max(0, data.formation.mysticCode.level - userMcLv);
  }

  return TeamBoxMatchScore(
    hardMismatch: hardMismatch,
    npDeficit: npDeficit,
    skillDeficit: skillDeficit,
    appendDeficit: appendDeficit,
    appendDeficitFarmable: appendDeficitFarmable,
    servantLevelDeficit: servantLevelDeficit,
    ceMlbMissing: ceMlbMissing,
    ceLevelDeficit: ceLevelDeficit,
    mcLevelDeficit: mcLevelDeficit,
    usedServantSlots: usedServantSlots,
  );
}
