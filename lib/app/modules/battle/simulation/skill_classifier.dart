import 'package:chaldea/models/db.dart';
import 'package:chaldea/models/gamedata/gamedata.dart';
import 'package:chaldea/models/gamedata/const_data.dart';
import 'package:chaldea/app/battle/functions/function_executor.dart';
import 'package:chaldea/app/battle/models/skill.dart';

/// High-level intent buckets for functions/skills. Purely descriptive; no behavior change.
enum SkillTag {
  npBattery, // direct gauge change (incl. aggregate/absorb variants)
  npRefund, // on-hit refund (attacker-side)
  npRegen, // per-turn NP gain
  damageBuff, // attacker-side damage up
  enemyDebuff, // enemy-side damage taken up
  bypassAvoidance, // pierce/sure-hit/break-avoidance
  relationOverwrite, // class/attribute overwrite
  traitProducer, // add trait(s) to self/enemy
  fieldProducer, // field change/field trait
  critStarOnly, // crit/star only effects
  survival, // guts/invul/def/regen-only
  utility, // misc non-damage/np utility
}

class ClassifiedFunction {
  final NiceFunction func;
  final Set<SkillTag> tags;
  final int? turn; // DataVals.Turn if add-state
  final int? count; // DataVals.Count
  final bool isAddState;
  ClassifiedFunction({
    required this.func,
    required this.tags,
    required this.isAddState,
    this.turn,
    this.count,
  });
}

class ClassifiedSkill {
  final BattleSkillInfoData info;
  final List<ClassifiedFunction> parts;
  final Set<SkillTag> tags;
  final int maxTurn; // max DataVals.Turn across add-state parts (0 if none)
  final bool hasDirectBattery; // contains any direct NP battery func type
  ClassifiedSkill({
    required this.info,
    required this.parts,
    required this.tags,
    required this.maxTurn,
    required this.hasDirectBattery,
  });

  @override
  String toString() {
    final name = info.lName;
    final level = info.skillLv;
    final tagStr = tags.map((e) => e.name).toList()..sort();
    return '[Skill] $name Lv.$level | tags=${tagStr.join(',')} | maxTurn=$maxTurn | hasBattery=$hasDirectBattery';
  }
}

class SkillClassifier {
  static bool _isBatteryFunc(final NiceFunction f) {
    switch (f.funcType) {
      case FuncType.gainNp:
      case FuncType.lossNp:
      case FuncType.gainMultiplyNp:
      case FuncType.lossMultiplyNp:
      case FuncType.gainNpIndividualSum:
      case FuncType.gainNpBuffIndividualSum:
      case FuncType.gainNpTargetSum:
      case FuncType.gainNpCriticalstarSum:
      case FuncType.gainNpFromTargets:
      case FuncType.absorbNpturn:
        return true;
      default:
        return false;
    }
  }

  static List<BuffAction> _actionsForBuffType(final Buff? buff) {
    if (buff == null) return const [];
    return db.gameData.constData.buffTypeActionMap[buff.type] ?? const [];
  }

  static bool _hasAnyAction(final Buff? buff, final List<BuffAction> targets) {
    if (buff == null) return false;
    final actions = _actionsForBuffType(buff);
    for (final t in targets) {
      if (actions.contains(t)) return true;
    }
    return false;
  }

  static bool _isDamageBuff(final Buff? buff) {
    return _hasAnyAction(buff, const [
      BuffAction.atk,
      BuffAction.commandAtk,
      BuffAction.npdamage,
      BuffAction.damage,
      BuffAction.damageSpecial,
      BuffAction.damageIndividuality,
      BuffAction.damageIndividualityActiveonly,
      BuffAction.givenDamage,
    ]);
  }

  static bool _isEnemyDebuff(final Buff? buff) {
    return _hasAnyAction(buff, const [
      BuffAction.commandDef,
      BuffAction.defence,
      BuffAction.damageDef,
      BuffAction.npdamageDef,
      BuffAction.specialdefence,
      BuffAction.receiveDamage,
      BuffAction.receiveDamagePierce,
    ]);
  }

  static bool _isNpRefundBuff(final Buff? buff) {
    return _hasAnyAction(buff, const [BuffAction.commandNpAtk, BuffAction.dropNp]);
  }

  static bool _isNpRegenBuff(final Buff? buff) {
    return _hasAnyAction(buff, const [BuffAction.turnendNp]);
  }

