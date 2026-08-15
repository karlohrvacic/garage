/// Which kind of entry an attachment hangs off. Stored as the language-neutral
/// key the `attachments.entry_kind` column checks against.
enum AttachmentEntryKind {
  fuel('fuel'),
  service('service'),
  cost('cost');

  const AttachmentEntryKind(this.key);

  final String key;

  static AttachmentEntryKind fromKey(String key) {
    for (final kind in values) {
      if (kind.key == key) {
        return kind;
      }
    }
    throw ArgumentError.value(key, 'key', 'not an attachment entry kind');
  }
}

/// A receipt or document kept with an entry: the pump receipt for a fill-up,
/// the shop invoice for a service, the policy for an insurance cost.
///
/// The file itself lives in Storage; this is the household-scoped record of
/// what it is and which entry it belongs to.
class Attachment {
  const Attachment({
    required this.id,
    required this.vehicleId,
    required this.entryKind,
    required this.entryId,
    required this.storagePath,
    required this.fileName,
    required this.createdBy,
    required this.createdAt,
    this.contentType,
    this.sizeBytes,
  });

  final String id;

  /// The vehicle the entry belongs to. Attachments are scoped by vehicle so a
  /// single row-level rule covers all three entry kinds.
  final String vehicleId;

  final AttachmentEntryKind entryKind;
  final String entryId;

  /// Key inside the `attachments` bucket, `<vehicle id>/<unique>-<file name>`.
  final String storagePath;

  final String fileName;
  final String? contentType;
  final int? sizeBytes;
  final String createdBy;
  final DateTime createdAt;

  /// Whether this can be shown as a picture rather than a file row. Falls back
  /// to the extension: a file picked on some platforms arrives without a MIME
  /// type at all.
  bool get isImage {
    final type = contentType;
    if (type != null && type.isNotEmpty) {
      return type.startsWith('image/');
    }
    final extension = fileName.split('.').last.toLowerCase();
    return const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'heic',
    }.contains(extension);
  }

  /// The storage key for a new upload.
  ///
  /// The vehicle id leads, because the storage policies read the first path
  /// segment. The file name is reduced to plain ASCII: storage keys reject a
  /// slash outright, and diacritics survive round trips badly enough to be not
  /// worth the risk on a name nobody reads.
  static String storagePathFor({
    required String vehicleId,
    required String uniqueId,
    required String fileName,
  }) {
    return '$vehicleId/$uniqueId-${_safeName(fileName)}';
  }

  static String _safeName(String fileName) {
    const folded = {
      'č': 'c',
      'ć': 'c',
      'đ': 'd',
      'š': 's',
      'ž': 'z',
      'Č': 'C',
      'Ć': 'C',
      'Đ': 'D',
      'Š': 'S',
      'Ž': 'Z',
    };
    final ascii = fileName.split('').map((c) => folded[c] ?? c).join();
    return ascii
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_(?=\.)|_$'), '');
  }

  @override
  bool operator ==(Object other) {
    return other is Attachment &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.entryKind == entryKind &&
        other.entryId == entryId &&
        other.storagePath == storagePath &&
        other.fileName == fileName &&
        other.contentType == contentType &&
        other.sizeBytes == sizeBytes &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    entryKind,
    entryId,
    storagePath,
    fileName,
    contentType,
    sizeBytes,
    createdBy,
    createdAt,
  );

  @override
  String toString() {
    return 'Attachment(id: $id, vehicleId: $vehicleId, '
        'entryKind: ${entryKind.key}, entryId: $entryId, '
        'storagePath: $storagePath, fileName: $fileName, '
        'contentType: $contentType, sizeBytes: $sizeBytes, '
        'createdBy: $createdBy, createdAt: $createdAt)';
  }
}
