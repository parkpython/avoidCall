// // GENERATED CODE - DO NOT MODIFY BY HAND

// part of 'database.dart';

// // ignore_for_file: type=lint
// class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
//   @override
//   final GeneratedDatabase attachedDatabase;
//   final String? _alias;
//   $ContactsTable(this.attachedDatabase, [this._alias]);
//   static const VerificationMeta _idMeta = const VerificationMeta('id');
//   @override
//   late final GeneratedColumn<int> id = GeneratedColumn<int>(
//     'id',
//     aliasedName,
//     false,
//     hasAutoIncrement: true,
//     type: DriftSqlType.int,
//     requiredDuringInsert: false,
//     defaultConstraints: GeneratedColumn.constraintIsAlways(
//       'PRIMARY KEY AUTOINCREMENT',
//     ),
//   );
//   static const VerificationMeta _nameMeta = const VerificationMeta('name');
//   @override
//   late final GeneratedColumn<String> name = GeneratedColumn<String>(
//     'name',
//     aliasedName,
//     false,
//     type: DriftSqlType.string,
//     requiredDuringInsert: true,
//   );
//   static const VerificationMeta _phoneNumberMeta = const VerificationMeta(
//     'phoneNumber',
//   );
//   @override
//   late final GeneratedColumn<String> phoneNumber = GeneratedColumn<String>(
//     'phone_number',
//     aliasedName,
//     false,
//     type: DriftSqlType.string,
//     requiredDuringInsert: true,
//   );
//   @override
//   List<GeneratedColumn> get $columns => [id, name, phoneNumber];
//   @override
//   String get aliasedName => _alias ?? actualTableName;
//   @override
//   String get actualTableName => $name;
//   static const String $name = 'contacts';
//   @override
//   VerificationContext validateIntegrity(
//     Insertable<Contact> instance, {
//     bool isInserting = false,
//   }) {
//     final context = VerificationContext();
//     final data = instance.toColumns(true);
//     if (data.containsKey('id')) {
//       context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
//     }
//     if (data.containsKey('name')) {
//       context.handle(
//         _nameMeta,
//         name.isAcceptableOrUnknown(data['name']!, _nameMeta),
//       );
//     } else if (isInserting) {
//       context.missing(_nameMeta);
//     }
//     if (data.containsKey('phone_number')) {
//       context.handle(
//         _phoneNumberMeta,
//         phoneNumber.isAcceptableOrUnknown(
//           data['phone_number']!,
//           _phoneNumberMeta,
//         ),
//       );
//     } else if (isInserting) {
//       context.missing(_phoneNumberMeta);
//     }
//     return context;
//   }

//   @override
//   Set<GeneratedColumn> get $primaryKey => {id};
//   @override
//   Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
//     final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
//     return Contact(
//       id: attachedDatabase.typeMapping.read(
//         DriftSqlType.int,
//         data['${effectivePrefix}id'],
//       )!,
//       name: attachedDatabase.typeMapping.read(
//         DriftSqlType.string,
//         data['${effectivePrefix}name'],
//       )!,
//       phoneNumber: attachedDatabase.typeMapping.read(
//         DriftSqlType.string,
//         data['${effectivePrefix}phone_number'],
//       )!,
//     );
//   }

//   @override
//   $ContactsTable createAlias(String alias) {
//     return $ContactsTable(attachedDatabase, alias);
//   }
// }

// class Contact extends DataClass implements Insertable<Contact> {
//   final int id;
//   final String name;
//   final String phoneNumber;
//   const Contact({
//     required this.id,
//     required this.name,
//     required this.phoneNumber,
//   });
//   @override
//   Map<String, Expression> toColumns(bool nullToAbsent) {
//     final map = <String, Expression>{};
//     map['id'] = Variable<int>(id);
//     map['name'] = Variable<String>(name);
//     map['phone_number'] = Variable<String>(phoneNumber);
//     return map;
//   }

