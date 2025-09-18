import 'dart:async';

import 'package:chaldea/app/battle/interactions/_delegate.dart';
import 'package:chaldea/app/battle/models/battle.dart';
import 'package:chaldea/models/models.dart';
import 'package:chaldea/utils/extension.dart';
import 'package:tuple/tuple.dart';
import 'package:chaldea/app/modules/battle/simulation/skill_classifier.dart';

/// Auto 3T solver that searches for a 3-turn clear by enumerating
/// all permutations of usable skills per turn and ending each turn
/// with one or more NPs (attacker NP goes last if used).
///
/// Assumptions (v1):
/// - Attacker is the first on-field ally (index 0).
/// - No Order Change / swaps.
/// - Each turn ends by using one or more NPs; if wave not cleared, prune.
/// - Ally-targeted skills target the attacker; enemy-targeted skills target the first alive enemy.
/// - Random target selection picks attacker (ally) or first enemy (enemy-side, if applicable).
/// - Exclude the attacker's own skills (configurable via [excludeAttackerSkills]).
/// - MC skills are included but Order Change is forbidden.
class AutoThreeTurnSolver {
  final QuestPhase quest;
  final Region? region;
  final BattleOptions baseOptions;

  /// If true, exclude the attacker's (index 0) own active skills.
  final bool excludeAttackerSkills;

  AutoThreeTurnSolver({
    required this.quest,
    required this.region,
    required this.baseOptions,
    this.excludeAttackerSkills = true,
    this.timeout = const Duration(seconds: 60),
    this.plugsuitMode = false,
    this.allowedReplaceTurn,
  });

  final Duration timeout;

  final StringBuffer _log = StringBuffer();
  int _branches = 0;
  DateTime? _start;
  DateTime? _deadline;
  String _result = 'unknown';
  int _npAttempts = 0;
  int _skillApplications = 0;
  int _turnsVisited = 0;
  int _maxSkillDepth = 0;
  int _alwaysDeployCount = 0;
  int _prunesWaveNotCleared = 0;

  String get logText {
    final summary = StringBuffer()
      ..writeln('[Auto3T Summary]')
      ..writeln(' - result: ' + _result)
      ..writeln(' - elapsed: ${_elapsed().inMilliseconds}ms')
      ..writeln(' - branchesTried: $_branches')
      ..writeln(' - turnsVisited: $_turnsVisited')
      ..writeln(' - skillApplications: $_skillApplications')
      ..writeln(' - npAttempts: $_npAttempts')
      ..writeln(' - maxSkillDepth: $_maxSkillDepth')
      ..writeln(' - alwaysDeployUsed: $_alwaysDeployCount')
      ..writeln(' - prunesWaveNotCleared: $_prunesWaveNotCleared')
      ..writeln('');
    return '$summary${_log.toString()}';
  }
  int get branchesTried => _branches;
  int get npAttempts => _npAttempts;
  int get turnsVisited => _turnsVisited;
  int get maxSkillDepth => _maxSkillDepth;
  int get alwaysDeployCount => _alwaysDeployCount;
  int get prunesWaveNotCleared => _prunesWaveNotCleared;
  String get result => _result;
  Duration _elapsed() => _start == null ? Duration.zero : DateTime.now().difference(_start!);
  final bool plugsuitMode;
  final int? allowedReplaceTurn;
  bool _checkTimeout() {
    if (_deadline != null && DateTime.now().isAfter(_deadline!)) {
      if (_result == 'unknown') _result = 'timeout';
      _log.writeln('[Auto3T] Timeout reached');
      return true;
    }
    return false;
  }

