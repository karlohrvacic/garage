import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/content_type.dart';

Uint8List bytesOf(List<int> head) =>
    Uint8List.fromList([...head, ...List.filled(32, 0)]);

Uint8List ascii(String head) => bytesOf(latin1.encode(head));

/// An ISO-BMFF file: a box size, `ftyp`, then the brand.
Uint8List ftyp(String brand) =>
    bytesOf([0, 0, 0, 24, ...latin1.encode('ftyp$brand')]);

void main() {
  group('what an upload says it is', () {
    test('the bytes decide, whatever the picker claimed', () {
      // A photo re-encoded to JPEG still arrives with the picker's
      // `image/heic`, and a file named `.png` can be anything.
      const cases = {
        'image/jpeg': [0xFF, 0xD8, 0xFF, 0xE0],
        'image/png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        'image/gif': [0x47, 0x49, 0x46, 0x38, 0x39, 0x61],
      };
      for (final MapEntry(key: want, value: head) in cases.entries) {
        expect(
          uploadContentType(
            bytesOf(head),
            claimed: 'image/heic',
            fileName: 'x.pdf',
          ),
          want,
        );
      }
      expect(uploadContentType(ascii('%PDF-1.7')), 'application/pdf');
      expect(
        uploadContentType(ascii('RIFF\x00\x00\x00\x00WEBPVP8 ')),
        'image/webp',
      );
    });

    test('an iPhone photo is HEIC or HEIF by its brand', () {
      expect(uploadContentType(ftyp('heic')), 'image/heic');
      expect(uploadContentType(ftyp('heix')), 'image/heic');
      expect(uploadContentType(ftyp('mif1')), 'image/heif');
    });

    test('a video in the same container is not a photo', () {
      expect(uploadContentType(ftyp('mp42')), 'application/octet-stream');
    });

    test('unknown bytes fall back to what the picker said', () {
      expect(
        uploadContentType(bytesOf([1, 2, 3]), claimed: 'image/jpeg'),
        'image/jpeg',
      );
    });

    test('and then to the file name', () {
      expect(
        uploadContentType(bytesOf([1, 2, 3]), fileName: 'Račun.JPG'),
        'image/jpeg',
      );
      expect(
        uploadContentType(bytesOf([1, 2, 3]), fileName: 'scan.pdf'),
        'application/pdf',
      );
    });

    test('a picker that says octet-stream has said nothing', () {
      // Some file providers report every file that way, and a scan named
      // `.pdf` would otherwise be sent as a type no bucket takes.
      expect(
        uploadContentType(
          bytesOf([1, 2, 3]),
          claimed: 'application/octet-stream',
          fileName: 'scan.pdf',
        ),
        'application/pdf',
      );
    });

    test('and never to a guess', () {
      // The bucket refuses what it does not accept; a guess would only move
      // the refusal to somewhere less honest.
      expect(
        uploadContentType(bytesOf([1, 2, 3]), fileName: 'notes'),
        'application/octet-stream',
      );
      expect(uploadContentType(Uint8List(0)), 'application/octet-stream');
    });
  });

  test('a vehicle photo is what the photo bucket takes', () {
    // The screen refuses anything else before sending it, so the two lists
    // have to agree: a type only the app accepted would fail at upload, and a
    // type only the bucket accepted would be refused for nothing.
    final migrations =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final setting = RegExp(
      r"allowed_mime_types\s*=\s*array\[([^\]]*)\]\s*where id = 'vehicle-photos'",
      dotAll: true,
    );
    final newest = migrations
        .map((file) => setting.firstMatch(file.readAsStringSync()))
        .whereType<RegExpMatch>()
        .last;

    expect(photoContentTypes, {
      for (final type in RegExp(r"'([^']+)'").allMatches(newest.group(1)!))
        type.group(1),
    });
  });
}