//   ContactsCompanion toCompanion(bool nullToAbsent) {
//     return ContactsCompanion(
//       id: Value(id),
//       name: Value(name),
//       phoneNumber: Value(phoneNumber),
//     );
//   }

//   factory Contact.fromJson(
//     Map<String, dynamic> json, {
//     ValueSerializer? serializer,
//   }) {
//     serializer ??= driftRuntimeOptions.defaultSerializer;
//     return Contact(
//       id: serializer.fromJson<int>(json['id']),
//       name: serializer.fromJson<String>(json['name']),
//       phoneNumber: serializer.fromJson<String>(json['phoneNumber']),
//     );
//   }
//   @override
//   Map<String, dynamic> toJson({ValueSerializer? serializer}) {
//     serializer ??= driftRuntimeOptions.defaultSerializer;
//     return <String, dynamic>{
//       'id': serializer.toJson<int>(id),
//       'name': serializer.toJson<String>(name),
//       'phoneNumber': serializer.toJson<String>(phoneNumber),
//     };
//   }

//   Contact copyWith({int? id, String? name, String? phoneNumber}) => Contact(
//     id: id ?? this.id,
//     name: name ?? this.name,
//     phoneNumber: phoneNumber ?? this.phoneNumber,
//   );
//   Contact copyWithCompanion(ContactsCompanion data) {
//     return Contact(
//       id: data.id.present ? data.id.value : this.id,
//       name: data.name.present ? data.name.value : this.name,
//       phoneNumber: data.phoneNumber.present
//           ? data.phoneNumber.value
//           : this.phoneNumber,
//     );
//   }

//   @override
//   String toString() {
//     return (StringBuffer('Contact(')
//           ..write('id: $id, ')
//           ..write('name: $name, ')
//           ..write('phoneNumber: $phoneNumber')
//           ..write(')'))
//         .toString();
//   }

//   @override
//   int get hashCode => Object.hash(id, name, phoneNumber);
//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       (other is Contact &&
//           other.id == this.id &&
//           other.name == this.name &&
//           other.phoneNumber == this.phoneNumber);
// }

// class ContactsCompanion extends UpdateCompanion<Contact> {
//   final Value<int> id;
//   final Value<String> name;
//   final Value<String> phoneNumber;
//   const ContactsCompanion({
//     this.id = const Value.absent(),
//     this.name = const Value.absent(),
//     this.phoneNumber = const Value.absent(),
//   });
//   ContactsCompanion.insert({
//     this.id = const Value.absent(),
//     required String name,
//     required String phoneNumber,
//   }) : name = Value(name),
//        phoneNumber = Value(phoneNumber);
//   static Insertable<Contact> custom({
//     Expression<int>? id,
//     Expression<String>? name,
//     Expression<String>? phoneNumber,
//   }) {
//     return RawValuesInsertable({
//       if (id != null) 'id': id,
//       if (name != null) 'name': name,
//       if (phoneNumber != null) 'phone_number': phoneNumber,
//     });
//   }

//   ContactsCompanion copyWith({
//     Value<int>? id,
//     Value<String>? name,
//     Value<String>? phoneNumber,
//   }) {
//     return ContactsCompanion(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       phoneNumber: phoneNumber ?? this.phoneNumber,
//     );
//   }

//   @override
//   Map<String, Expression> toColumns(bool nullToAbsent) {
//     final map = <String, Expression>{};
//     if (id.present) {
//       map['id'] = Variable<int>(id.value);
//     }
//     if (name.present) {
//       map['name'] = Variable<String>(name.value);
//     }
//     if (phoneNumber.present) {
//       map['phone_number'] = Variable<String>(phoneNumber.value);
//     }
//     return map;
//   }

//   @override
//   String toString() {
//     return (StringBuffer('ContactsCompanion(')
//           ..write('id: $id, ')
//           ..write('name: $name, ')
//           ..write('phoneNumber: $phoneNumber')
//           ..write(')'))
//         .toString();
//   }
// }

