// import 'dart:io';

// import 'package:drift/drift.dart';
// import 'package:drift/native.dart';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';

// part 'database.g.dart';

// class Contacts extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   TextColumn get name => text()();
//   TextColumn get phoneNumber => text()();
// }

// class CallLogs extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   TextColumn get phoneNumber => text()();
//   DateTimeColumn get callTime => dateTime()();
// }

// @DriftDatabase(tables: [Contacts, CallLogs])
// class AppDatabase extends _$AppDatabase {
//   AppDatabase() : super(_openConnection());

//   @override
//   int get schemaVersion => 1;
// }

// LazyDatabase _openConnection() {
//   return LazyDatabase(() async {
//     final dbFolder = await getApplicationDocumentsDirectory();
//     final file = File(p.join(dbFolder.path, 'db.sqlite'));
//     return NativeDatabase(file);
//   });
// }
