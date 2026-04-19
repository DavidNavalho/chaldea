import 'package:flutter_test/flutter_test.dart';

import 'package:chaldea/app/battle/utils/buff_utils.dart';
import 'package:chaldea/models/gamedata/const_data.dart';
import 'package:chaldea/models/gamedata/individuality.dart';

void main() {
  group('Test capBuffValue', () {
    const maxRate = 5000;
    final actionDetail = BuffActionInfo(
      limit: BuffLimit.normal,
      plusTypes: [],
      minusTypes: [],
      baseParam: 1500,
      baseValue: 25,
      isRec: false,
      plusAction: BuffAction.none,
      maxRate: [maxRate],
    );

    test('value default to base param - base value', () {
      expect(capBuffValue(actionDetail, 0, maxRate), actionDetail.baseParam - actionDetail.baseValue);
    });

    test('value bound on normal', () {
      actionDetail.limit = BuffLimit.normal;
      expect(capBuffValue(actionDetail, -100000, maxRate), -actionDetail.baseValue);
      expect(capBuffValue(actionDetail, 100000, maxRate), maxRate);
    });

    test('value bound on limit', () {
      actionDetail.limit = BuffLimit.lower;
      expect(capBuffValue(actionDetail, -100000, maxRate), -actionDetail.baseValue);
      expect(capBuffValue(actionDetail, 100000, maxRate), 100000 + actionDetail.baseParam - actionDetail.baseValue);
    });

    test('value bound on upper', () {
      actionDetail.limit = BuffLimit.upper;
      expect(capBuffValue(actionDetail, -100000, maxRate), -100000 + actionDetail.baseParam - actionDetail.baseValue);
      expect(capBuffValue(actionDetail, 100000, maxRate), maxRate);
      expect(capBuffValue(actionDetail, 100000, null), 100000 + actionDetail.baseParam - actionDetail.baseValue);
    });

    test('value bound on none', () {
      actionDetail.limit = BuffLimit.none;
      expect(capBuffValue(actionDetail, -100000, maxRate), -100000 + actionDetail.baseParam - actionDetail.baseValue);
      expect(capBuffValue(actionDetail, 100000, maxRate), 100000 + actionDetail.baseParam - actionDetail.baseValue);
    });
  });

  group('checkSignedIndividualities2', () {
    test('partialMatch null or empty', () {
      final requiredTraits = [300, 100, -200, -400];

      final myTraits1 = null;
      final result1 = Individuality.checkSignedIndivPartialMatch(self: myTraits1, signedTarget: requiredTraits);
      expect(result1, true);

      final myTraits2 = <int>[];
      final result2 = Individuality.checkSignedIndivPartialMatch(self: myTraits2, signedTarget: requiredTraits);
      expect(result2, false);
    });

    test('partialMatch positive only', () {
      final requiredTraits = [300, 100];

      final myTraits1 = [300, 100];
      final result1 = Individuality.checkSignedIndivPartialMatch(self: myTraits1, signedTarget: requiredTraits);
      expect(result1, true);

      final myTraits2 = [100, 200];
      final result2 = Individuality.checkSignedIndivPartialMatch(self: myTraits2, signedTarget: requiredTraits);
      expect(result2, true);

      final myTraits3 = [300, 200];
      final result3 = Individuality.checkSignedIndivPartialMatch(self: myTraits3, signedTarget: requiredTraits);
      expect(result3, true);

      final myTraits4 = [400, 200];
      final result4 = Individuality.checkSignedIndivPartialMatch(self: myTraits4, signedTarget: requiredTraits);
      expect(result4, false);
    });

    test('partialMatch mix', () {
      // OR on positive, AND on negative
      final requiredTraits = [300, 100, -200, -400];

      final myTraits1 = [300, 100];
      final result1 = Individuality.checkSignedIndivPartialMatch(self: myTraits1, signedTarget: requiredTraits);
      expect(result1, true);

      final myTraits2 = [100, 200];
      final result2 = Individuality.checkSignedIndivPartialMatch(self: myTraits2, signedTarget: requiredTraits);
      expect(result2, false);

      final myTraits3 = [300, 400];
      final result3 = Individuality.checkSignedIndivPartialMatch(self: myTraits3, signedTarget: requiredTraits);
      expect(result3, false);

      final myTraits4 = [500, 600];
      final result4 = Individuality.checkSignedIndivPartialMatch(self: myTraits4, signedTarget: requiredTraits);
      expect(result4, false);
    });

    test('allMatch null or empty', () {
      final requiredTraits = [300, 100, -200, -400];

      final myTraits1 = null;
      final result1 = Individuality.checkSignedIndivAllMatch(self: myTraits1, signedTarget: requiredTraits);
      expect(result1, true);

      final myTraits2 = <int>[];
      final result2 = Individuality.checkSignedIndivAllMatch(self: myTraits2, signedTarget: requiredTraits);
      expect(result2, false);
    });

    test('allMatch positive only', () {
      final requiredTraits = [300, 100];

      final myTraits1 = [300, 100, 200];
      final result1 = Individuality.checkSignedIndivAllMatch(self: myTraits1, signedTarget: requiredTraits);
      expect(result1, true);

      final myTraits2 = [100, 200];
      final result2 = Individuality.checkSignedIndivAllMatch(self: myTraits2, signedTarget: requiredTraits);
      expect(result2, false);

      final myTraits3 = [300, 200];
      final result3 = Individuality.checkSignedIndivAllMatch(self: myTraits3, signedTarget: requiredTraits);
      expect(result3, false);

      final myTraits4 = [400, 200];
      final result4 = Individuality.checkSignedIndivAllMatch(self: myTraits4, signedTarget: requiredTraits);
      expect(result4, false);
    });

    test('allMatch mix', () {
      // AND on positive, OR on negative
      final requiredTraits = [300, 100, -200, -400];

      final myTraits1 = [300, 100, 600];
      final result1 = Individuality.checkSignedIndivAllMatch(self: myTraits1, signedTarget: requiredTraits);
      expect(result1, true);

      final myTraits2 = [100, 200];
      final result2 = Individuality.checkSignedIndivAllMatch(self: myTraits2, signedTarget: requiredTraits);
      expect(result2, false);

      final myTraits3 = [100, 300, 400];
      final result3 = Individuality.checkSignedIndivAllMatch(self: myTraits3, signedTarget: requiredTraits);
      expect(result3, true);

      final myTraits4 = [500, 600];
      final result4 = Individuality.checkSignedIndivAllMatch(self: myTraits4, signedTarget: requiredTraits);
      expect(result4, false);
    });
  });

  group('checkSignedIndividualitiesPartialMatch', () {
    test('partialMatch', () {
      // OR on positive, OR on negative
      final requiredTraits = [300, 100, -200, -400];

      final myTraits1 = [300, 100, 600];
      final result1 = Individuality.checkSignedIndividualitiesPartialMatch(
        selfs: myTraits1,
        signedTargets: requiredTraits,
        matchedFunc: Individuality.isPartialMatchArray,
        mismatchFunc: Individuality.isPartialMatchArray,
      );
      expect(result1, true);

      final myTraits2 = [100, 200];
      final result2 = Individuality.checkSignedIndividualitiesPartialMatch(
        selfs: myTraits2,
        signedTargets: requiredTraits,
        matchedFunc: Individuality.isPartialMatchArray,
        mismatchFunc: Individuality.isPartialMatchArray,
      );
      expect(result2, true);

      final myTraits3 = [200, 400];
      final result3 = Individuality.checkSignedIndividualitiesPartialMatch(
        selfs: myTraits3,
        signedTargets: requiredTraits,
        matchedFunc: Individuality.isPartialMatchArray,
        mismatchFunc: Individuality.isPartialMatchArray,
      );
      expect(result3, false);

      final myTraits4 = [500, 600];
      final result4 = Individuality.checkSignedIndividualitiesPartialMatch(
        selfs: myTraits4,
        signedTargets: requiredTraits,
        matchedFunc: Individuality.isPartialMatchArray,
        mismatchFunc: Individuality.isPartialMatchArray,
      );
      expect(result4, true);
    });
  });
}
