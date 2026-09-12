import 'package:cloud_firestore/cloud_firestore.dart';

/// Manifest du dernier dictionnaire publié dans le cloud.
///
/// Stocké dans Firestore à `dictionaries/latest`. Le payload gzippé vit dans
/// Firebase Storage au chemin `storagePath`.
class RemoteDictionaryManifest {
  const RemoteDictionaryManifest({
    required this.version,
    required this.sha256,
    required this.sizeBytes,
    required this.wordCount,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.storagePath,
  });

  final String version;
  final String sha256;
  final int sizeBytes;
  final int wordCount;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String storagePath;

  factory RemoteDictionaryManifest.fromMap(Map<String, dynamic> map) {
    final raw = map['uploadedAt'];
    DateTime uploadedAt;
    if (raw is Timestamp) {
      uploadedAt = raw.toDate();
    } else if (raw is DateTime) {
      uploadedAt = raw;
    } else if (raw is int) {
      uploadedAt = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      uploadedAt = DateTime.now();
    }
    return RemoteDictionaryManifest(
      version: map['version'] as String? ?? '',
      sha256: map['sha256'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      wordCount: (map['wordCount'] as num?)?.toInt() ?? 0,
      uploadedAt: uploadedAt,
      uploadedBy: map['uploadedBy'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'sha256': sha256,
        'sizeBytes': sizeBytes,
        'wordCount': wordCount,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
        'uploadedBy': uploadedBy,
        'storagePath': storagePath,
      };

  @override
  String toString() =>
      'RemoteDictionaryManifest(version: $version, sha256: ${sha256.substring(0, 12)}…, '
      'words: $wordCount, uploadedAt: $uploadedAt)';
}