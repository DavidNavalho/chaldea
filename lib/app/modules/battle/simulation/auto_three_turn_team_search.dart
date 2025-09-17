import 'package:chaldea/app/battle/models/user.dart';
import 'package:chaldea/app/modules/battle/simulation/auto_three_turn_solver.dart';
import 'package:chaldea/models/db.dart';
import 'package:chaldea/models/gamedata/gamedata.dart';
import 'package:chaldea/models/gamedata/common.dart';
import 'package:chaldea/models/gamedata/servant.dart';
import 'package:chaldea/models/userdata/battle.dart';
import 'package:chaldea/models/userdata/userdata.dart';
import 'package:chaldea/utils/extension.dart';
import 'package:chaldea/models/models.dart';

/// Orchestrates Auto 3T search across attacker + CE candidates for the
/// 1-attacker + 2-Castoria team pattern.
class AutoThreeTurnTeamSearch {
  final QuestPhase quest;
  final Region? region;
  final BattleOptions baseOptions; // used for MC/options; formation overridden per candidate
  final Duration timeout;

  AutoThreeTurnTeamSearch({
    required this.quest,
    required this.region,
    required this.baseOptions,
    this.timeout = const Duration(seconds: 60),
  });

  Future<BattleShareData?> search() async {
    _attempts.clear();
    _log.clear();
    _candidateAttackersCount = 0;
    final startedAt = DateTime.now();
    final deadline = startedAt.add(timeout);
    // Resolve owned Castoria (must exist) and support Castoria template.
    final castoriaOwned = _findOwnedCastoria();
    if (castoriaOwned == null) {
      return null; // per spec: stop completely if no owned Castoria
    }
    final castoriaSupport = castoriaOwned; // use same servant entry; we will mark as support

    // Compute top attacker classes based on enemy class relations.
    final topClasses = _selectTopAttackerClasses();

    // Build attacker candidates: all owned SSR servants with Arts NP, filtered by top classes.
    final attackers = _findOwnedArtsSSR(allowedClasses: topClasses);
    _candidateAttackersCount = attackers.length;
    if (attackers.isEmpty) return null;

    // CE candidates for attacker (by collectionNo)
    final ceCandidates = _resolveAttackerCeCandidates();

    for (final attacker in attackers) {
      // Pass A: Double Castoria + Summer Streetwear (#330)
      for (final ce in ceCandidates) {
        final nowA = DateTime.now();
        final remainingA = deadline.difference(nowA);
        if (remainingA.isNegative || remainingA.inMilliseconds == 0) return null;
        final optA = baseOptions.copy();
        final onField = await _buildOnField(
          attacker: attacker,
          ownedCastoria: castoriaOwned,
          supportCastoria: castoriaSupport,
          attackerCe: ce,
        );
        final mcA = MysticCodeData()
          ..mysticCode = db.gameData.mysticCodes[330]
          ..level = 10;
        optA.formation = BattleTeamSetup(
          onFieldSvtDataList: onField,
          mysticCodeData: mcA,
        );
        final solverA = AutoThreeTurnSolver(
          quest: quest,
          region: region,
          baseOptions: optA,
          excludeAttackerSkills: false,
          timeout: remainingA,
        );
        final t0 = DateTime.now();
        final resA = await solverA.search();
        final dt = DateTime.now().difference(t0);
        _recordAttempt(
          attacker: attacker,
          ce: ce,
          mcId: 330,
          ocTurn: null,
          solver: solverA,
          elapsed: dt,
        );
        if (resA != null) return resA;
      }

      // Pass B: Plugsuit (#210) + Oberon in backup (slot 4). OC priority 3 -> 2 -> 1.
      final oberon = db.gameData.servants[316];
      if (oberon != null) {
        for (final ce in ceCandidates) {
          for (final ocTurn in const [3, 2, 1]) {
            final nowB = DateTime.now();
            final remainingB = deadline.difference(nowB);
            if (remainingB.isNegative || remainingB.inMilliseconds == 0) return null;
            final optB = baseOptions.copy();
            final pairs = await _buildOnFieldWithOberon(
              attacker: attacker,
              ownedCastoria: castoriaOwned,
              supportCastoria: castoriaSupport,
              oberon: oberon,
              attackerCe: ce,
            );
            final mcB = MysticCodeData()
              ..mysticCode = db.gameData.mysticCodes[210]
              ..level = 10;
            optB.formation = BattleTeamSetup(
              onFieldSvtDataList: pairs.$1,
              backupSvtDataList: pairs.$2,
              mysticCodeData: mcB,
            );
            final solverB = AutoThreeTurnSolver(
              quest: quest,
              region: region,
              baseOptions: optB,
              excludeAttackerSkills: false,
              timeout: remainingB,
              plugsuitMode: true,
              allowedReplaceTurn: ocTurn,
            );
            final t0b = DateTime.now();
            final resB = await solverB.search();
            final dtb = DateTime.now().difference(t0b);
            _recordAttempt(
              attacker: attacker,
              ce: ce,
              mcId: 210,
              ocTurn: ocTurn,
              solver: solverB,
              elapsed: dtb,
            );
            if (resB != null) return resB;
          }
        }
      }
    }
    return null;
  }