  Future<BattleShareData?> search() async {
    _start = DateTime.now();
    _deadline = _start!.add(timeout);
    _log.writeln('[Auto3T] Start search');
    _log.writeln(' - excludeAttackerSkills: $excludeAttackerSkills');
    _log.writeln(' - quest: ${quest.id}/${quest.phase}');
    _log.writeln(' - timeout: ${timeout.inSeconds}s');
    // Work on a fresh runtime to avoid mutating the current UI state.
    final runtime = BattleRuntime(
      battleData: BattleData(),
      region: region,
      originalOptions: baseOptions.copy(),
      originalQuest: quest,
    );
    final data = runtime.battleData;

    // Initialize battle using the current formation and settings.
    await data.init(
      quest,
      [
        ...runtime.originalOptions.formation.onFieldSvtDataList,
        ...runtime.originalOptions.formation.backupSvtDataList,
      ],
      runtime.originalOptions.formation.mysticCodeData,
    );
    _log.writeln(' - init: wave=${data.waveCount}, enemyOnField=${data.enemyOnFieldCount}');

    // Targeting without UI interactions.
    data.options.manualAllySkillTarget = false;
    data.playerTargetIndex = 0; // attacker as ally target
    _setFirstAliveEnemyAsTarget(data);

    final savedSimEnemy = data.options.simulateEnemy;
    // For search stability, disable enemy simulation (keeps turn outcome deterministic for our objective).
    data.options.simulateEnemy = false;
    _log.writeln(' - simulateEnemy: disabled for search');

    // Use a delegate to avoid prompts and make deterministic choices for ptRandom/skill branches.
    final delegate = _Auto3TDelegate(data);
    final savedDelegate = data.delegate;
    data.delegate = delegate;

    try {
      final success = await _searchTurn(data, currentTurn: 1);
      if (!success) {
        if (_result == 'unknown') _result = 'no_solution';
        _log.writeln('[Auto3T] Search ended: ' + _result);
        return null;
      }
      _result = 'success';
      _log.writeln('[Auto3T] Found solution');
      // Return the replay data from the solver runtime so the UI can replay it.
      return runtime.getShareData();
    } finally {
      data.delegate = savedDelegate;
      data.options.simulateEnemy = savedSimEnemy;
    }
  }

  Future<bool> _searchTurn(BattleData data, {required int currentTurn, bool usedReplace = false}) async {
    if (_checkTimeout()) return false;
    if (data.isBattleWin) {
      // Finished early is acceptable for a 3-turn goal.
      return true;
    }
    if (currentTurn > 3) {
      // Must be win by the end of Turn 3.
      return data.isBattleWin;
    }
    _turnsVisited += 1;
    final remainingTurns = 4 - currentTurn;

    // Apply always-deploy skills for this turn.
    final beforeAlwaysSnapshots = data.snapshots.length;
    final alwaysApplied = await _applyAlwaysDeploySkills(data, remainingTurns: remainingTurns);
    _log.writeln('[Turn$currentTurn] Always-deploy skills applied: ${alwaysApplied.length}');
    // Log classification for applied skills
    for (final act in alwaysApplied) {
      if (act.isMysticCode) {
        final info = data.masterSkillInfo.getOrNull(act.mcSkillIndex);
        if (info != null) {
          final c = SkillClassifier.classifySkill(info);
          _log.writeln('  >> ${c.toString()}');
        }
      } else {
        final svt = data.onFieldAllyServants.getOrNull(act.svtIndex);
        final info = svt?.skillInfoList.getOrNull(act.skillIndex);
        if (info != null) {
          final c = SkillClassifier.classifySkill(info);
          _log.writeln('  >> ${c.toString()}');
        }
      }
    }
    _alwaysDeployCount += alwaysApplied.length;

    // Prepare canonical action list once for combination enumeration.
    final canonicalActions = _collectUsableSkillActions(data, currentTurn, usedReplace)
      ..sort((a, b) {
        int ai = a.isMysticCode ? 1 : 0;
        int bi = b.isMysticCode ? 1 : 0;
        if (ai != bi) return ai.compareTo(bi);
        if (a.isMysticCode) return a.mcSkillIndex.compareTo(b.mcSkillIndex);
        final c = a.svtIndex.compareTo(b.svtIndex);
        if (c != 0) return c;
        return a.skillIndex.compareTo(b.skillIndex);
      });

    // Depth-first over combinations of usable skills, attempting NP set at every prefix
    // to cover 0..N skills used before NP.
    final result = await _dfsSkillsThenNp(data, canonicalActions, currentTurn: currentTurn, depth: 0, startIndex: 0);

    // Only backtrack always-deploy skills if this branch failed.
    if (!result) {
      while (data.snapshots.length > beforeAlwaysSnapshots) {
        data.popSnapshot();
      }
    }
    return result;
  }

