import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/utils/reorder.dart';

void main() {
  const items = ['a', 'b', 'c', 'd'];

  test('moves an item down', () {
    expect(reordered(items, 0, 2), ['b', 'c', 'a', 'd']);
  });

  test('moves an item up', () {
    expect(reordered(items, 3, 1), ['a', 'd', 'b', 'c']);
  });

  test('moving to the same slot changes nothing', () {
    expect(reordered(items, 2, 2), items);
  });

  test('moves to either end', () {
    expect(reordered(items, 3, 0), ['d', 'a', 'b', 'c']);
    expect(reordered(items, 0, 3), ['b', 'c', 'd', 'a']);
  });

  test('leaves the source list alone', () {
    final original = List.of(items);
    reordered(original, 0, 3);
    expect(original, items);
  });
}
