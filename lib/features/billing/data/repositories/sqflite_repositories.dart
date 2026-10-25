import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/features/billing/data/repositories/bill_repository.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/settings/domain/shop_settings.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'simple_billing.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bill_number INTEGER NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            subtotal INTEGER NOT NULL,
            discount_amount INTEGER NOT NULL DEFAULT 0,
            total INTEGER NOT NULL,
            payment_method TEXT NOT NULL,
            payment_status TEXT NOT NULL,
            notes TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE bill_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bill_id INTEGER NOT NULL,
            item_order INTEGER NOT NULL,
            price INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE recent_prices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            value INTEGER NOT NULL UNIQUE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE recent_prices (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              value INTEGER NOT NULL UNIQUE
            )
          ''');
        }
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class SqfliteBillRepository implements BillRepository {
  SqfliteBillRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> getNextBillNumber() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT MAX(bill_number) AS m FROM bills');
    return (rows.first['m'] as int? ?? 0) + 1;
  }

  @override
  Future<Bill> saveBill({
    required int billNumber,
    required List<BillItem> items,
    required int discountAmount,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    String? notes,
  }) async {
    if (items.isEmpty) throw const EmptyBill();
    final db = await _db.database;
    final subtotal = items.fold<int>(0, (s, i) => s + i.lineTotal);
    final total = subtotal - discountAmount;
    try {
      return await db.transaction((txn) async {
        final id = await txn.insert('bills', {
          'bill_number': billNumber,
          'created_at': DateTime.now().toIso8601String(),
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'total': total,
          'payment_method': paymentMethod.name,
          'payment_status': paymentStatus.name,
          'notes': notes,
        });
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          await txn.insert('bill_items', {
            'bill_id': id,
            'item_order': i + 1,
            'price': item.price,
            'quantity': item.quantity,
          });
        }
        return Bill(
          id: id,
          billNumber: billNumber,
          createdAt: DateTime.now(),
          subtotal: subtotal,
          discountAmount: discountAmount,
          total: total,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
          notes: notes,
          items: List.of(items),
        );
      });
    } catch (_) {
      throw const StorageFailure();
    }
  }

  @override
  Future<Bill?> getBillById(int id) async {
    final db = await _db.database;
    final billRows = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (billRows.isEmpty) return null;
    return _toBill(db, billRows.first);
  }

  @override
  Future<List<Bill>> getBills({DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    var query = 'SELECT * FROM bills';
    final args = <Object>[];
    final clauses = <String>[];
    if (from != null) {
      clauses.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('created_at <= ?');
      args.add(to.toIso8601String());
    }
    if (clauses.isNotEmpty) {
      query += ' WHERE ${clauses.join(' AND ')}';
    }
    query += ' ORDER BY created_at DESC';
    final rows = await db.rawQuery(query, args);
    final bills = <Bill>[];
    for (final row in rows) {
      bills.add(await _toBill(db, row));
    }
    return bills;
  }

  Future<Bill> _toBill(Database db, Map<String, Object?> row) async {
    final id = row['id'] as int;
    final items = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [id],
      orderBy: 'item_order ASC',
    );
    return Bill(
      id: id,
      billNumber: row['bill_number'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      subtotal: row['subtotal'] as int,
      discountAmount: row['discount_amount'] as int? ?? 0,
      total: row['total'] as int,
      paymentMethod: PaymentMethod.values.byName(row['payment_method'] as String),
      paymentStatus: PaymentStatus.values.byName(row['payment_status'] as String),
      notes: row['notes'] as String?,
      items: items
          .map((i) => BillItem(
                id: i['id'] as int,
                billId: i['bill_id'] as int?,
                itemOrder: i['item_order'] as int,
                price: i['price'] as int,
                quantity: i['quantity'] as int,
              ))
          .toList(),
    );
  }

  @override
  Future<void> deleteBill(int id) async {
    final db = await _db.database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAllBills() async {
    final db = await _db.database;
    await db.delete('bill_items');
    await db.delete('bills');
  }

  @override
  Future<SalesSummary> getSalesSummary({DateTime? from, DateTime? to}) async {    final db = await _db.database;
    var query = 'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS s FROM bills';
    final args = <Object>[];
    final clauses = <String>[];
    if (from != null) {
      clauses.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('created_at <= ?');
      args.add(to.toIso8601String());
    }
    if (clauses.isNotEmpty) {
      query += ' WHERE ${clauses.join(' AND ')}';
    }
    final rows = await db.rawQuery(query, args);
    final row = rows.first;
    final count = row['c'] as int? ?? 0;
    final total = row['s'] as int? ?? 0;
    return SalesSummary(
      totalSales: total,
      billCount: count,
      averageBill: count == 0 ? 0 : total ~/ count,
    );
  }

  @override
  Future<List<int>> getRecentPrices() async {
    final db = await _db.database;
    final rows = await db.query(
      'recent_prices',
      orderBy: 'id DESC',
      limit: 4,
    );
    return rows.map((r) => r['value'] as int).toList();
  }

  @override
  Future<void> addRecentPrice(int price) async {
    final db = await _db.database;
    await db.insert(
      'recent_prices',
      {'value': price},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.rawDelete(
      'DELETE FROM recent_prices WHERE id NOT IN '
      '(SELECT id FROM recent_prices ORDER BY id DESC LIMIT 8)',
    );
  }
}

class SqfliteSettingsRepository implements SettingsRepository {
  SqfliteSettingsRepository(this._db, this._bills);

  final AppDatabase _db;
  final BillRepository _bills;

  static const _settingsKey = 'shop_settings_v1';

  @override
  Future<ShopSettings> loadSettings() async {
    final db = await _db.database;
    final rows = await db.query('app_settings');
    if (rows.isEmpty) return const ShopSettings();
    return ShopSettings.fromJson(
      jsonDecode(rows.first['value'] as String) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> saveSettings(ShopSettings settings) async {
    final db = await _db.database;
    await db.insert(
      'app_settings',
      {'key': _settingsKey, 'value': settings.toJsonString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> backupBills() async {
    try {
      final bills = await _bills.getBills();
      final data = jsonEncode(
        bills
            .map((b) => {
                  'billNumber': b.billNumber,
                  'createdAt': b.createdAt.toIso8601String(),
                  'subtotal': b.subtotal,
                  'discountAmount': b.discountAmount,
                  'total': b.total,
                  'paymentMethod': b.paymentMethod.name,
                  'paymentStatus': b.paymentStatus.name,
                  'notes': b.notes,
                  'items': b.items
                      .map((i) => {
                            'itemOrder': i.itemOrder,
                            'price': i.price,
                            'quantity': i.quantity,
                          })
                      .toList(),
                })
            .toList(),
      );
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, 'bills_backup.json'));
      await file.writeAsString(data);
    } catch (_) {
      throw const StorageFailure('Could not create backup.');
    }
  }

  @override
  Future<void> restoreBills() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, 'bills_backup.json'));
      if (!await file.exists()) {
        throw const StorageFailure('No backup file found.');
      }
      final data = jsonDecode(await file.readAsString()) as List<dynamic>;
      final db = await _db.database;
      await db.transaction((txn) async {
        await txn.delete('bill_items');
        await txn.delete('bills');
        for (final raw in data) {
          final bill = raw as Map<String, dynamic>;
          final items = (bill['items'] as List<dynamic>)
              .map((i) => BillItem(
                    itemOrder: i['itemOrder'] as int,
                    price: i['price'] as int,
                    quantity: i['quantity'] as int,
                  ))
              .toList();
          final subtotal =
              items.fold<int>(0, (s, i) => s + i.lineTotal);
          final id = await txn.insert('bills', {
            'bill_number': bill['billNumber'] as int,
            'created_at': bill['createdAt'] as String,
            'subtotal': subtotal,
            'discount_amount': bill['discountAmount'] as int? ?? 0,
            'total': bill['total'] as int,
            'payment_method': bill['paymentMethod'] as String,
            'payment_status': bill['paymentStatus'] as String? ?? 'paid',
            'notes': bill['notes'] as String?,
          });
          for (final item in items) {
            await txn.insert('bill_items', {
              'bill_id': id,
              'item_order': item.itemOrder,
              'price': item.price,
              'quantity': item.quantity,
            });
          }
        }
      });
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const StorageFailure('Could not restore backup.');
    }
  }
}