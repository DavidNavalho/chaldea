import 'package:flutter/material.dart';

import 'package:chaldea/app/api/atlas.dart';
import 'package:chaldea/app/modules/battle/utils.dart';
import 'package:chaldea/custom/shared_teams/my_box_compatibility.dart';
import 'package:chaldea/models/api/api.dart';
import 'package:chaldea/models/models.dart';

const int kMyBoxBatchLimit = 200;

class MyBoxBatchCandidateSelection {
  final List<UserBattleData> candidates;
  final int strictCount;
  final int relaxedOnlyCount;

  const MyBoxBatchCandidateSelection({
    required this.candidates,
    required this.strictCount,
    required this.relaxedOnlyCount,
  });

  bool get isEmpty => candidates.isEmpty;
}

class MyBoxBatchRunReport {
  final int wins;
  final int total;
  final int uniqueWins;
  final int strictCount;
  final int relaxedOnlyCount;
  final Object? error;

  const MyBoxBatchRunReport({
    required this.wins,
    required this.total,
    required this.uniqueWins,
    required this.strictCount,
    required this.relaxedOnlyCount,
    this.error,
  });
}

class MyBoxRunButtonStyle {
  final String label;
  final Color backgroundColor;

  const MyBoxRunButtonStyle({required this.label, required this.backgroundColor});
}

class SharedTeamsMyBoxBatchController {
  final Map<int, TeamBoxMatchScore> _scoreCache = {};
  final Map<int, MyBoxReplayRunResult> _results = {};
  final Map<int, int> _evalOrder = {};
  final Set<int> _uniqueWinners = {};

  Map<int, MyBoxReplayRunResult> get results => _results;
  bool get hasResults => _results.isNotEmpty;
  int get winCount => _results.values.where((e) => e.win).length;
  int get uniqueWinCount => _uniqueWinners.length;

  TeamBoxMatchScore scoreOf(UserBattleData record, TeamBoxMatchScore Function(BattleShareData data) evaluator) {
    return _scoreCache.putIfAbsent(record.id, () {
      final data = record.decoded;
      if (data == null) {
        return const TeamBoxMatchScore(
          hardMismatch: 999,
          npDeficit: 999,
          skillDeficit: 999,
          appendDeficit: 999,
          appendDeficitFarmable: 999,
          servantLevelDeficit: 999,
          ceMlbMissing: 999,
          ceLevelDeficit: 999,
          mcLevelDeficit: 999,
          usedServantSlots: 99,
        );
      }
      return evaluator(data);
    });
  }

  void clearScoreCache() {
    _scoreCache.clear();
  }

  void clearBatchResults() {
    _results.clear();
    _evalOrder.clear();
    _uniqueWinners.clear();
  }

  void clearAll() {
    clearScoreCache();
    clearBatchResults();
  }

  MyBoxReplayRunResult? resultOf(UserBattleData record) => _results[record.id];

  bool isUniqueWinner(UserBattleData record) => _uniqueWinners.contains(record.id);

  int compareRecords({
    required UserBattleData a,
    required UserBattleData b,
    required bool prioritizeMyBox,
    required TeamBoxMatchStrictness strictness,
    required TeamBoxMatchScore Function(BattleShareData data) evaluator,
    required int Function(UserBattleData a, UserBattleData b) fallbackCompare,
  }) {
    if (_results.isNotEmpty) {
      final aGroup = _batchSortGroup(a);
      final bGroup = _batchSortGroup(b);
      int c = aGroup.compareTo(bGroup);
      if (c != 0) return c;
      if (aGroup <= 2) {
        c = (_evalOrder[a.id] ?? 1 << 30).compareTo(_evalOrder[b.id] ?? 1 << 30);
        if (c != 0) return c;
      }
    }

    if (prioritizeMyBox) {
      final aData = a.decoded;
      final bData = b.decoded;
      if (aData != null && bData != null) {
        final aScore = scoreOf(a, evaluator);
        final bScore = scoreOf(b, evaluator);
        final aMatch = aScore.matches(strictness) ? 0 : 1;
        final bMatch = bScore.matches(strictness) ? 0 : 1;
        int c = aMatch.compareTo(bMatch);
        if (c != 0) return c;
        c = aScore.hardMismatch.compareTo(bScore.hardMismatch);
        if (c != 0) return c;
        c = aScore.weightedPenalty.compareTo(bScore.weightedPenalty);
        if (c != 0) return c;
        c = aScore.usedServantSlots.compareTo(bScore.usedServantSlots);
        if (c != 0) return c;
      }
    }

    return fallbackCompare(a, b);
  }

  MyBoxBatchCandidateSelection selectCandidates(
    List<UserBattleData> sortedShownList, {
    int limit = kMyBoxBatchLimit,
    required TeamBoxMatchScore Function(BattleShareData data) evaluator,
  }) {
    final topRecords = sortedShownList.take(limit).toList();
    final candidates = <UserBattleData>[];
    int strictCount = 0;
    int relaxedOnlyCount = 0;
    for (final record in topRecords) {
      final data = record.decoded;
      if (data == null || data.actions.isEmpty) continue;
      final score = scoreOf(record, evaluator);
      if (score.matches(TeamBoxMatchStrictness.relaxed)) {
        candidates.add(record);
        if (score.matches(TeamBoxMatchStrictness.strict)) {
          strictCount += 1;
        } else {
          relaxedOnlyCount += 1;
        }
      }
    }
    return MyBoxBatchCandidateSelection(
      candidates: candidates,
      strictCount: strictCount,
      relaxedOnlyCount: relaxedOnlyCount,
    );
  }

