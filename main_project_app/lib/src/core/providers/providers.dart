// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:main_project_app/src/core/database/database.dart';
// import 'package:main_project_app/src/core/repository/call_log_repository.dart';
// import 'package:main_project_app/src/core/repository/contacts_repository.dart';

// final databaseProvider = Provider<AppDatabase>((ref) {
//   return AppDatabase();
// });

// final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
//   final db = ref.watch(databaseProvider);
//   return ContactsRepository(db);
// });

// final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
//   final db = ref.watch(databaseProvider);
//   return CallLogRepository(db);
// });
