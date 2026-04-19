import 'package:chaldea/models/gamedata/common.dart';

enum BoxCoverageNpTarget {
  single,
  aoe,
  support,
  unknown;

  String get label => switch (this) {
    single => 'Single',
    aoe => 'AoE',
    support => 'Support',
    unknown => 'Unknown',
  };
}

enum BoxCoverageTableKind { targetCoverage, classCapability, multiplier }

class BoxCoverageRequest {
  final bool includeFourStar;
  final bool includeFiveStar;
  final bool includeSingleTarget;
  final bool includeAoe;

  const BoxCoverageRequest({
    this.includeFourStar = true,
    this.includeFiveStar = true,
    this.includeSingleTarget = true,
    this.includeAoe = true,
  });

  const BoxCoverageRequest.defaults()
    : includeFourStar = true,
      includeFiveStar = true,
      includeSingleTarget = true,
      includeAoe = true;

  List<int> get allowedRarities => [if (includeFourStar) 4, if (includeFiveStar) 5];

  List<BoxCoverageNpTarget> get allowedTargets => [
    if (includeAoe) BoxCoverageNpTarget.aoe,
    if (includeSingleTarget) BoxCoverageNpTarget.single,
  ];
}

class BoxCoverageServantSnapshot {
  final int collectionNo;
  final int servantId;
  final String name;
  final int classId;
  final int rarity;
  final bool owned;
  final int npLevel;
  final int grailCount;
  final int totalNpGain;
  final BoxCoverageNpTarget npTarget;
  final CardType npCard;
  final String? faceIcon;
  final String? classIcon;

  const BoxCoverageServantSnapshot({
    required this.collectionNo,
    required this.servantId,
    required this.name,
    required this.classId,
    required this.rarity,
    required this.owned,
    required this.npLevel,
    required this.grailCount,
    required this.totalNpGain,
    required this.npTarget,
    required this.npCard,
    required this.faceIcon,
    required this.classIcon,
  });
}

class BoxCoverageContributor {
  final int collectionNo;
  final int servantId;
  final String name;
  final int classId;
  final int rarity;
  final int npLevel;
  final int totalNpGain;
  final BoxCoverageNpTarget npTarget;
  final CardType npCard;
  final double? multiplier;
  final String? faceIcon;
  final String? classIcon;

  const BoxCoverageContributor({
    required this.collectionNo,
    required this.servantId,
    required this.name,
    required this.classId,
    required this.rarity,
    required this.npLevel,
    required this.totalNpGain,
    required this.npTarget,
    required this.npCard,
    required this.multiplier,
    required this.faceIcon,
    required this.classIcon,
  });

  factory BoxCoverageContributor.fromSnapshot(BoxCoverageServantSnapshot snapshot, {double? multiplier}) {
    return BoxCoverageContributor(
      collectionNo: snapshot.collectionNo,
      servantId: snapshot.servantId,
      name: snapshot.name,
      classId: snapshot.classId,
      rarity: snapshot.rarity,
      npLevel: snapshot.npLevel,
      totalNpGain: snapshot.totalNpGain,
      npTarget: snapshot.npTarget,
      npCard: snapshot.npCard,
      multiplier: multiplier,
      faceIcon: snapshot.faceIcon,
      classIcon: snapshot.classIcon,
    );
  }
}

class BoxCoverageCellModel {
  final String id;
  final int count;
  final int maxNpGain;
  final double? bestMultiplier;
  final List<BoxCoverageContributor> contributors;

  const BoxCoverageCellModel({
    required this.id,
    required this.count,
    required this.maxNpGain,
    required this.bestMultiplier,
    required this.contributors,
  });

  const BoxCoverageCellModel.empty(this.id) : count = 0, maxNpGain = 0, bestMultiplier = null, contributors = const [];

  bool get hasData => contributors.isNotEmpty;
}

class BoxCoverageColumn {
  final String id;
  final String label;
  final int? rarity;
  final BoxCoverageNpTarget? npTarget;
  final CardType? npCard;

  const BoxCoverageColumn({
    required this.id,
    required this.label,
    required this.rarity,
    required this.npTarget,
    required this.npCard,
  });
}

class BoxCoverageColumnGroup {
  final String label;
  final List<BoxCoverageColumn> columns;

  const BoxCoverageColumnGroup({required this.label, required this.columns});
}

class BoxCoverageRowModel {
  final String id;
  final String label;
  final int classId;
  final String? classIcon;
  final List<BoxCoverageCellModel> cells;

  const BoxCoverageRowModel({
    required this.id,
    required this.label,
    required this.classId,
    required this.classIcon,
    required this.cells,
  });
}

class BoxCoverageTableModel {
  final BoxCoverageTableKind kind;
  final String title;
  final List<BoxCoverageColumnGroup> columnGroups;
  final List<BoxCoverageRowModel> rows;

  const BoxCoverageTableModel({
    required this.kind,
    required this.title,
    required this.columnGroups,
    required this.rows,
  });

  List<BoxCoverageColumn> get columns => columnGroups.expand((group) => group.columns).toList(growable: false);
}

class BoxCoveragePageModel {
  final DateTime generatedAt;
  final int ownedServantCount;
  final List<BoxCoverageServantSnapshot> servants;
  final BoxCoverageTableModel targetCoverageTable;
  final BoxCoverageTableModel classCapabilityTable;
  final BoxCoverageTableModel multiplierTable;

  const BoxCoveragePageModel({
    required this.generatedAt,
    required this.ownedServantCount,
    required this.servants,
    required this.targetCoverageTable,
    required this.classCapabilityTable,
    required this.multiplierTable,
  });
}