// class $CallLogsTable extends CallLogs with TableInfo<$CallLogsTable, CallLog> {
//   @override
//   final GeneratedDatabase attachedDatabase;
//   final String? _alias;
//   $CallLogsTable(this.attachedDatabase, [this._alias]);
//   static const VerificationMeta _idMeta = const VerificationMeta('id');
//   @override
//   late final GeneratedColumn<int> id = GeneratedColumn<int>(
//     'id',
//     aliasedName,
//     false,
//     hasAutoIncrement: true,
//     type: DriftSqlType.int,
//     requiredDuringInsert: false,
//     defaultConstraints: GeneratedColumn.constraintIsAlways(
//       'PRIMARY KEY AUTOINCREMENT',
//     ),
//   );
//   static const VerificationMeta _phoneNumberMeta = const VerificationMeta(
//     'phoneNumber',
//   );
//   @override
//   late final GeneratedColumn<String> phoneNumber = GeneratedColumn<String>(
//     'phone_number',
//     aliasedName,
//     false,
//     type: DriftSqlType.string,
//     requiredDuringInsert: true,
//   );
//   static const VerificationMeta _callTimeMeta = const VerificationMeta(
//     'callTime',
//   );
//   @override
//   late final GeneratedColumn<DateTime> callTime = GeneratedColumn<DateTime>(
//     'call_time',
//     aliasedName,
//     false,
//     type: DriftSqlType.dateTime,
//     requiredDuringInsert: true,
//   );
//   @override
//   List<GeneratedColumn> get $columns => [id, phoneNumber, callTime];
//   @override
//   String get aliasedName => _alias ?? actualTableName;
//   @override
//   String get actualTableName => $name;
//   static const String $name = 'call_logs';
//   @override
//   VerificationContext validateIntegrity(
//     Insertable<CallLog> instance, {
//     bool isInserting = false,
//   }) {
//     final context = VerificationContext();
//     final data = instance.toColumns(true);
//     if (data.containsKey('id')) {
//       context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
//     }
//     if (data.containsKey('phone_number')) {
//       context.handle(
//         _phoneNumberMeta,
//         phoneNumber.isAcceptableOrUnknown(
//           data['phone_number']!,
//           _phoneNumberMeta,
//         ),
//       );
//     } else if (isInserting) {
//       context.missing(_phoneNumberMeta);
//     }
//     if (data.containsKey('call_time')) {
//       context.handle(
//         _callTimeMeta,
//         callTime.isAcceptableOrUnknown(data['call_time']!, _callTimeMeta),
//       );
//     } else if (isInserting) {
//       context.missing(_callTimeMeta);
//     }
//     return context;
//   }

//   @override
//   Set<GeneratedColumn> get $primaryKey => {id};
//   @override
//   CallLog map(Map<String, dynamic> data, {String? tablePrefix}) {
//     final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
//     return CallLog(
//       id: attachedDatabase.typeMapping.read(
//         DriftSqlType.int,
//         data['${effectivePrefix}id'],
//       )!,
//       phoneNumber: attachedDatabase.typeMapping.read(
//         DriftSqlType.string,
//         data['${effectivePrefix}phone_number'],
//       )!,
//       callTime: attachedDatabase.typeMapping.read(
//         DriftSqlType.dateTime,
//         data['${effectivePrefix}call_time'],
//       )!,
//     );
//   }

//   @override
//   $CallLogsTable createAlias(String alias) {
//     return $CallLogsTable(attachedDatabase, alias);
//   }
// }

// class CallLog extends DataClass implements Insertable<CallLog> {
//   final int id;
//   final String phoneNumber;
//   final DateTime callTime;
//   const CallLog({
//     required this.id,
//     required this.phoneNumber,
//     required this.callTime,
//   });
//   @override
//   Map<String, Expression> toColumns(bool nullToAbsent) {
//     final map = <String, Expression>{};
//     map['id'] = Variable<int>(id);
//     map['phone_number'] = Variable<String>(phoneNumber);
//     map['call_time'] = Variable<DateTime>(callTime);
//     return map;
//   }

