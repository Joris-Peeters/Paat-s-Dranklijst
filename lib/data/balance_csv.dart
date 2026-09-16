/// The `name,group,balance` CSV that balances are exported to and imported
/// from. Pure: no files, no database.
library;

import 'dart:math';

/// One user's line, as written.
typedef BalanceCsvEntry = ({String name, String group, int balanceMinorUnits});

/// One data row as read, with the line it started on for error messages.
class BalanceCsvRow {
  const BalanceCsvRow({
    required this.line,
    required this.name,
    required this.group,
    required this.balanceMinorUnits,
  });

  final int line;
  final String name;
  final String group;
  final int balanceMinorUnits;
}

enum BalanceCsvErrorKind {
  /// The file holds no header line.
  empty,

  /// The header lacks a required column; [BalanceCsvError.detail] names it.
  missingColumn,

  /// A quote was opened and never closed.
  unterminatedQuote,

  /// A row has too few fields to reach every required column.
  missingField,

  emptyName,
  emptyGroup,

  /// [BalanceCsvError.detail] is the text that is not an amount.
  invalidBalance,
}

class BalanceCsvError {
  const BalanceCsvError({required this.line, required this.kind, this.detail});

  final int line;
  final BalanceCsvErrorKind kind;
  final String? detail;
}

const _columns = ['name', 'group', 'balance'];

/// The CSV for [entries], with a header and CRLF line endings.
///
/// The balance is a plain decimal with a point, never a formatted amount: this
/// is read by other programs, not people.
String encodeBalancesCsv(
  List<BalanceCsvEntry> entries, {
  required int decimalDigits,
}) {
  final buffer = StringBuffer()..write('${_columns.join(',')}\r\n');
  for (final entry in entries) {
    buffer
      ..write(_quote(entry.name))
      ..write(',')
      ..write(_quote(entry.group))
      ..write(',')
      ..write(formatCsvAmount(entry.balanceMinorUnits, decimalDigits))
      ..write('\r\n');
  }
  return buffer.toString();
}

String _quote(String value) {
  final needsQuotes =
      value.contains(RegExp('[,;"\r\n]')) || value.trim() != value;
  return needsQuotes ? '"${value.replaceAll('"', '""')}"' : value;
}

/// `-1250` minor units as `-12.50`, in integer arithmetic.
String formatCsvAmount(int minorUnits, int decimalDigits) {
  final sign = minorUnits < 0 ? '-' : '';
  final magnitude = minorUnits.abs();
  if (decimalDigits == 0) return '$sign$magnitude';
  final divisor = pow(10, decimalDigits).toInt();
  final fraction = (magnitude % divisor).toString().padLeft(decimalDigits, '0');
  return '$sign${magnitude ~/ divisor}.$fraction';
}

/// Minor units from `-12.50` or `-12,50`, or null.
///
/// Either decimal mark is taken, since a semicolon file from Dutch Excel writes
/// a comma. Grouping is refused rather than guessed at, and so is a fraction
/// more precise than the currency.
int? parseCsvAmount(String text, int decimalDigits) {
  final match = RegExp(r'^([+-]?)(\d{1,12})(?:[.,](\d+))?$')
      .firstMatch(text.trim());
  if (match == null) return null;

  final fraction = match[3] ?? '';
  if (fraction.length > decimalDigits) return null;

  final scale = pow(10, decimalDigits).toInt();
  final minor =
      int.parse(match[2]!) * scale +
      (fraction.isEmpty ? 0 : int.parse(fraction.padRight(decimalDigits, '0')));
  return match[1] == '-' ? -minor : minor;
}

