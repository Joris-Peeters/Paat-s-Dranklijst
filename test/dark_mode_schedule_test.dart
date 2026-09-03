import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/app_settings.dart';
import 'package:paats_dranklijst/data/converters.dart';

TimeOfDay at(int hour, [int minute = 0]) =>
    TimeOfDay(hour: hour, minute: minute);

void main() {
  group('isDarkAt', () {
    group('window wrapping midnight (20:00 - 07:00)', () {
      final start = at(20);
      final end = at(7);

      bool dark(TimeOfDay now) => isDarkAt(now: now, start: start, end: end);

      test('is light in the middle of the day', () {
        expect(dark(at(12)), isFalse);
        expect(dark(at(7)), isFalse); // end is exclusive
        expect(dark(at(19, 59)), isFalse);
      });

      test('is dark in the evening, from the start minute on', () {
        expect(dark(at(20)), isTrue); // start is inclusive
        expect(dark(at(21, 30)), isTrue);
        expect(dark(at(23, 59)), isTrue);
      });

      test('is dark in the early morning, up to the end minute', () {
        expect(dark(at(0)), isTrue);
        expect(dark(at(3)), isTrue);
        expect(dark(at(6, 59)), isTrue);
      });
    });

    group('window within one day (07:00 - 20:00)', () {
      final start = at(7);
      final end = at(20);

      bool dark(TimeOfDay now) => isDarkAt(now: now, start: start, end: end);

      test('is dark inside the window', () {
        expect(dark(at(7)), isTrue);
        expect(dark(at(12)), isTrue);
        expect(dark(at(19, 59)), isTrue);
      });

      test('is light outside the window', () {
        expect(dark(at(6, 59)), isFalse);
        expect(dark(at(20)), isFalse);
        expect(dark(at(23, 59)), isFalse);
        expect(dark(at(0)), isFalse);
      });
    });

    test('a zero-length window is never dark', () {
      final noon = at(12);
      bool dark(TimeOfDay now) => isDarkAt(now: now, start: noon, end: noon);

      expect(dark(at(0)), isFalse);
      expect(dark(noon), isFalse);
      expect(dark(at(23, 59)), isFalse);
    });
  });

  group('TimeOfDayConverter', () {
    const converter = TimeOfDayConverter();

    test('stores minutes since midnight', () {
      expect(converter.toSql(at(0)), 0);
      expect(converter.toSql(at(7)), 7 * 60);
      expect(converter.toSql(at(20, 30)), 20 * 60 + 30);
      expect(converter.toSql(at(23, 59)), 24 * 60 - 1);
    });

    test('round-trips every minute of the day', () {
      for (var minutes = 0; minutes < 24 * 60; minutes++) {
        expect(converter.toSql(converter.fromSql(minutes)), minutes);
      }
    });
  });
}