  Servant? _findOwnedCastoria() {
    // Match by name heuristics: support both JP/EN variants
    final patterns = ['キャスター', 'キャストリア', 'アルトリア', 'Artoria', 'Altria', 'Castoria'];
    for (final entry in db.curUser.servants.entries) {
      final colNo = entry.key;
      final status = entry.value;
      if (status.cur.favorite != true) continue;
      final svt = db.gameData.servants[colNo];
      if (svt == null) continue;
      if (svt.classId != SvtClass.caster.value) continue;
      final n = svt.name.toLowerCase();
      if (patterns.any((p) => n.contains(p.toLowerCase()))) {
        // ensure it's truly Castoria by checking she has Arts NP and skills consistent
        if (svt.noblePhantasms.any((td) => td.svt.card.isArts())) {
          return svt;
        }
      }
    }
    return null;
  }

  List<Servant> _findOwnedArtsSSR({Set<int>? allowedClasses}) {
    final List<Servant> list = [];
    for (final entry in db.curUser.servants.entries) {
      final colNo = entry.key;
      final status = entry.value;
      if (status.cur.favorite != true) continue; // owned
      final svt = db.gameData.servants[colNo];
      if (svt == null) continue;
      if (svt.rarity != 5) continue;
      if (!svt.noblePhantasms.any((td) => td.svt.card.isArts())) continue;
      if (allowedClasses != null && allowedClasses.isNotEmpty && !allowedClasses.contains(svt.classId)) continue;
      list.add(svt);
    }
    // Sort attackers to try best-suited first:
    // 1) Berserkers first
    // 2) Higher NP level first (user-owned npLv)
    // 3) Higher ATK as tie-breaker
    list.sort((a, b) {
      int ab = a.classId == SvtClass.berserker.value ? 0 : 1;
      int bb = b.classId == SvtClass.berserker.value ? 0 : 1;
      if (ab != bb) return ab.compareTo(bb);
      final npA = db.curUser.svtStatusOf(a.collectionNo).cur.npLv;
      final npB = db.curUser.svtStatusOf(b.collectionNo).cur.npLv;
      if (npA != npB) return npB.compareTo(npA);
      return b.atkMax.compareTo(a.atkMax);
    });
    return list;
  }