//   CallLogsCompanion toCompanion(bool nullToAbsent) {
//     return CallLogsCompanion(
//       id: Value(id),
//       phoneNumber: Value(phoneNumber),
//       callTime: Value(callTime),
//     );
//   }

//   factory CallLog.fromJson(
//     Map<String, dynamic> json, {
//     ValueSerializer? serializer,
//   }) {
//     serializer ??= driftRuntimeOptions.defaultSerializer;
//     return CallLog(
//       id: serializer.fromJson<int>(json['id']),
//       phoneNumber: serializer.fromJson<String>(json['phoneNumber']),
//       callTime: serializer.fromJson<DateTime>(json['callTime']),
//     );
//   }
//   @override
//   Map<String, dynamic> toJson({ValueSerializer? serializer}) {
//     serializer ??= driftRuntimeOptions.defaultSerializer;
//     return <String, dynamic>{
//       'id': serializer.toJson<int>(id),
//       'phoneNumber': serializer.toJson<String>(phoneNumber),
//       'callTime': serializer.toJson<DateTime>(callTime),
//     };
//   }

//   CallLog copyWith({int? id, String? phoneNumber, DateTime? callTime}) =>
//       CallLog(
//         id: id ?? this.id,
//         phoneNumber: phoneNumber ?? this.phoneNumber,
//         callTime: callTime ?? this.callTime,
//       );
//   CallLog copyWithCompanion(CallLogsCompanion data) {
//     return CallLog(
//       id: data.id.present ? data.id.value : this.id,
//       phoneNumber: data.phoneNumber.present
//           ? data.phoneNumber.value
//           : this.phoneNumber,
//       callTime: data.callTime.present ? data.callTime.value : this.callTime,
//     );
//   }

//   @override
//   String toString() {
//     return (StringBuffer('CallLog(')
//           ..write('id: $id, ')
//           ..write('phoneNumber: $phoneNumber, ')
//           ..write('callTime: $callTime')
//           ..write(')'))
//         .toString();
//   }

//   @override
//   int get hashCode => Object.hash(id, phoneNumber, callTime);
//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       (other is CallLog &&
//           other.id == this.id &&
//           other.phoneNumber == this.phoneNumber &&
//           other.callTime == this.callTime);
// }

// class CallLogsCompanion extends UpdateCompanion<CallLog> {
//   final Value<int> id;
//   final Value<String> phoneNumber;
//   final Value<DateTime> callTime;
//   const CallLogsCompanion({
//     this.id = const Value.absent(),
//     this.phoneNumber = const Value.absent(),
//     this.callTime = const Value.absent(),
//   });
//   CallLogsCompanion.insert({
//     this.id = const Value.absent(),
//     required String phoneNumber,
//     required DateTime callTime,
//   }) : phoneNumber = Value(phoneNumber),
//        callTime = Value(callTime);
//   static Insertable<CallLog> custom({
//     Expression<int>? id,
//     Expression<String>? phoneNumber,
//     Expression<DateTime>? callTime,
//   }) {
//     return RawValuesInsertable({
//       if (id != null) 'id': id,
//       if (phoneNumber != null) 'phone_number': phoneNumber,
//       if (callTime != null) 'call_time': callTime,
//     });
//   }

//   CallLogsCompanion copyWith({
//     Value<int>? id,
//     Value<String>? phoneNumber,
//     Value<DateTime>? callTime,
//   }) {
//     return CallLogsCompanion(
//       id: id ?? this.id,
//       phoneNumber: phoneNumber ?? this.phoneNumber,
//       callTime: callTime ?? this.callTime,
//     );
//   }

//   @override
//   Map<String, Expression> toColumns(bool nullToAbsent) {
//     final map = <String, Expression>{};
//     if (id.present) {
//       map['id'] = Variable<int>(id.value);
//     }
//     if (phoneNumber.present) {
//       map['phone_number'] = Variable<String>(phoneNumber.value);
//     }
//     if (callTime.present) {
//       map['call_time'] = Variable<DateTime>(callTime.value);
//     }
//     return map;
//   }

