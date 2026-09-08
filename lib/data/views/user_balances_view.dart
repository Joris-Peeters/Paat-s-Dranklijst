import 'package:drift/drift.dart';

import '../tables/transactions_table.dart';

/// Per-member balance: the type-agnostic SUM from rule 1, voided rows excluded.
///
/// Deliberately narrow — just the id and the balance — so it stays valid when
/// `users` grows a column, and the DAO decides what to join alongside it.
///
/// A member with no live transactions has **no row here**, not a zero, so
/// readers left-join and treat a missing row as 0.
@DataClassName('UserBalanceRow')
abstract class UserBalances extends View {
  Transactions get transactions;

  Expression<int> get userId => transactions.userId;
  Expression<int> get balanceMinorUnits => transactions.amountMinorUnits.sum();

  // Do not wrap this body in parentheses: drift_dev walks the `as()` AST and
  // rejects a ParenthesizedExpression outright. Cascades are fine.
  // The return type is spelled out only because `strict-raw-types` rejects a
  // bare `Query`; drift's own signature is the raw one.
  @override
  Query<HasResultSet, dynamic> as() =>
      select([userId, balanceMinorUnits]).from(transactions)
    ..where(transactions.voidedAt.isNull())
    ..groupBy([transactions.userId]);
}
