import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paats_dranklijst/data/database.dart';
import 'package:paats_dranklijst/data/logical_day.dart';
import 'package:paats_dranklijst/data/tables/transactions_table.dart';
import 'package:paats_dranklijst/screens/consumption_screen.dart';
import 'package:paats_dranklijst/screens/leaderboard_screen.dart';
import 'package:paats_dranklijst/screens/start_screen.dart';
import 'package:paats_dranklijst/screens/stats_screen.dart';
import 'package:paats_dranklijst/screens/user_detail_screen.dart';
import 'package:paats_dranklijst/widgets/count_bar_chart.dart';
import 'package:paats_dranklijst/widgets/podium.dart';
import 'package:paats_dranklijst/widgets/ranked_bar_list.dart';
import 'package:paats_dranklijst/widgets/trend_line_chart.dart';

import 'support/harness.dart';
import 'support/ledger.dart';

const int seededGroup = 1;

// By predicate: byType matches the exact runtime type, generic arguments included.
final rankedBarLists = find.byWidgetPredicate((w) => w is RankedBarList);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ItemRow cola;
  late List<int> users;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    users = [
      for (final name in ['Ann', 'Bob', 'Cas', 'Dirk', 'Eva', 'Fien'])
        await db.usersDao.createUser(
          name: name,
          groupId: seededGroup,
          avatarEmoji: '🦊',
          seedColorArgb: 0xFF009688,
        ),
    ];
    final id = await db.itemsDao.createItem(
      name: 'Cola',
      groupId: seededGroup,
      priceMinorUnits: 150,
      emoji: '🥤',
    );
    cola = await (db.select(
      db.items,
    )..where((i) => i.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  /// A portrait tablet, so every section of a long page is built.
  void tabletView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Consumptions spread over the past [days] days, in the current logical
  /// day's evening so none of them lands after now.
  Future<void> seed({
    required List<int> who,
    int days = 60,
    int every = 3,
  }) async {
    final today = logicalDayOf(DateTime.now());
    for (var day = 0; day < days; day += every) {
      for (final (index, userId) in who.indexed) {
        final at = DateTime(
          today.year,
          today.month,
          today.day - day,
          8 + index,
        );
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: userId,
                type: TransactionType.consumption,
                amountMinorUnits: -150,
                itemId: Value(cola.id),
                itemNameSnapshot: Value(cola.name),
                itemUnitPriceSnapshot: const Value(150),
                createdAt: Value(at),
                logicalDate: logicalDayKey(at),
              ),
            );
      }
    }
  }

  testWidgetsWithDatabase('the start page shows a podium from three people', (
    tester,
  ) async {
    tabletView(tester);
    for (final userId in users.take(2)) {
      await db.logConsumption(userId: userId, item: cola);
    }
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: StartScreen(onOpenUsers: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Podium), findsNothing);

    await db.logConsumption(userId: users[2], item: cola);
    await tester.pumpAndSettle();
    expect(find.byType(Podium), findsOneWidget);
  });

  testWidgetsWithDatabase('a podium place opens that user\'s page to take '
      'something', (tester) async {
    tabletView(tester);
    for (final userId in users.take(3)) {
      await db.logConsumption(userId: userId, item: cola);
    }
    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: StartScreen(onOpenUsers: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // The name, not the avatar: the whole place is the target.
    await tester.tap(
      find.descendant(of: find.byType(Podium), matching: find.text('Bob')),
    );
    await tester.pumpAndSettle();

    final screen = tester.widget<ConsumptionScreen>(
      find.byType(ConsumptionScreen),
    );
    expect(screen.users.single.name, 'Bob');
  });

  testWidgetsWithDatabase('stats loads only once its tab is active', (
    tester,
  ) async {
    tabletView(tester);
    await seed(who: users);

    Future<void> pump({required bool active}) async {
      await tester.pumpWidget(
        await settingsHarness(
          null,
          database: db,
          screen: StatsScreen(active: active),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(active: false);
    expect(find.byType(CountBarChart), findsNothing);

    await pump(active: true);
    // 120 consumptions: enough for the hour of night and the weekday as well
    // as the volume.
    expect(find.byType(CountBarChart), findsNWidgets(3));
    expect(rankedBarLists, findsOneWidget);

    for (final period in ['Year', 'All time']) {
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      expect(find.byType(CountBarChart), findsNWidgets(3));
    }
  });

  testWidgetsWithDatabase('the leaderboard needs five people per ranking', (
    tester,
  ) async {
    tabletView(tester);
    await seed(who: users.take(4).toList());

    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: const LeaderboardScreen(active: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(rankedBarLists, findsNothing);
    expect(find.text('Not enough data yet'), findsOneWidget);

    await seed(who: [users[4]], days: 1);
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    // Best day qualifies; loyalty needs 75 each in a year, not 20.
    expect(rankedBarLists, findsNWidgets(3));
    expect(find.text('MOST LOYAL'), findsNothing);
  });

  testWidgetsWithDatabase('the leaderboard ranks best days and loyalty', (
    tester,
  ) async {
    tabletView(tester);
    // 30 each in the month, over loyalty's minimum of 20.
    await seed(who: users.take(5).toList(), days: 30, every: 1);

    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: const LeaderboardScreen(active: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(rankedBarLists, findsNWidgets(4));
    expect(find.text('BEST DAY'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(5));
    // All items: each row names its favourite.
    expect(find.text('🥤'), findsNWidgets(5));
  });

  testWidgetsWithDatabase('a user page shows spend, favourites and a trend', (
    tester,
  ) async {
    tabletView(tester);
    await seed(who: [users.first]);
    final user = (await db.readUser(users.first))!;

    await tester.pumpWidget(
      await settingsHarness(
        null,
        database: db,
        screen: UserDetailScreen(user: user),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SPENT'), findsOneWidget);
    expect(rankedBarLists, findsOneWidget);
    expect(find.byType(TrendLineChart), findsOneWidget);
  });
}