//   @override
//   String toString() {
//     return (StringBuffer('CallLogsCompanion(')
//           ..write('id: $id, ')
//           ..write('phoneNumber: $phoneNumber, ')
//           ..write('callTime: $callTime')
//           ..write(')'))
//         .toString();
//   }
// }

// abstract class _$AppDatabase extends GeneratedDatabase {
//   _$AppDatabase(QueryExecutor e) : super(e);
//   $AppDatabaseManager get managers => $AppDatabaseManager(this);
//   late final $ContactsTable contacts = $ContactsTable(this);
//   late final $CallLogsTable callLogs = $CallLogsTable(this);
//   @override
//   Iterable<TableInfo<Table, Object?>> get allTables =>
//       allSchemaEntities.whereType<TableInfo<Table, Object?>>();
//   @override
//   List<DatabaseSchemaEntity> get allSchemaEntities => [contacts, callLogs];
// }

// typedef $$ContactsTableCreateCompanionBuilder =
//     ContactsCompanion Function({
//       Value<int> id,
//       required String name,
//       required String phoneNumber,
//     });
// typedef $$ContactsTableUpdateCompanionBuilder =
//     ContactsCompanion Function({
//       Value<int> id,
//       Value<String> name,
//       Value<String> phoneNumber,
//     });

// class $$ContactsTableFilterComposer
//     extends Composer<_$AppDatabase, $ContactsTable> {
//   $$ContactsTableFilterComposer({
//     required super.$db,
//     required super.$table,
//     super.joinBuilder,
//     super.$addJoinBuilderToRootComposer,
//     super.$removeJoinBuilderFromRootComposer,
//   });
//   ColumnFilters<int> get id => $composableBuilder(
//     column: $table.id,
//     builder: (column) => ColumnFilters(column),
//   );

//   ColumnFilters<String> get name => $composableBuilder(
//     column: $table.name,
//     builder: (column) => ColumnFilters(column),
//   );

//   ColumnFilters<String> get phoneNumber => $composableBuilder(
//     column: $table.phoneNumber,
//     builder: (column) => ColumnFilters(column),
//   );
// }

// class $$ContactsTableOrderingComposer
//     extends Composer<_$AppDatabase, $ContactsTable> {
//   $$ContactsTableOrderingComposer({
//     required super.$db,
//     required super.$table,
//     super.joinBuilder,
//     super.$addJoinBuilderToRootComposer,
//     super.$removeJoinBuilderFromRootComposer,
//   });
//   ColumnOrderings<int> get id => $composableBuilder(
//     column: $table.id,
//     builder: (column) => ColumnOrderings(column),
//   );

//   ColumnOrderings<String> get name => $composableBuilder(
//     column: $table.name,
//     builder: (column) => ColumnOrderings(column),
//   );

//   ColumnOrderings<String> get phoneNumber => $composableBuilder(
//     column: $table.phoneNumber,
//     builder: (column) => ColumnOrderings(column),
//   );
// }

// class $$ContactsTableAnnotationComposer
//     extends Composer<_$AppDatabase, $ContactsTable> {
//   $$ContactsTableAnnotationComposer({
//     required super.$db,
//     required super.$table,
//     super.joinBuilder,
//     super.$addJoinBuilderToRootComposer,
//     super.$removeJoinBuilderFromRootComposer,
//   });
//   GeneratedColumn<int> get id =>
//       $composableBuilder(column: $table.id, builder: (column) => column);

//   GeneratedColumn<String> get name =>
//       $composableBuilder(column: $table.name, builder: (column) => column);

//   GeneratedColumn<String> get phoneNumber => $composableBuilder(
//     column: $table.phoneNumber,
//     builder: (column) => column,
//   );
// }

