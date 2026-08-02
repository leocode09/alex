import 'package:alex/services/cloud/business_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BusinessSearch.matches', () {
    test('matches exact and partial business names', () {
      expect(
        BusinessSearch.matches(
          name: 'dime shop',
          code: 'tt7u4s',
          query: 'dime shop',
        ),
        isTrue,
      );
      expect(
        BusinessSearch.matches(
          name: 'dime shop',
          code: 'tt7u4s',
          query: 'dime',
        ),
        isTrue,
      );
    });

    test('matches shop code exactly or by substring', () {
      expect(
        BusinessSearch.matches(
          name: 'dime shop',
          code: 'tt7u4s',
          query: 'tt7u4s',
        ),
        isTrue,
      );
      expect(
        BusinessSearch.matches(
          name: 'dime shop',
          code: 'tt7u4s',
          query: 'tt7',
        ),
        isTrue,
      );
    });

    test('still surfaces Dime shop for dime store typo', () {
      expect(
        BusinessSearch.matches(
          name: 'dime shop',
          code: 'tt7u4s',
          query: 'dime store',
        ),
        isTrue,
      );
    });

    test('rejects unrelated queries', () {
      expect(
        BusinessSearch.matches(
          name: 'dime shop',
          code: 'tt7u4s',
          query: 'alex',
        ),
        isFalse,
      );
    });
  });
}