  static bool _isBypassAvoidance(final Buff? buff) {
    return _hasAnyAction(buff, const [
      BuffAction.pierceInvincible,
      BuffAction.pierceSpecialInvincible,
      BuffAction.breakAvoidance,
    ]);
  }

  static bool _isRelationOverwrite(final Buff? buff) {
    return _hasAnyAction(buff, const [
      BuffAction.overwriteBattleclass,
      BuffAction.overwriteClassrelatioAtk,
      BuffAction.overwriteClassrelatioDef,
    ]);
  }

  static bool _isTraitProducer(final Buff? buff) {
    return _hasAnyAction(buff, const [
      BuffAction.individualityAdd,
      BuffAction.individualitySub,
    ]);
  }

  static bool _isFieldProducer(final NiceFunction f) {
    // function-level field changes
    return f.funcType == FuncType.addFieldChangeToField ||
        _hasAnyAction(f.buff, const [BuffAction.toFieldChangeField, BuffAction.toFieldSubIndividualityField]);
  }

  static bool _isCritStarOnly(final Buff? buff) {
    return _hasAnyAction(buff, const [
      BuffAction.criticalDamage,
      BuffAction.criticalPoint,
      BuffAction.starweight,
      BuffAction.commandStarAtk,
      BuffAction.commandStarDef,
    ]);
  }

  static bool _isSurvival(final Buff? buff) {
    return _hasAnyAction(buff, const [
      BuffAction.guts,
      BuffAction.invincible,
      BuffAction.avoidance,
      BuffAction.defence,
      BuffAction.overwriteDamageDef,
      BuffAction.gainHp,
      BuffAction.turnendHpRegain,
      BuffAction.preventInvisibleWhenInstantDeath,
      BuffAction.specialInvincible,
    ]);
  }

  static ClassifiedFunction classifyFunction(final NiceFunction func, {required int skillLevel}) {
    final tags = <SkillTag>{};
    if (_isBatteryFunc(func)) tags.add(SkillTag.npBattery);

    // Add-state derived tags
    if (func.funcType.isAddState) {
      final buff = func.buff;
      if (_isDamageBuff(buff)) tags.add(SkillTag.damageBuff);
      if (_isEnemyDebuff(buff)) tags.add(SkillTag.enemyDebuff);
      if (_isNpRefundBuff(buff)) tags.add(SkillTag.npRefund);
      if (_isNpRegenBuff(buff)) tags.add(SkillTag.npRegen);
      if (_isBypassAvoidance(buff)) tags.add(SkillTag.bypassAvoidance);
      if (_isRelationOverwrite(buff)) tags.add(SkillTag.relationOverwrite);
      if (_isTraitProducer(buff)) tags.add(SkillTag.traitProducer);
      if (_isCritStarOnly(buff)) tags.add(SkillTag.critStarOnly);
      if (_isSurvival(buff)) tags.add(SkillTag.survival);
      // Utility catchall: no specific tag matched
      if (tags.isEmpty) tags.add(SkillTag.utility);
    } else {
      // Non add-state: field changes, others
      if (_isFieldProducer(func)) tags.add(SkillTag.fieldProducer);
    }

    // Pull duration if add-state
    int? turn;
    int? count;
    if (func.funcType.isAddState) {
      final vals = FunctionExecutor.getDataVals(func, skillLevel, 1);
      turn = vals.Turn;
      count = vals.Count;
    }

    return ClassifiedFunction(
      func: func,
      tags: tags,
      isAddState: func.funcType.isAddState,
      turn: turn,
      count: count,
    );
  }

  static ClassifiedSkill classifySkill(final BattleSkillInfoData info) {
    final skill = info.skill;
    final parts = <ClassifiedFunction>[];
    final tags = <SkillTag>{};
    int maxTurn = 0;
    bool hasBattery = false;
    if (skill != null) {
      for (final f in skill.functions) {
        final cf = classifyFunction(f, skillLevel: info.skillLv);
        parts.add(cf);
        tags.addAll(cf.tags);
        if (cf.isAddState) {
          final t = cf.turn ?? 0;
          if (t > maxTurn) maxTurn = t;
        }
        hasBattery = hasBattery || _isBatteryFunc(f);
      }
    }
    return ClassifiedSkill(info: info, parts: parts, tags: tags, maxTurn: maxTurn, hasDirectBattery: hasBattery);
  }
}
