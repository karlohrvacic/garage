import 'dart:convert';
import 'dart:typed_data';

/// What an upload tells storage it is.
///
/// Both buckets accept images, and attachments PDFs as well, and nothing else
/// (migration 0075). So the type sent has to be right, and three things the
/// app used to send could each be wrong or missing: a picker that reports no
/// type at all, a photo re-encoded to JPEG that still carries the picker's
/// `image/heic`, and a vehicle photo copied during a merge with no type,
/// which storage then guessed from a path that has no extension.
///
/// The bytes decide first, because they are what the file is. Then what the
/// picker said, then the file name. Anything else is
/// `application/octet-stream`, which the buckets refuse: a guess would only
/// move the refusal somewhere less honest.
///
/// A picker that claims `application/octet-stream` has said nothing: some
/// file providers report every file that way.
String uploadContentType(Uint8List bytes, {String? claimed, String? fileName}) {
  return _sniffed(bytes) ??
      _saysSomething(claimed) ??
      _byExtension(fileName) ??
      _unknown;
}

/// The types the `vehicle-photos` bucket takes (migration 0075), for a screen
/// to refuse anything else before sending it.
const photoContentTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/heic',
  'image/heif',
};

const _unknown = 'application/octet-stream';

String? _saysSomething(String? claimed) {
  final trimmed = claimed?.trim();
  return trimmed == null || trimmed.isEmpty || trimmed == _unknown
      ? null
      : trimmed;
}

bool _startsWith(Uint8List bytes, List<int> head, [int offset = 0]) {
  if (bytes.length < offset + head.length) {
    return false;
  }
  for (var i = 0; i < head.length; i++) {
    if (bytes[offset + i] != head[i]) {
      return false;
    }
  }
  return true;
}

/// The HEIF family's brands that mean a still image, as the `ftyp` box names
/// them. A phone video uses the same container with brands like `mp42`, and
/// is not a photo.
const _heicBrands = {'heic', 'heix', 'heim', 'heis', 'hevc', 'hevx'};
const _heifBrands = {'mif1', 'msf1'};

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

String? _sniffed(Uint8List bytes) {
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
  }
  if (_startsWith(bytes, _pngSignature)) {
    return 'image/png';
  }
  if (_startsWith(bytes, latin1.encode('GIF87a')) ||
      _startsWith(bytes, latin1.encode('GIF89a'))) {
    return 'image/gif';
  }
  if (_startsWith(bytes, latin1.encode('RIFF')) &&
      _startsWith(bytes, latin1.encode('WEBP'), 8)) {
    return 'image/webp';
  }
  if (_startsWith(bytes, latin1.encode('%PDF-'))) {
    return 'application/pdf';
  }
  if (_startsWith(bytes, latin1.encode('ftyp'), 4) && bytes.length >= 12) {
    final brand = latin1.decode(bytes.sublist(8, 12));
    if (_heicBrands.contains(brand)) {
      return 'image/heic';
    }
    if (_heifBrands.contains(brand)) {
      return 'image/heif';
    }
  }
  return null;
}

/// The extensions the file pickers offer (`lib/core/files/file_picker.dart`),
/// and nothing they do not.
const _extensions = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'pdf': 'application/pdf',
};

String? _byExtension(String? fileName) {
  final name = fileName?.trim().toLowerCase();
  if (name == null) {
    return null;
  }
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) {
    return null;
  }
  return _extensions[name.substring(dot + 1)];
}