  Set<int> _selectTopAttackerClasses() {
    // Collect defender classes per wave (up to 3 waves)
    final waves = quest.stages;
    final weights = <double>[1.0, 1.2, 1.5];
    // Candidate attacker classes come from owned SSR Arts list
    final allSSRArts = _findOwnedArtsSSR();
    final candidateClasses = allSSRArts.map((e) => e.classId).toSet();
    if (candidateClasses.isEmpty) return candidateClasses;

    final List<_ClassScore> scores = [];
    for (final cls in candidateClasses) {
      double total = 0.0;
      final avgs = <double>[0, 0, 0];
      for (int wi = 0; wi < waves.length && wi < 3; wi++) {
        final stage = waves[wi];
        final enemies = stage.enemies.where((e) => e.deck == DeckType.enemy).toList();
        if (enemies.isEmpty) {
          avgs[wi] = 0;
          continue;
        }
        int bucketSum = 0;
        for (final en in enemies) {
          final rel = db.gameData.constData.getClassIdRelation(cls, en.dispClassId);
          final bucket = rel > 1000
              ? 2
              : (rel == 1000
                  ? 1
                  : 0);
          bucketSum += bucket;
        }
        final avgBucket = bucketSum / enemies.length;
        avgs[wi] = avgBucket;
        total += avgBucket * weights[wi];
      }
      // Prune class that is disadvantaged across all present waves
      final validWaves = avgs.where((v) => v > 0).toList();
      final allWeak = validWaves.isNotEmpty && validWaves.every((v) => v == 0);
      if (!allWeak) {
        scores.add(_ClassScore(cls, total, avgs));
      }
    }
    // Persist latest scores for summary
    _classScores = scores.toList();
    if (scores.isEmpty) return candidateClasses; // fallback
    scores.sort((a, b) {
      final t = b.total.compareTo(a.total);
      if (t != 0) return t;
      // tie-breakers: wave3, wave2, wave1
      for (final idx in [2, 1, 0]) {
        final c = b.avgs[idx].compareTo(a.avgs[idx]);
        if (c != 0) return c;
      }
      return a.classId.compareTo(b.classId);
    });
    final top = scores.take(3).map((e) => e.classId).toSet();
    _topClasses = top.toList();
    return top;
  }

  List<_CeChoice> _resolveAttackerCeCandidates() {
    final choices = <_CeChoice>[];
    // 1) currently equipped CE in UI slot 0 (if any) — use exactly the equipped LB and level
    final curEquip = baseOptions.formation.onFieldSvtDataList[0].equip1;
    final curCe = curEquip.ce;
    if (curCe != null) {
      choices.add(_CeChoice(curCe, curEquip.limitBreak, lv: curEquip.lv));
    }
    // 2) The Black Grail (#48)
    final grail = db.gameData.craftEssences[48];
    if (grail != null && db.curUser.ceStatusOf(48).status == CraftStatus.owned) {
      final stat = db.curUser.ceStatusOf(48);
      choices.add(_CeChoice(grail, stat.limitCount >= 4, lv: stat.lv));
    }
    // 3) Kaleidoscope (#34)
    final scope = db.gameData.craftEssences[34];
    if (scope != null && db.curUser.ceStatusOf(34).status == CraftStatus.owned) {
      final stat = db.curUser.ceStatusOf(34);
      choices.add(_CeChoice(scope, stat.limitCount >= 4, lv: stat.lv));
    }

    // Dedup by ce.id while preferring MLB entry first
    final Map<int, _CeChoice> dedup = {};
    for (final c in choices) {
      final prev = dedup[c.ce.id];
      if (prev == null || (c.limitBreak && !prev.limitBreak)) dedup[c.ce.id] = c;
    }
    return dedup.values.toList();
  }

  Future<List<PlayerSvtData>> _buildOnField({
    required Servant attacker,
    required Servant ownedCastoria,
    required Servant supportCastoria,
    required _CeChoice attackerCe,
  }) async {
    // Attacker from user
    final p0 = PlayerSvtData.svt(attacker);
    p0.onSelectServant(attacker, source: PreferPlayerSvtDataSource.current, region: region);
    p0.equip1 = SvtEquipData(
      ce: attackerCe.ce,
      limitBreak: attackerCe.limitBreak,
      lv: attackerCe.lv ?? attackerCe.ce.lvMax,
    );

    // Owned Castoria from user
    final p1 = PlayerSvtData.svt(ownedCastoria);
    p1.onSelectServant(ownedCastoria, source: PreferPlayerSvtDataSource.current, region: region);

    // Support Castoria: 10/10/10, NP1, max level
    final p2 = PlayerSvtData.svt(supportCastoria)
      ..supportType = SupportSvtType.friend
      ..limitCount = 4
      ..lv = supportCastoria.lvMax
      ..tdLv = 1
      ..skillLvs = [10, 10, 10]
      ..appendLvs = [0, 0, 0]
      ..atkFou = 1000
      ..hpFou = 1000;

    return [p0, p1, p2];
  }