  Future<bool> _dfsSkillsThenNp(
    BattleData data,
    List<_SkillAction> actions, {
    required int currentTurn,
    int depth = 0,
    int startIndex = 0,
    bool usedReplace = false,
  }) async {
    if (_checkTimeout()) return false;
    if (depth > _maxSkillDepth) _maxSkillDepth = depth;
    _log.writeln('[Turn$currentTurn] Try NPs (prefix skills applied)');
    // Attempt NP with current prefix (0-skill or more).
    final beforeNpSnapshots = data.snapshots.length;
    if (await _tryNPCombos(data)) {
      if (data.isBattleWin) return true;
      final ok = await _searchTurn(data, currentTurn: currentTurn + 1, usedReplace: usedReplace);
      if (ok) return true;
      // Backtrack NP and continue exploring more skills for this turn
      while (data.snapshots.length > beforeNpSnapshots) {
        data.popSnapshot();
      }
      _log.writeln('[Turn$currentTurn] Backtrack NP(s), continue skills');
    }

    // Otherwise expand by applying one more usable skill (combinations via startIndex) and recurse.
    _log.writeln('[Turn$currentTurn] Usable skills: ${actions.length}');
    // Log classification summaries (first time at this turn)
    for (int i = startIndex; i < actions.length; i++) {
      final act = actions[i];
      if (act.isMysticCode) {
        final info = data.masterSkillInfo.getOrNull(act.mcSkillIndex);
        if (info != null) {
          final c = SkillClassifier.classifySkill(info);
          _log.writeln('  - ${c.toString()}');
        }
      } else {
        final svt = data.onFieldAllyServants.getOrNull(act.svtIndex);
        final info = svt?.skillInfoList.getOrNull(act.skillIndex);
        if (info != null) {
          final c = SkillClassifier.classifySkill(info);
          _log.writeln('  - ${c.toString()}');
        }
      }
    }
    if (actions.isEmpty) {
      _log.writeln('[Turn$currentTurn] Dead end: no skills and NP failed');
      return false;
    }
    for (int i = startIndex; i < actions.length; i++) {
      final act = actions[i];
      // Skip if no longer usable due to previous selections
      if (act.isMysticCode) {
        final info = data.masterSkillInfo.getOrNull(act.mcSkillIndex);
        if (info == null || info.chargeTurn != 0) continue;
        if (_isReplaceMember(info)) {
          if (!plugsuitMode) continue;
          if (usedReplace) continue;
          if (allowedReplaceTurn != null && allowedReplaceTurn != currentTurn) continue;
        }
      } else {
        final svt = data.onFieldAllyServants.getOrNull(act.svtIndex);
        if (svt == null) continue;
        final info = svt.skillInfoList.getOrNull(act.skillIndex);
        if (info == null || info.chargeTurn != 0) continue;
        if (data.isSkillSealed(act.svtIndex, act.skillIndex)) continue;
        if (data.isSkillCondFailed(act.svtIndex, act.skillIndex)) continue;
        if (_isOberon(svt) && act.skillIndex == 2 && currentTurn < 3) continue;
      }
      _branches += 1;
      if (act.isMysticCode) {
        final info = data.masterSkillInfo[act.mcSkillIndex];
        _log.writeln('[Turn$currentTurn] Use MC skill #${act.mcSkillIndex + 1}: ${info.lName}');
      } else {
        final svt = data.onFieldAllyServants[act.svtIndex];
        final info = svt?.skillInfoList[act.skillIndex];
        _log.writeln('[Turn$currentTurn] Use svt${act.svtIndex + 1} skill #${act.skillIndex + 1}: ${info?.lName ?? '?'}');
      }
      bool isReplace = false;
      if (act.isMysticCode) {
        final info = data.masterSkillInfo[act.mcSkillIndex];
        isReplace = _isReplaceMember(info);
        await data.activateMysticCodeSkill(act.mcSkillIndex);
      } else {
        await data.activateSvtSkill(act.svtIndex, act.skillIndex);
      }
      _skillApplications += 1;

      // Maintain targeting assumptions.
      data.playerTargetIndex = 0;
      _setFirstAliveEnemyAsTarget(data);

      final ok = await _dfsSkillsThenNp(
        data,
        actions,
        currentTurn: currentTurn,
        depth: depth + 1,
        startIndex: i + 1,
        usedReplace: usedReplace || isReplace,
      );
      if (ok) return true;

      // Backtrack the last skill application.
      _log.writeln('[Turn$currentTurn] Backtrack');
      data.popSnapshot();
      if (_checkTimeout()) return false;
    }
    return false;
  }

