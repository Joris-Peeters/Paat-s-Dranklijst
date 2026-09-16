import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/balance_csv.dart';

void main() {
  List<BalanceCsvRow> rowsOf(String text, {int digits = 2}) {
    final result = parseBalancesCsv(text, decimalDigits: digits);
    expect(result.errors, isEmpty);
    return result.rows;
  }

  List<BalanceCsvErrorKind> errorsOf(String text, {int digits = 2}) => [
    for (final e in parseBalancesCsv(text, decimalDigits: digits).errors)
      e.kind,
  ];

  group('encode', () {
    test('writes a header, CRLF lines and point decimals', () {
      final csv = encodeBalancesCsv([
        (name: 'Jonas', group: 'Leiding', balanceMinorUnits: -1250),
        (name: 'Wout', group: 'Leiding', balanceMinorUnits: 5),
      ], decimalDigits: 2);
      expect(
        csv,
        'name,group,balance\r\nJonas,Leiding,-12.50\r\nWout,Leiding,0.05\r\n',
      );
    });

    test('quotes delimiters, quotes, newlines and outer spaces', () {
      final csv = encodeBalancesCsv([
        (name: 'Jo, "JJ"', group: 'A;B', balanceMinorUnits: 0),
        (name: ' pad', group: 'two\nlines', balanceMinorUnits: 0),
      ], decimalDigits: 2);
      expect(
        csv,
        'name,group,balance\r\n'
        '"Jo, ""JJ""","A;B",0.00\r\n'
        '" pad","two\nlines",0.00\r\n',
      );
    });

    test('round-trips through the parser', () {
      final entries = <BalanceCsvEntry>[
        (name: 'Jo, "JJ"', group: 'Oud-leiding', balanceMinorUnits: -99999),
        (name: 'Ëlise', group: 'two\nlines', balanceMinorUnits: 1),
      ];
      final rows = rowsOf(encodeBalancesCsv(entries, decimalDigits: 2));
      expect(
        [for (final r in rows) (r.name, r.group, r.balanceMinorUnits)],
        [('Jo, "JJ"', 'Oud-leiding', -99999), ('Ëlise', 'two\nlines', 1)],
      );
      expect(rows.map((r) => r.line), [2, 3]);
    });
  });

  group('amounts', () {
    test('respect the currency digits', () {
      expect(formatCsvAmount(-1250, 0), '-1250');
      expect(formatCsvAmount(1234, 3), '1.234');
      expect(parseCsvAmount('1250', 0), 1250);
      expect(parseCsvAmount('1.5', 0), isNull);
      expect(parseCsvAmount('-1.234', 3), -1234);
      expect(parseCsvAmount('1.2', 3), 1200);
    });

    test('take either decimal mark and refuse grouping', () {
      expect(parseCsvAmount('-12,50', 2), -1250);
      expect(parseCsvAmount(' +3.5 ', 2), 350);
      expect(parseCsvAmount('1.250,00', 2), isNull);
      expect(parseCsvAmount('1,250', 2), isNull);
      expect(parseCsvAmount('€ 12', 2), isNull);
      expect(parseCsvAmount('', 2), isNull);
    });
  });

  group('parse', () {
    test('reads a semicolon file with comma decimals and a BOM', () {
      final rows = rowsOf(
        '\uFEFFname;group;balance\r\nJonas;Leiding;-12,50\r\n',
      );
      expect(rows.single.name, 'Jonas');
      expect(rows.single.balanceMinorUnits, -1250);
    });

    test('finds columns by name in any order, ignoring extras', () {
      final rows = rowsOf('Balance, Extra ,NAME,Group\n3,x,Jonas,Leiding\n');
      expect(rows.single.name, 'Jonas');
      expect(rows.single.group, 'Leiding');
      expect(rows.single.balanceMinorUnits, 300);
    });

    test('skips blank lines and numbers lines as in the file', () {
      final rows = rowsOf('name,group,balance\n\nJonas,A,1\n\nWout,A,2');
      expect(rows.map((r) => r.line), [3, 5]);
    });

    test('reports a missing column', () {
      final result = parseBalancesCsv(
        'name,balance\nJonas,1\n',
        decimalDigits: 2,
      );
      expect(result.errors.single.kind, BalanceCsvErrorKind.missingColumn);
      expect(result.errors.single.detail, 'group');
    });

    test('reports an empty file', () {
      expect(errorsOf('\n\n'), [BalanceCsvErrorKind.empty]);
    });

    test('reports each bad row with its line and keeps the good ones', () {
      final result = parseBalancesCsv(
        'name,group,balance\n'
        'Jonas,A,1.234\n'
        ',A,1\n'
        'Wout,,1\n'
        'Short,A\n'
        'Mira,A,2\n',
        decimalDigits: 2,
      );
      expect(
        [for (final e in result.errors) (e.line, e.kind)],
        [
          (2, BalanceCsvErrorKind.invalidBalance),
          (3, BalanceCsvErrorKind.emptyName),
          (4, BalanceCsvErrorKind.emptyGroup),
          (5, BalanceCsvErrorKind.missingField),
        ],
      );
      expect(result.rows.single.name, 'Mira');
    });

    test('reports an unterminated quote', () {
      expect(
        errorsOf('name,group,balance\n"Jonas,A,1\n'),
        contains(BalanceCsvErrorKind.unterminatedQuote),
      );
    });
  });

  group('compress', () {
    final csv = encodeBalancesCsv([
      for (var i = 0; i < 60; i++)
        (name: 'Ëlise $i', group: 'Leiding', balanceMinorUnits: -125 * i),
    ], decimalDigits: 2);

    test('decompresses back to the exact CSV', () {
      final compressed = compressBalancesCsv(csv);
      expect(utf8.decode(BZip2Decoder().decodeBytes(compressed)), csv);
    });

    test('is a bzip2 stream, smaller than the CSV', () {
      final compressed = compressBalancesCsv(csv);
      expect(ascii.decode(compressed.take(3).toList()), 'BZh');
      expect(compressed.length, lessThan(utf8.encode(csv).length));
    });
  });
}
