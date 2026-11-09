import 'package:flutter_test/flutter_test.dart';
import 'package:photos/widgets/index_keyed_maps.dart';

void main() {
  group('shiftIndexKeysAfter', () {
    test('moves keys after the removed index down by one', () {
      final map = {0: 'a', 2: 'c', 3: 'd'};

      shiftIndexKeysAfter(map, 1);

      expect(map, equals({0: 'a', 1: 'c', 2: 'd'}));
    });

    test('leaves keys before the removed index unchanged', () {
      final map = {0: 'a', 1: 'b'};

      shiftIndexKeysAfter(map, 5);

      expect(map, equals({0: 'a', 1: 'b'}));
    });

    test('handles an empty map', () {
      final map = <int, String>{};

      shiftIndexKeysAfter(map, 0);

      expect(map, isEmpty);
    });
  });
}
