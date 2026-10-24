import 'package:flutter_test/flutter_test.dart';
import 'package:ration_safe/crypto/canonical_json.dart';

void main() {
  test('sorts object keys and strips whitespace', () {
    const input = {
      'zeta': 1,
      'alpha': {'d': true, 'c': false},
    };

    expect(canonicalJson(input), '{"alpha":{"c":false,"d":true},"zeta":1}');
  });

  test('keeps list order and encodes nested maps', () {
    const input = {
      'items': [
        {'b': 2, 'a': 1},
        {'z': 9, 'm': 5},
      ],
    };

    expect(
      canonicalJson(input),
      '{"items":[{"a":1,"b":2},{"m":5,"z":9}]}',
    );
  });
}
