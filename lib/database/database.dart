import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart'; // This will be generated

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get referenceNumber => text()();
  DateTimeColumn get transactionDate => dateTime()();
  RealColumn get amount => real()();
  TextColumn get terminalId => text().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  
}
@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'cborecon_db');
  }
}