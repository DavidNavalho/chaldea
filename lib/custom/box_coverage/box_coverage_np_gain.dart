import 'dart:math' as math;

import 'box_coverage_data_source.dart';

class BoxCoverageNpGainCalculator {
  const BoxCoverageNpGainCalculator._();

  static int computeTotalNpGain(BoxCoverageSourceServant servant) {
    var totalRaw = 0;
    for (final slot in servant.activeSkillsBySlot.keys) {
      totalRaw += maxDirectNpGainForSkillVariants(servant.activeSkillsBySlot[slot] ?? const []);
    }
    return scaleNpGainRaw(totalRaw);
  }

  static int maxDirectNpGainForSkillVariants(Iterable<BoxCoverageSourceSkill> variants) {
    var maxRaw = 0;
    for (final skill in variants) {
      maxRaw = math.max(maxRaw, maxDirectNpGainForSkill(skill));
    }
    return maxRaw;
  }

  static int maxDirectNpGainForSkill(BoxCoverageSourceSkill skill) {
    var maxRaw = 0;
    for (final function in skill.functions) {
      if (function.kind != BoxCoverageSourceFunctionKind.directNpGain) continue;
      maxRaw = math.max(maxRaw, directGainNpValueAtLevel10(function));
    }
    return maxRaw;
  }

  static int directGainNpValueAtLevel10(BoxCoverageSourceFunction function) {
    if (function.levelValues.isEmpty) return 0;
    final levelIndex = function.levelValues.length >= 10 ? 9 : function.levelValues.length - 1;
    return function.levelValues[levelIndex] ?? 0;
  }

  static int scaleNpGainRaw(int rawValue) {
    if (rawValue <= 0) return 0;
    return (rawValue / 100).round();
  }
}