  Future<bool> _tryNPCombos(BattleData data) async {
    // Build NP candidates
    final List<int> cand = [];
    for (int i = 0; i < data.onFieldAllyServants.length; i++) {
      final svt = data.onFieldAllyServants.getOrNull(i);
      if (svt == null) continue;
      if (svt.canSelectNP(data)) cand.add(i);
    }
    if (cand.isEmpty) {
      _log.writeln('  - No NP-capable ally at this prefix');
      return false;
    }
    final bool attackerReady = cand.contains(0);
    final supports = cand.where((i) => i != 0).toList()..sort();

    // Iterate over subsets of supports, and optionally attacker last
    final int supCount = supports.length;
    final int maskMax = 1 << supCount;
    for (int mask = 0; mask < maskMax; mask++) {
      for (final includeAttacker in [false, true]) {
        if (!includeAttacker && mask == 0) continue; // must use at least one NP
        if (includeAttacker && !attackerReady) continue;

        final List<CombatAction> actions = [];
        // supports first
        for (int k = 0; k < supCount; k++) {
          if (((mask >> k) & 1) == 1) {
            final idx = supports[k];
            final svt = data.onFieldAllyServants[idx]!;
            final card = svt.getNPCard();
            if (card != null) actions.add(CombatAction(svt, card));
          }
        }
        // attacker last
        if (includeAttacker) {
          final atk = data.onFieldAllyServants[0]!;
          final card = atk.getNPCard();
          if (card != null) actions.add(CombatAction(atk, card));
        }
        if (actions.isEmpty) continue;

        _npAttempts += 1;
        _setFirstAliveEnemyAsTarget(data);
        final prevWave = data.waveCount;
        await data.playerTurn(actions);
        if (data.waveCount > prevWave || data.isBattleWin) {
          _log.writeln('  - NP success with ${actions.length} NP(s): wave $prevWave -> ${data.waveCount}');
          return true;
        }
        _log.writeln('  - NP combo failed (${actions.length}); undo');
        _prunesWaveNotCleared += 1;
        data.popSnapshot();
        if (_checkTimeout()) return false;
      }
    }
    return false;
  }

  void _setFirstAliveEnemyAsTarget(BattleData data) {
    int idx = -1;
    int bestHp = -1;
    for (int i = 0; i < data.onFieldEnemies.length; i++) {
      final e = data.onFieldEnemies[i];
      if (e != null && e.hp > 0) {
        if (e.hp > bestHp) {
          bestHp = e.hp;
          idx = i;
        }
      }
    }
    data.enemyTargetIndex = idx < 0 ? 0 : idx;
  }

  List<_SkillAction> _collectUsableSkillActions(BattleData data, int currentTurn, bool usedReplace) {
    final list = <_SkillAction>[];

    // Ally skills (on-field only). Optionally exclude attacker skills.
    for (int i = 0; i < data.onFieldAllyServants.length; i++) {
      final svt = data.onFieldAllyServants[i];
      if (svt == null) continue;
      if (excludeAttackerSkills && i == 0) continue;

      for (int j = 0; j < svt.skillInfoList.length; j++) {
        final info = svt.skillInfoList[j];
        if (info.chargeTurn != 0) continue;
        if (data.isSkillSealed(i, j)) continue;
        if (data.isSkillCondFailed(i, j)) continue;
        // Oberon S3 only on T3
        if (_isOberon(svt) && j == 2 && currentTurn < 3) continue;
        list.add(_SkillAction.svt(i, j));
    }
  }

    // Mystic Code skills
    for (int k = 0; k < data.masterSkillInfo.length; k++) {
      final info = data.masterSkillInfo[k];
      if (info.chargeTurn != 0) continue;
      final skill = info.skill;
      if (skill == null) continue;
      final hasOrderChange = skill.functions.any((f) => f.funcType == FuncType.replaceMember);
      if (hasOrderChange) {
        if (!plugsuitMode) continue;
        if (usedReplace) continue;
        if (allowedReplaceTurn != null && allowedReplaceTurn != currentTurn) continue;
      }
      if (!data.canUseMysticCodeSkillIgnoreCoolDown(k)) continue;
      list.add(_SkillAction.mc(k));
    }

    return list;
  }

