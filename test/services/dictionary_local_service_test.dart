import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:endingletter/utils/wordlist_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../services_test_setup.dart';

void main() {
  setUpAll(initSqfliteForTests);

  group('WordlistLoader.importCategoriesJson', () {
    late TestDb testDb;
    late Database db;

    setUp(() async {
      testDb = await openTestDb();
      db = testDb.db;
      // Pré-remplir avec quelques mots.
      await db.insert('words', {
        'word': 'apple', 'length': 5, 'first_letter': 'a',
        'last_letter': 'e', 'frequency': 0.001,
        'category': 'general', 'source_version': 'test',
      });
      await db.insert('words', {
        'word': 'zebra', 'length': 5, 'first_letter': 'z',
        'last_letter': 'a', 'frequency': 0.00001,
        'category': 'general', 'source_version': 'test',
      });
      await db.insert('words', {
        'word': 'tiger', 'length': 5, 'first_letter': 't',
        'last_letter': 'r', 'frequency': 0.001,
        'category': 'general', 'source_version': 'test',
      });
    });

    tearDown(() async => closeAndDeleteTestDb(testDb));

    test('update la catégorie des mots existants', () async {
      final json = jsonEncode({
        'version': 1,
        'categories': {
          'apple': 'food',
          'zebra': 'animals',
          'ghost': 'mythical', // pas dans la DB → ignoré
        }
      });
      final updated = await WordlistLoader.importCategoriesJson(db, json);
      expect(updated, 2);

      final rows = await db.query('words',
          columns: ['word', 'category'],
          where: 'word IN (?, ?, ?)',
          whereArgs: ['apple', 'zebra', 'tiger'],
          orderBy: 'word');
      final byWord = {
        for (final r in rows) r['word'] as String: r['category'] as String
      };
      expect(byWord['apple'], 'food');
      expect(byWord['zebra'], 'animals');
      expect(byWord['tiger'], 'general', reason: 'non touché');
    });

    test('JSON vide ne fait rien', () async {
      final updated = await WordlistLoader.importCategoriesJson(
          db, '{"version":1,"categories":{}}');
      expect(updated, 0);
    });
  });

  group('WordlistLoader.importJsonSync', () {
    late TestDb testDb;
    late Database db;

    setUp(() async {
      testDb = await openTestDb();
      db = testDb.db;
    });
    tearDown(() async => closeAndDeleteTestDb(testDb));

    test('insère les mots avec fréquences et catégories', () async {
      final jsonStr = jsonEncode({
        'version': '2026-06-15',
        'categories': {
          'apple': ['food'],
          'zebra': ['animals'],
          'orange': ['food', 'colors'],
        },
        'frequencies': {
          'apple': 0.001,
          'zebra': 0.0000042,
          'orange': 0.0008,
        }
      });
      final gzBytes = Uint8List.fromList(GZipEncoder().encode(utf8.encode(jsonStr))!);

      final inserted = await WordlistLoader.importJsonSync(
          db, gzBytes, 'v2026-06-15');
      expect(inserted, 3);

      final rows = await db.query('words', orderBy: 'word');
      expect(rows.length, 3);

      final apple = rows.firstWhere((r) => r['word'] == 'apple');
      final zebra = rows.firstWhere((r) => r['word'] == 'zebra');
      final orange = rows.firstWhere((r) => r['word'] == 'orange');
      expect(zebra['frequency'], 0.0000042);
      expect(orange['category'], 'food');
      expect(apple['first_letter'], 'a');
      expect(apple['last_letter'], 'e');
      expect(apple['length'], 5);
    });
  });
}