  Future<(List<PlayerSvtData>, List<PlayerSvtData>)> _buildOnFieldWithOberon({
    required Servant attacker,
    required Servant ownedCastoria,
    required Servant supportCastoria,
    required Servant oberon,
    required _CeChoice attackerCe,
  }) async {
    final onField = await _buildOnField(
      attacker: attacker,
      ownedCastoria: ownedCastoria,
      supportCastoria: supportCastoria,
      attackerCe: attackerCe,
    );
    final p3 = PlayerSvtData.svt(oberon)
      ..supportType = SupportSvtType.none
      ..limitCount = 4
      ..lv = oberon.lvMax
      ..tdLv = 1
      ..skillLvs = [10, 10, 10]
      ..appendLvs = [0, 0, 0]
      ..atkFou = 1000
      ..hpFou = 1000;
    final backup = [p3, PlayerSvtData.base(), PlayerSvtData.base()];
    return (onField, backup);
  }

  // Summary logging
  final List<_Attempt> _attempts = [];
  final StringBuffer _log = StringBuffer();
  List<_ClassScore> _classScores = [];
  List<int> _topClasses = [];
  int _candidateAttackersCount = 0;

  void _recordAttempt({
    required Servant attacker,
    required _CeChoice ce,
    required int mcId,
    required int? ocTurn,
    required AutoThreeTurnSolver solver,
    required Duration elapsed,
  }) {
    final attName = attacker.lName.l;
    final className = Transl.svtClassId(attacker.classId).l;
    final ceName = ce.ce.lName.l;
    _attempts.add(
      _Attempt(
        attacker: attName,
        className: className,
        ce: ceName,
        ceMLB: ce.limitBreak,
        ceLv: ce.lv ?? 0,
        mcId: mcId,
        ocTurn: ocTurn,
        result: solver.result,
        branches: solver.branchesTried,
        npAttempts: solver.npAttempts,
        turnsVisited: solver.turnsVisited,
        maxSkillDepth: solver.maxSkillDepth,
        alwaysDeployCount: solver.alwaysDeployCount,
        prunesWaveNotCleared: solver.prunesWaveNotCleared,
        skillApplications: null, // currently not exposed separately
        elapsedMs: elapsed.inMilliseconds,
      ),
    );
  }

