import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The longest a stored *document* photo's edge gets to be. Large enough
/// that a receipt or an odometer reading is still legible zoomed in; far
/// below what a phone camera hands over, which is the point.
const _maxDimension = 1600;

/// A vehicle photo is never shown larger than a small thumbnail (96×64 on
/// the edit screen), so it can be capped harder than a document someone
/// needs to read.
const _iconMaxDimension = 960;

const _jpegQuality = 82;

/// Downscales and re-encodes a photo before it is uploaded, so a 6 MB camera
/// shot does not cost the same as what it's a photo of.
///
/// Never returns something bigger than [bytes]: a file the codec cannot
/// decode (a PDF, an unsupported format like HEIC, a handful of bytes too
/// short to be a real image — the format sniffers in `package:image` read
/// past the end of those rather than reporting "not this format") or one
/// small enough that re-encoding would not help both pass through unchanged
/// rather than risk making the upload worse.
Uint8List compressImage(
  Uint8List bytes, {
  int maxDimension = _maxDimension,
  int quality = _jpegQuality,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return bytes;
  }
  if (decoded == null) {
    return bytes;
  }

  final longEdge = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longEdge > maxDimension
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDimension : null,
          height: decoded.height > decoded.width ? maxDimension : null,
        )
      : decoded;

  final encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  return encoded.length < bytes.length ? encoded : bytes;
}

/// [compressImage], capped for a photo that is only ever shown as an icon.
Uint8List compressIconImage(Uint8List bytes) =>
    compressImage(bytes, maxDimension: _iconMaxDimension);

/// Whether a cropping editor could show [bytes] at all.
///
/// A PDF picked through the same file dialog, or a HEIC camera shot the pure
/// Dart decoders in this app have no codec for, cannot be laid out on a
/// canvas any more than they can be resized — the crop screen would either
/// throw building it or show nothing to drag a rect over. Checked with the
/// same decoder [compressImage] already carries, so a file this returns
/// false for is one [compressImage] already knows to leave untouched.
bool isCroppableImage(Uint8List bytes) {
  try {
    return img.decodeImage(bytes) != null;
  } catch (_) {
    return false;
  }
}
