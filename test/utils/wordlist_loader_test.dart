import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WordlistLoader - gunzip + parsing', () {
    test('gunzip un fichier texte simple', () {
      final txt = 'apple\nbanana\ncherry\n';
      final gzBytes = GZipEncoder().encode(utf8.encode(txt))!;
      final decoded = utf8.decode(gunzip(gzBytes));
      expect(decoded, txt);
    });

    test('parse un JSON de sync Firestore', () {
      final jsonStr = jsonEncode({
        'version': '2026-06-15',
        'categories': {
          'apple': ['food'],
          'zebra': ['animals'],
        },
        'frequencies': {
          'apple': 0.001,
          'zebra': 0.0000042,
        },
      });
      final gzBytes = GZipEncoder().encode(utf8.encode(jsonStr))!;
      final decoded = utf8.decode(gunzip(gzBytes));
      final root = jsonDecode(decoded) as Map<String, dynamic>;
      expect(root['version'], '2026-06-15');
      expect((root['categories'] as Map).length, 2);
      expect((root['frequencies'] as Map)['zebra'], 0.0000042);
    });

    test('le seed bundlé assets/dictionary/enable_seed.txt.gz est valide', () {
      final file = File('assets/dictionary/enable_seed.txt.gz');
      expect(file.existsSync(), isTrue,
          reason: 'enable_seed.txt.gz doit être bundlé avant les tests.');
      final header = file.openSync().readSync(3);
      // Magic GZIP : 1f 8b 08
      expect(header[0], 0x1f);
      expect(header[1], 0x8b);
      expect(header[2], 0x08);
    });
  });
}

/// Helper partagé avec `lib/utils/wordlist_loader.dart`.
/// Décompresse un fichier gzip natif (RFC 1952).
Uint8List gunzip(List<int> bytes) {
  return Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
}