// class $$ContactsTableTableManager
//     extends
//         RootTableManager<
//           _$AppDatabase,
//           $ContactsTable,
//           Contact,
//           $$ContactsTableFilterComposer,
//           $$ContactsTableOrderingComposer,
//           $$ContactsTableAnnotationComposer,
//           $$ContactsTableCreateCompanionBuilder,
//           $$ContactsTableUpdateCompanionBuilder,
//           (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
//           Contact,
//           PrefetchHooks Function()
//         > {
//   $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
//     : super(
//         TableManagerState(
//           db: db,
//           table: table,
//           createFilteringComposer: () =>
//               $$ContactsTableFilterComposer($db: db, $table: table),
//           createOrderingComposer: () =>
//               $$ContactsTableOrderingComposer($db: db, $table: table),
//           createComputedFieldComposer: () =>
//               $$ContactsTableAnnotationComposer($db: db, $table: table),
//           updateCompanionCallback:
//               ({
//                 Value<int> id = const Value.absent(),
//                 Value<String> name = const Value.absent(),
//                 Value<String> phoneNumber = const Value.absent(),
//               }) => ContactsCompanion(
//                 id: id,
//                 name: name,
//                 phoneNumber: phoneNumber,
//               ),
//           createCompanionCallback:
//               ({
//                 Value<int> id = const Value.absent(),
//                 required String name,
//                 required String phoneNumber,
//               }) => ContactsCompanion.insert(
//                 id: id,
//                 name: name,
//                 phoneNumber: phoneNumber,
//               ),
//           withReferenceMapper: (p0) => p0
//               .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
//               .toList(),
//           prefetchHooksCallback: null,
//         ),
//       );
// }

// typedef $$ContactsTableProcessedTableManager =
//     ProcessedTableManager<
//       _$AppDatabase,
//       $ContactsTable,
//       Contact,
//       $$ContactsTableFilterComposer,
//       $$ContactsTableOrderingComposer,
//       $$ContactsTableAnnotationComposer,
//       $$ContactsTableCreateCompanionBuilder,
//       $$ContactsTableUpdateCompanionBuilder,
//       (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
//       Contact,
//       PrefetchHooks Function()
//     >;
// typedef $$CallLogsTableCreateCompanionBuilder =
//     CallLogsCompanion Function({
//       Value<int> id,
//       required String phoneNumber,
//       required DateTime callTime,
//     });
// typedef $$CallLogsTableUpdateCompanionBuilder =
//     CallLogsCompanion Function({
//       Value<int> id,
//       Value<String> phoneNumber,
//       Value<DateTime> callTime,
//     });

// class $$CallLogsTableFilterComposer
//     extends Composer<_$AppDatabase, $CallLogsTable> {
//   $$CallLogsTableFilterComposer({
//     required super.$db,
//     required super.$table,
//     super.joinBuilder,
//     super.$addJoinBuilderToRootComposer,
//     super.$removeJoinBuilderFromRootComposer,
//   });
//   ColumnFilters<int> get id => $composableBuilder(
//     column: $table.id,
//     builder: (column) => ColumnFilters(column),
//   );

//   ColumnFilters<String> get phoneNumber => $composableBuilder(
//     column: $table.phoneNumber,
//     builder: (column) => ColumnFilters(column),
//   );

//   ColumnFilters<DateTime> get callTime => $composableBuilder(
//     column: $table.callTime,
//     builder: (column) => ColumnFilters(column),
//   );
// }

// class $$CallLogsTableOrderingComposer
//     extends Composer<_$AppDatabase, $CallLogsTable> {
//   $$CallLogsTableOrderingComposer({
//     required super.$db,
//     required super.$table,
//     super.joinBuilder,
//     super.$addJoinBuilderToRootComposer,
//     super.$removeJoinBuilderFromRootComposer,
//   });
//   ColumnOrderings<int> get id => $composableBuilder(
//     column: $table.id,
//     builder: (column) => ColumnOrderings(column),
//   );

