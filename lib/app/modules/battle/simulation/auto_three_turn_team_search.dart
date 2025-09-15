import 'package:chaldea/app/battle/models/user.dart';
import 'package:chaldea/app/modules/battle/simulation/auto_three_turn_solver.dart';
import 'package:chaldea/models/db.dart';
import 'package:chaldea/models/gamedata/gamedata.dart';
import 'package:chaldea/models/gamedata/common.dart';
import 'package:chaldea/models/gamedata/servant.dart';
import 'package:chaldea/models/userdata/battle.dart';
import 'package:chaldea/models/userdata/userdata.dart';
import 'package:chaldea/utils/extension.dart';

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
    // Resolve owned Castoria (must exist) and support Castoria template.
    final castoriaOwned = _findOwnedCastoria();
    if (castoriaOwned == null) {
      return null; // per spec: stop completely if no owned Castoria
    }
    final castoriaSupport = castoriaOwned; // use same servant entry; we will mark as support

    // Build attacker candidates: all owned SSR servants with Arts NP.
    final attackers = _findOwnedArtsSSR();
    if (attackers.isEmpty) return null;

    // CE candidates for attacker (by collectionNo)
    final ceCandidates = _resolveAttackerCeCandidates();

    for (final attacker in attackers) {
      for (final ce in ceCandidates) {
        final opt = baseOptions.copy();
        // Build on-field team: [attacker, owned Castoria, support Castoria]
        final onField = await _buildOnField(attacker: attacker, ownedCastoria: castoriaOwned, supportCastoria: castoriaSupport, attackerCe: ce);
        opt.formation = BattleTeamSetup(onFieldSvtDataList: onField, mysticCodeData: baseOptions.formation.mysticCodeData.copy());

        final solver = AutoThreeTurnSolver(
          quest: quest,
          region: region,
          baseOptions: opt,
          excludeAttackerSkills: false,
          timeout: timeout,
        );
        final result = await solver.search();
        if (result != null) return result; // first success
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

  List<Servant> _findOwnedArtsSSR() {
    final List<Servant> list = [];
    for (final entry in db.curUser.servants.entries) {
      final colNo = entry.key;
      final status = entry.value;
      if (status.cur.favorite != true) continue; // owned
      final svt = db.gameData.servants[colNo];
      if (svt == null) continue;
      if (svt.rarity != 5) continue;
      if (!svt.noblePhantasms.any((td) => td.svt.card.isArts())) continue;
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
}

class _CeChoice {
  final CraftEssence ce;
  final bool limitBreak;
  final int? lv; // owned CE level if available
  _CeChoice(this.ce, this.limitBreak, {this.lv});
}