/// Reads a balances CSV, collecting every problem rather than stopping at the
/// first.
///
/// The delimiter is taken from the header line, so a semicolon file saved by
/// Excel in a Dutch locale reads as well as the comma files the app writes.
/// Columns are found by name, in any order; extra ones are ignored.
({List<BalanceCsvRow> rows, List<BalanceCsvError> errors}) parseBalancesCsv(
  String text, {
  required int decimalDigits,
}) {
  final rows = <BalanceCsvRow>[];
  final errors = <BalanceCsvError>[];

  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final records = _records(text, _delimiter(text), errors);

  if (records.isEmpty) {
    errors.add(const BalanceCsvError(line: 1, kind: BalanceCsvErrorKind.empty));
    return (rows: rows, errors: errors);
  }

  final header = records.first;
  final index = <String, int>{
    for (var i = 0; i < header.fields.length; i++)
      header.fields[i].trim().toLowerCase(): i,
  };
  final missing = [
    for (final column in _columns)
      if (!index.containsKey(column)) column,
  ];
  if (missing.isNotEmpty) {
    for (final column in missing) {
      errors.add(
        BalanceCsvError(
          line: header.line,
          kind: BalanceCsvErrorKind.missingColumn,
          detail: column,
        ),
      );
    }
    return (rows: rows, errors: errors);
  }

  final nameAt = index['name']!;
  final groupAt = index['group']!;
  final balanceAt = index['balance']!;
  final needed = [nameAt, groupAt, balanceAt].reduce(max) + 1;

  for (final record in records.skip(1)) {
    final line = record.line;
    final fields = record.fields;
    if (fields.length < needed) {
      errors.add(
        BalanceCsvError(line: line, kind: BalanceCsvErrorKind.missingField),
      );
      continue;
    }

    final name = fields[nameAt].trim();
    final group = fields[groupAt].trim();
    final balance = parseCsvAmount(fields[balanceAt], decimalDigits);

    if (name.isEmpty) {
      errors.add(
        BalanceCsvError(line: line, kind: BalanceCsvErrorKind.emptyName),
      );
    }
    if (group.isEmpty) {
      errors.add(
        BalanceCsvError(line: line, kind: BalanceCsvErrorKind.emptyGroup),
      );
    }
    if (balance == null) {
      errors.add(
        BalanceCsvError(
          line: line,
          kind: BalanceCsvErrorKind.invalidBalance,
          detail: fields[balanceAt].trim(),
        ),
      );
    }
    if (name.isEmpty || group.isEmpty || balance == null) continue;

    rows.add(
      BalanceCsvRow(
        line: line,
        name: name,
        group: group,
        balanceMinorUnits: balance,
      ),
    );
  }

  return (rows: rows, errors: errors);
}

/// `;` when the first line holds more of them than commas, outside quotes.
String _delimiter(String text) {
  var commas = 0;
  var semicolons = 0;
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      quoted = !quoted;
    } else if (!quoted && (char == '\n' || char == '\r')) {
      break;
    } else if (!quoted && char == ',') {
      commas++;
    } else if (!quoted && char == ';') {
      semicolons++;
    }
  }
  return semicolons > commas ? ';' : ',';
}

/// Splits [text] into records of fields, RFC 4180 style: a quoted field may
/// hold the delimiter, a newline, or a doubled quote. Blank lines are dropped.
List<({int line, List<String> fields})> _records(
  String text,
  String delimiter,
  List<BalanceCsvError> errors,
) {
  final records = <({int line, List<String> fields})>[];
  var fields = <String>[];
  final field = StringBuffer();
  var line = 1;
  var recordLine = 1;
  var quoted = false;
  var atFieldStart = true;

  void endRecord() {
    fields.add(field.toString());
    field.clear();
    final blank = fields.length == 1 && fields.first.trim().isEmpty;
    if (!blank) records.add((line: recordLine, fields: fields));
    fields = <String>[];
    atFieldStart = true;
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];

    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        if (char == '\n') line++;
        field.write(char);
      }
      continue;
    }

    if (char == '"' && atFieldStart) {
      quoted = true;
      atFieldStart = false;
    } else if (char == delimiter) {
      fields.add(field.toString());
      field.clear();
      atFieldStart = true;
    } else if (char == '\r' || char == '\n') {
      // CRLF is one line break, not two.
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRecord();
      line++;
      recordLine = line;
    } else {
      field.write(char);
      // Leading spaces before an opening quote still count as the start.
      if (char != ' ') atFieldStart = false;
    }
  }

  if (quoted) {
    errors.add(
      BalanceCsvError(
        line: recordLine,
        kind: BalanceCsvErrorKind.unterminatedQuote,
      ),
    );
  }
  if (field.isNotEmpty || fields.isNotEmpty) endRecord();
  return records;
}