  Future<List<_SkillAction>> _applyAlwaysDeploySkills(BattleData data, {required int remainingTurns}) async {
    final applied = <_SkillAction>[];
    bool usableSvt(int i, int j) {
      final svt = data.onFieldAllyServants.getOrNull(i);
      if (svt == null) return false;
      final info = svt.skillInfoList.getOrNull(j);
      if (info == null) return false;
      if (info.chargeTurn != 0) return false;
      if (data.isSkillSealed(i, j)) return false;
      if (data.isSkillCondFailed(i, j)) return false;
      return _isAlwaysDeploy(info, remainingTurns: remainingTurns);
    }

    for (int i = 0; i < data.onFieldAllyServants.length; i++) {
      for (int j = 0; j < 3; j++) {
        if (!usableSvt(i, j)) continue;
        await data.activateSvtSkill(i, j);
        applied.add(_SkillAction.svt(i, j));
      }
    }

    // MC skills
    for (int k = 0; k < data.masterSkillInfo.length; k++) {
      final info = data.masterSkillInfo[k];
      if (info.chargeTurn != 0) continue;
      if (!_isAlwaysDeploy(info, remainingTurns: remainingTurns)) continue;
      if (_isReplaceMember(info)) continue;
      await data.activateMysticCodeSkill(k);
      applied.add(_SkillAction.mc(k));
    }
    return applied;
  }

  bool _isAlwaysDeploy(BattleSkillInfoData info, {required int remainingTurns}) {
    final skill = info.skill;
    if (skill == null) return false;
    // reject order change or immediate NP-gain
    for (final f in skill.functions) {
      if (f.funcType == FuncType.replaceMember) return false;
      if (f.funcType == FuncType.gainNp) return false;
    }
    // accept if has any long-duration buff (remainingTurns)
    final lv = info.skillLv <= 0 ? 1 : info.skillLv;
    for (final f in skill.functions) {
      if (!f.funcType.isAddState) continue;
      final vals = f.svals.getOrNull(lv - 1);
      final turn = vals?.Turn ?? 0;
      if (turn >= remainingTurns) return true;
    }
    return false;
  }

  bool _isReplaceMember(BattleSkillInfoData info) {
    final s = info.skill;
    if (s == null) return false;
    return s.functions.any((f) => f.funcType == FuncType.replaceMember);
  }

  bool _isOberon(BattleServantData svt) {
    return svt.niceSvt?.collectionNo == 316;
  }
}

class _SkillAction {
  final bool isMysticCode;
  final int svtIndex;
  final int skillIndex;
  final int mcSkillIndex;

  _SkillAction.svt(this.svtIndex, this.skillIndex)
      : isMysticCode = false,
        mcSkillIndex = -1;

  _SkillAction.mc(this.mcSkillIndex)
      : isMysticCode = true,
        svtIndex = -1,
        skillIndex = -1;

  String get key => isMysticCode ? 'mc:$mcSkillIndex' : 's:$svtIndex/$skillIndex';
}

/// Delegate to avoid UI prompts and enforce deterministic choices during search.
class _Auto3TDelegate extends BattleDelegate {
  final BattleData data;
  _Auto3TDelegate(this.data) {
    // Choose the first branch option when needed.
    skillActSelect = (_) async => 1;

    // For ptRandom on ally-side, pick attacker (index 0) if present; else fallback to first.
    ptRandom = (targets) async {
      final attacker = data.onFieldAllyServants.getOrNull(0);
      if (attacker != null) {
        final t = targets.firstWhereOrNull((e) => e.uniqueId == attacker.uniqueId);
        if (t != null) return t;
      }
      return targets.firstOrNull;
    };

    // For probability checks when tailoredExecution=true, just accept engine's current result.
    canActivate = (curResult) async => curResult;

    // Prefer swapping out slot 1 (owned Castoria) with backup slot 0 (Oberon)
    replaceMember = (onFieldSvts, backupSvts) async {
      final onField = onFieldSvts.getOrNull(1);
      final backup = backupSvts.getOrNull(0);
      if (onField != null && backup != null) {
        return Tuple2(onField, backup);
      }
      final anyOn = onFieldSvts.firstWhereOrNull((e) => e != null);
      final anyBk = backupSvts.firstWhereOrNull((e) => e != null);
      if (anyOn != null && anyBk != null) return Tuple2(anyOn, anyBk);
      return null;
    };
  }
}