  String get summaryText {
    if (_attempts.isEmpty) return 'No attempts recorded.';
    _log.writeln('Team Search 3T Summary');
    // Aggregate to first success if present, otherwise all attempts.
    final int successIndex = _attempts.indexWhere((a) => a.result == 'success');
    final List<_Attempt> considered = successIndex >= 0 ? _attempts.sublist(0, successIndex + 1) : _attempts;
    final bool hasSuccess = successIndex >= 0;
    final double elapsedSec = considered.fold<int>(0, (p, a) => p + a.elapsedMs) / 1000.0;
    // Distinct attackers tried until success
    final Set<String> attackersTried = considered.map((a) => a.attacker).toSet();
    final int attackersTriedCount = attackersTried.length;
    final int attemptsCount = considered.length;
    // Pass counts by MC
    final int passBase = considered.where((a) => a.mcId == 330).length;
    final int passPlug = considered.where((a) => a.mcId == 210).length;
    // CE variants tried (distinct names)
    final int ceVariants = considered.map((a) => a.ce).toSet().length;
    // Totals (to success or to end)
    final int totBranches = considered.fold(0, (p, a) => p + a.branches);
    final int totNp = considered.fold(0, (p, a) => p + a.npAttempts);
    final int totTurnsVisited = considered.fold(0, (p, a) => p + a.turnsVisited);
    final int totAlwaysDeploy = considered.fold(0, (p, a) => p + a.alwaysDeployCount);
    final int totPrunes = considered.fold(0, (p, a) => p + a.prunesWaveNotCleared);

    if (_topClasses.isNotEmpty) {
      final topNames = _topClasses.map((id) => Transl.svtClassId(id).l).join(', ');
      _log.writeln('Top classes chosen: $topNames');
    }
    _log.writeln(hasSuccess
        ? 'Elapsed to success: ${elapsedSec.toStringAsFixed(2)}s'
        : 'Elapsed: ${elapsedSec.toStringAsFixed(2)}s (timeout/no solution)');
    _log.writeln(
        'Attackers enumerated: $_candidateAttackersCount; attempted (distinct): $attackersTriedCount; attempts until success: $attemptsCount');
    _log.writeln('Attempts by pass: Base=$passBase, Plugsuit+Oberon=$passPlug');
    _log.writeln('CE variants tried: $ceVariants');
    _log.writeln(
        'Solver totals: branches=$totBranches; npCombos=$totNp; turnsVisited=$totTurnsVisited; alwaysDeploy=$totAlwaysDeploy; prunes=$totPrunes');
    _log.writeln('');
    if (_classScores.isNotEmpty) {
      _log.writeln('Class scores (weighted total; avgs by W1/W2/W3):');
      final sorted = [..._classScores]..sort((a, b) => b.total.compareTo(a.total));
      for (final s in sorted) {
        final name = Transl.svtClassId(s.classId).l;
        final w1 = s.avgs.getOrNull(0) ?? 0;
        final w2 = s.avgs.getOrNull(1) ?? 0;
        final w3 = s.avgs.getOrNull(2) ?? 0;
        _log.writeln(' - $name: total=${s.total.toStringAsFixed(2)} | '
            'W1=${w1.toStringAsFixed(1)}, W2=${w2.toStringAsFixed(1)}, W3=${w3.toStringAsFixed(1)}');
      }
      _log.writeln('');
    }
    for (final a in _attempts) {
      final oc = a.ocTurn == null ? '-' : 'T${a.ocTurn}';
      final mlb = a.ceMLB ? 'MLB' : 'NLB';
      _log.writeln(
        'MC ${a.mcId} | Attacker: ${a.attacker} (${a.className}) | CE: ${a.ce} [$mlb Lv${a.ceLv}] | OC: $oc | '
        'result: ${a.result} | branches: ${a.branches} | np: ${a.npAttempts} | turns: ${a.turnsVisited} | '
        'alwaysDeploy: ${a.alwaysDeployCount} | prunes: ${a.prunesWaveNotCleared} | ${a.elapsedMs}ms',
      );
    }
    return _log.toString();
  }
}

class _CeChoice {
  final CraftEssence ce;
  final bool limitBreak;
  final int? lv; // owned CE level if available
  _CeChoice(this.ce, this.limitBreak, {this.lv});
}

class _ClassScore {
  final int classId;
  final double total;
  final List<double> avgs; // [w1,w2,w3]
  _ClassScore(this.classId, this.total, this.avgs);
}

class _Attempt {
  final String attacker;
  final String className;
  final String ce;
  final bool ceMLB;
  final int ceLv;
  final int mcId;
  final int? ocTurn;
  final String result;
  final int branches;
  final int npAttempts;
  final int turnsVisited;
  final int maxSkillDepth;
  final int alwaysDeployCount;
  final int prunesWaveNotCleared;
  final int? skillApplications;
  final int elapsedMs;

  _Attempt({
    required this.attacker,
    required this.className,
    required this.ce,
    required this.ceMLB,
    required this.ceLv,
    required this.mcId,
    required this.ocTurn,
    required this.result,
    required this.branches,
    required this.npAttempts,
    required this.turnsVisited,
    required this.maxSkillDepth,
    required this.alwaysDeployCount,
    required this.prunesWaveNotCleared,
    required this.skillApplications,
    required this.elapsedMs,
  });
}
