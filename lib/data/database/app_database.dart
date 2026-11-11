import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedMerchant => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get cycle => text()();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  BoolColumn get isAutoDetected =>
      boolean().withDefault(const Constant(true))();
  TextColumn get category =>
      text().withDefault(const Constant('subscription'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get sender => text()();
  TextColumn get body => text()();
  TextColumn get merchant => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get isDebit => boolean()();
  TextColumn get signal => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class IgnoredMerchants extends Table {
  TextColumn get merchant => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {merchant};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class ReviewCandidates extends Table {
  TextColumn get id => text()();
  TextColumn get merchant => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get cycle => text()();
  DateTimeColumn get nextDueDate => dateTime()();
  IntColumn get occurrences => integer()();
  TextColumn get signal => text().nullable()();
  DateTimeColumn get firstSeen => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChangeEvents extends Table {
  TextColumn get id => text()();
  TextColumn get subscriptionId => text().nullable()();
  TextColumn get merchant => text()();
  TextColumn get type => text()();
  RealColumn get beforeAmount => real().nullable()();
  RealColumn get afterAmount => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Subscriptions,
    Transactions,
    IgnoredMerchants,
    AppSettings,
    ReviewCandidates,
    ChangeEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(executor ?? driftDatabase(name: 'dues'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(subscriptions, subscriptions.category);
        await migrator.createTable(reviewCandidates);
        await migrator.createTable(changeEvents);
      }
    },
  );
}
