import 'dart:async';

import 'package:chaldea/app/battle/interactions/_delegate.dart';
import 'package:chaldea/app/battle/models/battle.dart';
import 'package:chaldea/models/models.dart';
import 'package:chaldea/utils/extension.dart';

/// Auto 3T solver that searches for a 3-turn clear by enumerating
/// all permutations of usable skills per turn and ending each turn
/// with the attacker's NP.
///
/// Assumptions (v1):
/// - Attacker is the first on-field ally (index 0).
/// - No Order Change / swaps.
/// - Each turn ends by using only the attacker's NP.
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
      ..writeln('');
    return '$summary${_log.toString()}';
  }
  int get branchesTried => _branches;
  Duration _elapsed() => _start == null ? Duration.zero : DateTime.now().difference(_start!);
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

  Future<bool> _searchTurn(BattleData data, {required int currentTurn}) async {
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

    // Depth-first over all permutations of usable skills, attempting NP at every prefix
    // to cover 0..N skills used before NP.
    return await _dfsSkillsThenNp(data, currentTurn: currentTurn);
  }

  Future<bool> _dfsSkillsThenNp(BattleData data, {required int currentTurn, int depth = 0}) async {
    if (_checkTimeout()) return false;
    if (depth > _maxSkillDepth) _maxSkillDepth = depth;
    _log.writeln('[Turn$currentTurn] Try NP (prefix skills applied)');
    // Attempt NP with current prefix (0-skill or more).
    final beforeNpSnapshots = data.snapshots.length;
    if (await _tryNP(data)) {
      if (data.isBattleWin) return true;
      final ok = await _searchTurn(data, currentTurn: currentTurn + 1);
      if (ok) return true;
      // Backtrack NP and continue exploring more skills for this turn
      while (data.snapshots.length > beforeNpSnapshots) {
        data.popSnapshot();
      }
      _log.writeln('[Turn$currentTurn] Backtrack NP, continue skills');
    }

    // Otherwise expand by applying one more usable skill and recurse.
    final actions = _collectUsableSkillActions(data);
    _log.writeln('[Turn$currentTurn] Usable skills: ${actions.length}');
    if (actions.isEmpty) {
      _log.writeln('[Turn$currentTurn] Dead end: no skills and NP failed');
      return false;
    }
    for (final act in actions) {
      _branches += 1;
      if (act.isMysticCode) {
        final info = data.masterSkillInfo[act.mcSkillIndex];
        _log.writeln('[Turn$currentTurn] Use MC skill #${act.mcSkillIndex + 1}: ${info.lName}');
      } else {
        final svt = data.onFieldAllyServants[act.svtIndex];
        final info = svt?.skillInfoList[act.skillIndex];
        _log.writeln('[Turn$currentTurn] Use svt${act.svtIndex + 1} skill #${act.skillIndex + 1}: ${info?.lName ?? '?'}');
      }
      if (act.isMysticCode) {
        await data.activateMysticCodeSkill(act.mcSkillIndex);
      } else {
        await data.activateSvtSkill(act.svtIndex, act.skillIndex);
      }
      _skillApplications += 1;

      // Maintain targeting assumptions.
      data.playerTargetIndex = 0;
      _setFirstAliveEnemyAsTarget(data);

      final ok = await _dfsSkillsThenNp(data, currentTurn: currentTurn, depth: depth + 1);
      if (ok) return true;

      // Backtrack the last skill application.
      _log.writeln('[Turn$currentTurn] Backtrack');
      data.popSnapshot();
      if (_checkTimeout()) return false;
    }
    return false;
  }

  Future<bool> _tryNP(BattleData data) async {
    _npAttempts += 1;
    final attacker = data.onFieldAllyServants.getOrNull(0);
    if (attacker == null) return false;
    if (!attacker.canSelectNP(data)) {
      _log.writeln('  - NP not ready: np=${attacker.np}, canNP=${attacker.canNP()}');
      return false;
    }

    // Ensure we hit the first alive enemy if single-target.
    _setFirstAliveEnemyAsTarget(data);

    final prevWave = data.waveCount;
    final card = attacker.getNPCard();
    if (card == null) return false;

    await data.playerTurn([CombatAction(attacker, card)]);

    // Success if wave advanced or the battle ended.
    if (data.waveCount > prevWave || data.isBattleWin) {
      _log.writeln('  - NP success: wave ${prevWave} -> ${data.waveCount}');
      return true;
    }

    // Revert NP.
    _log.writeln('  - NP failed to clear wave; undo');
    data.popSnapshot();
    return false;
  }

  void _setFirstAliveEnemyAsTarget(BattleData data) {
    int idx = 0;
    for (int i = 0; i < data.onFieldEnemies.length; i++) {
      final e = data.onFieldEnemies[i];
      if (e != null && e.hp > 0) {
        idx = i;
        break;
      }
    }
    data.enemyTargetIndex = idx;
  }

  List<_SkillAction> _collectUsableSkillActions(BattleData data) {
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
        list.add(_SkillAction.svt(i, j));
      }
    }

    // Mystic Code skills (exclude Order Change explicitly).
    for (int k = 0; k < data.masterSkillInfo.length; k++) {
      final info = data.masterSkillInfo[k];
      if (info.chargeTurn != 0) continue;
      final skill = info.skill;
      if (skill == null) continue;
      final hasOrderChange = skill.functions.any((f) => f.funcType == FuncType.replaceMember);
      if (hasOrderChange) continue;
      if (!data.canUseMysticCodeSkillIgnoreCoolDown(k)) continue;
      list.add(_SkillAction.mc(k));
    }

    return list;
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
  }
}
