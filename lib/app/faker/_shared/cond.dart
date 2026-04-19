part of '../runtime.dart';

class FakerCondCheck {
  final FakerRuntime runtime;
  final MasterDataManager mstData;
  FakerCondCheck(this.runtime) : mstData = runtime.agent.network.mstData;

  bool? isCondOpen2(CondType condType, List<int> targetIds, int targetNum) {
    switch (condType) {
      case CondType.questNotClearAnd:
        if (targetIds.isEmpty) return false;
        for (final questId in targetIds) {
          if (mstData.isQuestClear(questId)) {
            return false;
          }
        }
        return true;
      case CondType.notShopPurchase:
        for (final shopId in targetIds) {
          if ((mstData.userShop[shopId]?.num ?? 0) == 0) return true;
        }
        return false;
      case CondType.purchaseShop:
        int num2 = 0;
        for (final shopId in targetIds) {
          num2 += (mstData.userShop[shopId]?.num ?? 0);
        }
        return targetNum > 0 && num2 == targetNum;
      case CondType.questClear: // {1: [94149606] - 1, 2: [94034014, 94034112] - 2}
        return targetIds.where(mstData.isQuestClear).length >= targetNum;
      case CondType.eventMissionClear: // {1: [11861] - 1}
        return targetIds.where((targetId) => mstData.getMissionProgress(targetId).isClearOrAchieve).length >= targetNum;
      case CondType.eventMissionAchieve: // {1: [80576268] - 1}
        return targetIds
                .where((targetId) => mstData.getMissionProgress(targetId) == MissionProgressType.achieve)
                .length >=
            targetNum;
      case CondType.unknown:
        return null;
      default:
        break;
    }
    assert(targetIds.length <= 1, '$condType-$targetIds-$targetNum');
    return isCondOpen(condType, targetIds.isEmpty ? 0 : targetIds[0], targetNum);
  }

  bool _checkSvtCollection(int svtId, bool Function(UserServantCollectionEntity collection) test) {
    final collection = mstData.userSvtCollection[svtId];
    return collection != null && test(collection);
  }

  bool _testSvt(int svtId, bool Function(UserServantEntity svt) test) {
    return mstData.userSvt.followedBy(mstData.userSvtStorage).any((e) => e.svtId == svtId && test(e));
  }

  bool? isCondOpen(CondType condType, int targetId, int targetNum) {
    switch (condType) {
      case CondType.none:
        return true;
      case CondType.svtGet:
        return _checkSvtCollection(targetId, (e) => e.isOwned);
      case CondType.notSvtHaving:
        return !_testSvt(targetId, (e) => true);
      case CondType.svtHaving:
        return _testSvt(targetId, (e) => true);
      case CondType.questClear:
        return mstData.isQuestClear(targetId);
      case CondType.questNotClear:
        return !mstData.isQuestClear(targetId);
      case CondType.questClearPhase:
        final userQuest = mstData.userQuest[targetId];
        return userQuest != null && userQuest.questPhase >= targetNum;
      case CondType.date:
        return DateTime.now().timestamp > targetNum;
      case CondType.eventMissionAchieve:
        return mstData.userEventMission[targetId]?.missionProgressType == MissionProgressType.achieve.value;
      case CondType.notEquipGet:
        return mstData.userEquip.every((e) => e.equipId != targetId);
      case CondType.equipGet:
        return mstData.userEquip.any((e) => e.equipId == targetId);
      case CondType.svtLimit:
        return _checkSvtCollection(targetId, (e) => e.maxLimitCount >= targetNum);
      case CondType.svtFriendship:
        return _checkSvtCollection(targetId, (e) => e.friendshipRank >= targetNum);
      case CondType.itemGet:
        final userItem = mstData.userItem[targetId];
        return userItem != null && userItem.num >= targetNum;
      case CondType.notItemGet:
        final userItem = mstData.userItem[targetId];
        return userItem == null || userItem.num < targetNum;
      case CondType.notQuestClearPhase:
        return !mstData.isQuestPhaseClear(targetId, targetNum);
      case CondType.forceFalse:
        return false;
      case CondType.unknown:
        return null;
      case CondType.raidAlive:
      case CondType.raidDead:
      case CondType.questGroupClear:
      case CondType.eventTotalPoint:
      case CondType.eventGroupPoint:
      case CondType.notQuestGroupClear:
      case CondType.eventFlag:
      case CondType.purchaseShop:
      case CondType.eventPoint:
      case CondType.eventValueEqual:
      case CondType.raidGroupDead:
      case CondType.eventScriptPlay:
      case CondType.allUsersBoxGachaCount:
      case CondType.multipleDate:
      case CondType.eventGroupTotalWinEachPlayer:
      case CondType.eventFortificationRewardNum:
      case CondType.eventGroupPointRatioInTerm:
      case CondType.routeSelect:
      case CondType.notEventRaceQuestOrNotTargetRankGoal:
      case CondType.eventPointGroupWin:
      case CondType.notEventRaceQuestOrNotAllGroupGoal:
      case CondType.classBoardSquareReleased:
      case CondType.boardGameTokenGroupHaving:
      case CondType.notEventStatus:
      case CondType.questResetAvailable:
      case CondType.eventValue:
      case CondType.eventGroupRankInTerm:
      case CondType.weekdays:
      case CondType.notRouteSelect:
      case CondType.commonValueAbove:
      case CondType.eventNormaPointClear:
      case CondType.eventStatus:
      case CondType.elapsedTimeAfterQuestClear:
      case CondType.notEventMissionAchieve:
      case CondType.eventFlagOff:
      case CondType.notSvtCostumeReleased:
      case CondType.shopGroupLimitNum:
      case CondType.purchaseQpShop:
      case CondType.shopReleased:
      case CondType.commonRelease:
      default:
      //
    }
    return null;
  }

  int? getProgressNum(CondType condType, List<int> targetIds, int targetNum) {
    switch (condType) {
      case CondType.missionConditionDetail:
        final condDetailId = targetIds.firstOrNull ?? 0;
        return mstData.userEventMissionCondDetail[condDetailId]?.progressNum ?? 0;
      case CondType.eventMissionClear:
      case CondType.eventMissionAchieve:
        return targetIds.where((mid) {
          int? progressType;
          final mission = runtime.gameData.timerData.eventMissions[mid];
          if (mission != null && mission.type == .daily) {
            for (final cond in mission.conds) {
              if (cond.missionProgressType == .clear &&
                  cond.condType == .missionConditionDetail &&
                  cond.targetIds.isNotEmpty) {
                final userCondDetail = mstData.userEventMissionCondDetail[cond.targetIds.first];
                if (userCondDetail == null) continue;
                if (runtime.region.getDateTimeByOffset(userCondDetail.updatedAt).day !=
                    runtime.region.getDateTimeByOffset(DateTime.now().timestamp).day) {
                  // not same day
                  progressType = MissionProgressType.none.value;
                } else {
                  progressType = userCondDetail.progressNum >= cond.targetNum
                      ? MissionProgressType.achieve.value
                      : MissionProgressType.none.value;
                }
                break;
              }
            }
          }
          progressType ??= mstData.userEventMission[mid]?.missionProgressType;
          if (progressType == null) return false;
          if (progressType == MissionProgressType.achieve.value) return true;
          if (progressType == MissionProgressType.clear.value && condType == .eventMissionClear) return true;
          return false;
        }).length;
      case CondType.questClear:
        return targetIds.where(mstData.isQuestClear).length;
      default:
        return null;
    }
  }
}