//   ColumnOrderings<String> get phoneNumber => $composableBuilder(
//     column: $table.phoneNumber,
//     builder: (column) => ColumnOrderings(column),
//   );

//   ColumnOrderings<DateTime> get callTime => $composableBuilder(
//     column: $table.callTime,
//     builder: (column) => ColumnOrderings(column),
//   );
// }

// class $$CallLogsTableAnnotationComposer
//     extends Composer<_$AppDatabase, $CallLogsTable> {
//   $$CallLogsTableAnnotationComposer({
//     required super.$db,
//     required super.$table,
//     super.joinBuilder,
//     super.$addJoinBuilderToRootComposer,
//     super.$removeJoinBuilderFromRootComposer,
//   });
//   GeneratedColumn<int> get id =>
//       $composableBuilder(column: $table.id, builder: (column) => column);

//   GeneratedColumn<String> get phoneNumber => $composableBuilder(
//     column: $table.phoneNumber,
//     builder: (column) => column,
//   );

//   GeneratedColumn<DateTime> get callTime =>
//       $composableBuilder(column: $table.callTime, builder: (column) => column);
// }

// class $$CallLogsTableTableManager
//     extends
//         RootTableManager<
//           _$AppDatabase,
//           $CallLogsTable,
//           CallLog,
//           $$CallLogsTableFilterComposer,
//           $$CallLogsTableOrderingComposer,
//           $$CallLogsTableAnnotationComposer,
//           $$CallLogsTableCreateCompanionBuilder,
//           $$CallLogsTableUpdateCompanionBuilder,
//           (CallLog, BaseReferences<_$AppDatabase, $CallLogsTable, CallLog>),
//           CallLog,
//           PrefetchHooks Function()
//         > {
//   $$CallLogsTableTableManager(_$AppDatabase db, $CallLogsTable table)
//     : super(
//         TableManagerState(
//           db: db,
//           table: table,
//           createFilteringComposer: () =>
//               $$CallLogsTableFilterComposer($db: db, $table: table),
//           createOrderingComposer: () =>
//               $$CallLogsTableOrderingComposer($db: db, $table: table),
//           createComputedFieldComposer: () =>
//               $$CallLogsTableAnnotationComposer($db: db, $table: table),
//           updateCompanionCallback:
//               ({
//                 Value<int> id = const Value.absent(),
//                 Value<String> phoneNumber = const Value.absent(),
//                 Value<DateTime> callTime = const Value.absent(),
//               }) => CallLogsCompanion(
//                 id: id,
//                 phoneNumber: phoneNumber,
//                 callTime: callTime,
//               ),
//           createCompanionCallback:
//               ({
//                 Value<int> id = const Value.absent(),
//                 required String phoneNumber,
//                 required DateTime callTime,
//               }) => CallLogsCompanion.insert(
//                 id: id,
//                 phoneNumber: phoneNumber,
//                 callTime: callTime,
//               ),
//           withReferenceMapper: (p0) => p0
//               .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
//               .toList(),
//           prefetchHooksCallback: null,
//         ),
//       );
// }

// typedef $$CallLogsTableProcessedTableManager =
//     ProcessedTableManager<
//       _$AppDatabase,
//       $CallLogsTable,
//       CallLog,
//       $$CallLogsTableFilterComposer,
//       $$CallLogsTableOrderingComposer,
//       $$CallLogsTableAnnotationComposer,
//       $$CallLogsTableCreateCompanionBuilder,
//       $$CallLogsTableUpdateCompanionBuilder,
//       (CallLog, BaseReferences<_$AppDatabase, $CallLogsTable, CallLog>),
//       CallLog,
//       PrefetchHooks Function()
//     >;

// class $AppDatabaseManager {
//   final _$AppDatabase _db;
//   $AppDatabaseManager(this._db);
//   $$ContactsTableTableManager get contacts =>
//       $$ContactsTableTableManager(_db, _db.contacts);
//   $$CallLogsTableTableManager get callLogs =>
//       $$CallLogsTableTableManager(_db, _db.callLogs);
// }
