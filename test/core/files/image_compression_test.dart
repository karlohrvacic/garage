import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/image_compression.dart';
import 'package:image/image.dart' as img;

img.Image _solidImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 40, 200));
  return image;
}

Uint8List _asJpg(img.Image image) =>
    Uint8List.fromList(img.encodeJpg(image, quality: 95));

Uint8List _asPng(img.Image image) => Uint8List.fromList(img.encodePng(image));

void main() {
  test('a photo larger than the cap is downscaled to the long edge', () {
    final original = _asJpg(_solidImage(3000, 2000));

    final decoded = img.decodeImage(compressImage(original))!;

    expect(decoded.width, 1600);
    expect(decoded.height, 1067);
  });

  test('a portrait photo keeps its aspect ratio, capped on the tall edge', () {
    final original = _asJpg(_solidImage(2000, 3000));

    final decoded = img.decodeImage(compressImage(original))!;

    expect(decoded.height, 1600);
    expect(decoded.width, 1067);
  });

  test('re-encoding a large photo actually shrinks it', () {
    final original = _asJpg(_solidImage(3000, 2000));

    expect(compressImage(original).length, lessThan(original.length));
  });

  test('a small, already-tiny image is never made bigger by re-encoding', () {
    final original = _asPng(_solidImage(40, 40));

    expect(compressImage(original).length, lessThanOrEqualTo(original.length));
  });

  test('bytes that are not a decodable image pass through unchanged', () {
    final notAnImage = Uint8List.fromList('%PDF-1.4 not really'.codeUnits);

    expect(compressImage(notAnImage), same(notAnImage));
  });

  test('a handful of bytes too short for any format sniffer to inspect '
      'passes through unchanged rather than throwing', () {
    final tooShort = Uint8List.fromList([1, 2, 3, 4]);

    expect(compressImage(tooShort), same(tooShort));
  });

  test('an icon photo is capped tighter than a document photo', () {
    final original = _asJpg(_solidImage(3000, 2000));

    final decoded = img.decodeImage(compressIconImage(original))!;

    expect(decoded.width, 960);
    expect(decoded.height, 640);
  });

  group('isCroppableImage', () {
    test('a real photo can be shown in a cropping editor', () {
      expect(isCroppableImage(_asJpg(_solidImage(100, 100))), isTrue);
    });

    test('a PDF picked through the same dialog cannot', () {
      final notAnImage = Uint8List.fromList('%PDF-1.4 not really'.codeUnits);

      expect(isCroppableImage(notAnImage), isFalse);
    });

    test('bytes too short to sniff a format from cannot', () {
      expect(isCroppableImage(Uint8List.fromList([1, 2, 3, 4])), isFalse);
    });
  });
}
