import 'package:drift/drift.dart';

import '../tables/transactions_table.dart';

/// Per-member balance: a plain SUM over the signed amounts, voided rows
/// excluded.
///
/// A member with no live transactions has no row here, not a zero, so readers
/// left-join and treat a missing row as 0.
@DataClassName('UserBalanceRow')
abstract class UserBalances extends View {
  Transactions get transactions;

  Expression<int> get userId => transactions.userId;
  Expression<int> get balanceMinorUnits => transactions.amountMinorUnits.sum();

  // Not parenthesised: drift_dev walks this AST and rejects a
  // ParenthesizedExpression outright. The return type is spelled out because
  // `strict-raw-types` rejects the bare `Query` drift's own signature uses.
  @override
  Query<HasResultSet, dynamic> as() =>
      select([userId, balanceMinorUnits]).from(transactions)
    ..where(transactions.voidedAt.isNull())
    ..groupBy([transactions.userId]);
}
