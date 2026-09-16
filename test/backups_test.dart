import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/backups.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/errors.dart';

void main() {
  late Directory temp;
  late File liveFile;
  late AppDatabase db;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('backups_test');
    liveFile = File('${temp.path}/live.sqlite');
    db = AppDatabase(executor: NativeDatabase(liveFile));
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<void> addUser(String name) => db.usersDao.createUser(
    name: name,
    groupId: 1,
    avatarEmoji: '🦊',
    seedColorArgb: 0xFF009688,
  );

  Matcher refusedFor(InvalidBackupReason reason) => throwsA(
    isA<InvalidBackupException>().having((e) => e.reason, 'reason', reason),
  );

  test('a backup is a database this app accepts', () async {
    await addUser('Jonas');
    final backup = await createBackup(
      db,
      temp,
      at: DateTime(2026, 9, 14, 15, 30, 12),
    );
    expect(backup.path, endsWith('paats_dranklijst_2026-09-14_153012.sqlite'));
    await validateBackup(db, backup);

    final listed = await listFiles(temp, backupExtensions);
    expect(
      listed.map((f) => f.name),
      contains('paats_dranklijst_2026-09-14_153012.sqlite'),
    );
  });

  test('two backups in the same second both survive', () async {
    final at = DateTime(2026, 9, 14, 15, 30, 12);
    final first = await createBackup(db, temp, at: at, suffix: 'before-reset');
    final second = await createBackup(db, temp, at: at, suffix: 'before-reset');
    expect(first.path, endsWith('_153012_before-reset.sqlite'));
    expect(second.path, endsWith('_153012_before-reset-2.sqlite'));
    expect(await first.exists(), isTrue);
    expect(await second.exists(), isTrue);
  });

  group('validation refuses', () {
    test('a text file', () async {
      final file = File('${temp.path}/notes.sqlite')
        ..writeAsStringSync('hello, this is not a database at all' * 100);
      await expectLater(
        validateBackup(db, file),
        refusedFor(InvalidBackupReason.notADatabase),
      );
      // Detached again: the next check still works.
      await validateBackup(db, await createBackup(db, temp));
    });

    test('an empty SQLite file', () async {
      final file = File('${temp.path}/empty.sqlite')..createSync();
      await expectLater(
        validateBackup(db, file),
        refusedFor(InvalidBackupReason.notThisApp),
      );
    });

    test('a newer schema', () async {
      final backup = await createBackup(db, temp);
      final other = AppDatabase(executor: NativeDatabase(backup));
      await other.customSelect('SELECT 1').get();
      await other.customStatement('PRAGMA user_version = 99');
      await other.close();

      await expectLater(
        validateBackup(db, backup),
        refusedFor(InvalidBackupReason.newerVersion),
      );
    });

    test('a missing file, without creating it', () async {
      final file = File('${temp.path}/missing.sqlite');
      await expectLater(
        validateBackup(db, file),
        refusedFor(InvalidBackupReason.notADatabase),
      );
      expect(await file.exists(), isFalse);
    });
  });

  test('installing a backup brings its data back', () async {
    await addUser('Jonas');
    final backup = await createBackup(db, temp);
    await addUser('Wout');
    await db.close();

    await installDatabaseFile(source: backup, target: liveFile);
    expect(await File('${liveFile.path}.restoring').exists(), isFalse);

    db = AppDatabase(executor: NativeDatabase(liveFile));
    final names = [for (final u in await db.select(db.users).get()) u.name];
    expect(names, ['Jonas']);
  });

  test('a CSV export carries a BOM and reads back', () async {
    final file = await writeCsvExport(temp, 'name,group,balance\r\n');
    final bytes = await file.readAsBytes();
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    // Dart's UTF-8 decoder drops the mark itself.
    expect(await readCsvText(file), 'name,group,balance\r\n');
  });

  test('a Windows-1252 CSV still reads', () async {
    final file = File('${temp.path}/excel.csv')
      ..writeAsBytesSync([0x45, 0x6C, 0xEB, 0x6E]); // "Elën" in Latin-1
    expect(await readCsvText(file), 'Elën');
  });
}