  Future<MyBoxBatchRunReport> runCandidates(
    MyBoxBatchCandidateSelection selection, {
    void Function(int done, int total)? onProgress,
  }) async {
    clearBatchResults();
    final candidates = selection.candidates;
    final questCache = <String, QuestPhase>{};
    Object? runError;

    try {
      for (int i = 0; i < candidates.length; i++) {
        final record = candidates[i];
        final detail = record.decoded;
        _evalOrder[record.id] = i;
        if (detail == null) {
          _results[record.id] = const MyBoxReplayRunResult(win: false, error: 'missing team data');
          onProgress?.call(i + 1, candidates.length);
          continue;
        }

        final questInfo = detail.quest;
        if (questInfo == null) {
          _results[record.id] = const MyBoxReplayRunResult(win: false, error: 'missing quest info');
          onProgress?.call(i + 1, candidates.length);
          continue;
        }

        final cacheKey = '${questInfo.id}:${questInfo.phase}:${questInfo.enemyHash ?? ''}';
        var questPhase = questCache[cacheKey];
        questPhase ??= await AtlasApi.questPhase(
          questInfo.id,
          questInfo.phase,
          hash: questInfo.enemyHash,
          region: Region.jp,
        );
        if (questPhase == null) {
          _results[record.id] = const MyBoxReplayRunResult(win: false, error: 'quest not found');
        } else {
          questCache[cacheKey] = questPhase;
          _results[record.id] = await simulateSharedTeamWithMyBox(detail: detail, questPhase: questPhase);
        }
        onProgress?.call(i + 1, candidates.length);
      }
    } catch (e) {
      runError = e;
    }

    final seenCompositions = <String>{};
    for (final record in candidates) {
      final result = _results[record.id];
      final detail = record.decoded;
      if (result?.win != true || detail == null) continue;
      final key = _servantCompositionKey(detail);
      if (seenCompositions.add(key)) {
        _uniqueWinners.add(record.id);
      }
    }

    return MyBoxBatchRunReport(
      wins: winCount,
      total: _results.length,
      uniqueWins: uniqueWinCount,
      strictCount: selection.strictCount,
      relaxedOnlyCount: selection.relaxedOnlyCount,
      error: runError,
    );
  }

  String? extraInfoLabel(UserBattleData record) {
    final result = _results[record.id];
    if (result == null) return null;
    if (!result.win) return 'Batch Loss';
    if (_uniqueWinners.contains(record.id)) return 'Batch Win (Unique)';
    return 'Batch Win';
  }

  String? badgeLabel(UserBattleData record) {
    final result = _results[record.id];
    if (result == null) return null;
    if (!result.win) return 'LOSS';
    if (_uniqueWinners.contains(record.id)) return 'WIN UNIQUE';
    return 'WIN';
  }

  String? badgeTooltip(UserBattleData record) {
    final result = _results[record.id];
    if (result == null) return null;
    if (!result.win) return 'Batch evaluated: loss';
    if (_uniqueWinners.contains(record.id)) return 'Batch winner (unique comp)';
    return 'Batch winner';
  }

  Color? badgeColor(UserBattleData record, BuildContext context) {
    final result = _results[record.id];
    if (result == null) return null;
    if (!result.win) return Theme.of(context).colorScheme.errorContainer;
    if (_uniqueWinners.contains(record.id)) return Colors.green.shade700;
    return Colors.green.shade600;
  }

  bool isBatchWinner(UserBattleData record) => _results[record.id]?.win == true;

  MyBoxRunButtonStyle runButtonStyle(UserBattleData record, {required bool strictCompatible}) {
    final result = _results[record.id];
    final label = switch ((result?.win, strictCompatible)) {
      (true, true) => 'Run My Box (Strict WIN)',
      (true, false) => 'Run My Box (Relaxed WIN)',
      (false, true) => 'Run My Box (Strict LOSS)',
      (false, false) => 'Run My Box (Relaxed LOSS)',
      _ => strictCompatible ? 'Run My Box (Strict)' : 'Run My Box (Relaxed)',
    };
    final color = switch ((result?.win, strictCompatible)) {
      (true, _) => Colors.green.shade700,
      (false, _) => Colors.red.shade700,
      _ => strictCompatible ? Colors.green : Colors.orange,
    };
    return MyBoxRunButtonStyle(label: label, backgroundColor: color);
  }

  int _batchSortGroup(UserBattleData record) {
    final result = _results[record.id];
    if (result == null) return 3; // not evaluated
    if (result.win && _uniqueWinners.contains(record.id)) return 0;
    if (result.win) return 1;
    return 2;
  }

  static String _servantCompositionKey(BattleShareData data) {
    final ids = <int>[];
    for (final svt in data.formation.svts) {
      final svtId = svt?.svtId ?? 0;
      if (svtId > 0) ids.add(svtId);
    }
    ids.sort();
    return ids.join('-');
  }
}
