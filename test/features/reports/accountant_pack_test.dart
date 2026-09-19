import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/company/payment_method.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/reports/accountant_pack.dart';
import 'package:garage/features/reports/report_builder.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A one-pixel PNG, which is enough for the PDF library to place.
final onePixel = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
);

final period = ReportPeriod(
  from: DateTime.utc(2026, 9, 1),
  to: DateTime.utc(2026, 9, 30),
  label: 'September 2026',
);

Attachment receiptFor(
  String entryId, {
  String id = 'a1',
  String fileName = 'parking.png',
  String contentType = 'image/png',
}) {
  return Attachment(
    id: id,
    vehicleId: 'v1',
    entryKind: AttachmentEntryKind.cost,
    entryId: entryId,
    storagePath: 'v1/$id-$fileName',
    fileName: fileName,
    contentType: contentType,
    sizeBytes: onePixel.length,
    createdBy: 'u2',
    createdAt: DateTime.utc(2026, 9, 3),
  );
}

Vehicle car({String? plate = 'ZG 1234 AB', String nickname = 'Golf'}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: nickname,
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
    plate: plate,
  );
}

VehiclePack golf({
  Vehicle? vehicle,
  List<ReceiptImage>? receipts,
  bool withReceipt = true,
}) {
  return VehiclePack(
    vehicle: vehicle ?? car(),
    fuel: [
      FuelEntry(
        id: 'f1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 9, 12),
        odometerKm: 61000,
        volumeL: 40,
        total: 62,
        fullTank: true,
        missedFill: false,
        createdBy: 'u2',
        paidWith: PaymentMethod.companyCard,
      ),
      // Outside the month: not in the ledger.
      FuelEntry(
        id: 'f0',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 8, 30),
        odometerKm: 60000,
        volumeL: 40,
        total: 60,
        fullTank: true,
        missedFill: false,
        createdBy: 'u2',
      ),
    ],
    services: const [],
    costs: [
      CostEntry(
        id: 'c1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 9, 3),
        category: CostCategories.parking,
        amount: 12.5,
        createdBy: 'u2',
        paidWith: PaymentMethod.ownMoney,
      ),
    ],
    receipts:
        receipts ??
        (withReceipt
            ? [ReceiptImage(attachment: receiptFor('c1'), bytes: onePixel)]
            : const []),
    assignments: [
      VehicleAssignment(
        id: 'as1',
        vehicleId: 'v1',
        userId: 'u2',
        fromDate: DateTime.utc(2026, 1, 1),
      ),
    ],
    driverNames: const {'u2': 'Ana'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  final l10n = AppLocalizationsEn();
  final format = UnitFormat(
    locale: 'en',
    preferences: const UnitPreferences(
      distance: DistanceUnit.km,
      volume: VolumeUnit.liter,
      currencyCode: 'EUR',
    ),
  );

  Future<Archive> pack({
    List<VehiclePack>? cars,
    bool withReceipt = true,
    String? letterhead = 'Prijevoz d.o.o. · 12345678901',
  }) async {
    final bytes = await buildAccountantPack(
      cars: cars ?? [golf(withReceipt: withReceipt)],
      period: period,
      letterhead: letterhead,
      l10n: l10n,
      format: format,
    );
    return ZipDecoder().decodeBytes(bytes);
  }

  List<String> names(Archive archive) =>
      archive.files.map((file) => file.name).toList();

  test(
    'one folder per car: the ledger, the originals and the spreadsheets',
    () async {
      final archive = await pack();

      expect(
        names(archive),
        contains('zg-1234-ab/zg-1234-ab-2026-09-ledger.pdf'),
      );
      expect(
        names(archive),
        contains('zg-1234-ab/2026-09-03-cost-12.50.png'),
        reason:
            'originals are named so a folder sorts by date and says what '
            'each is',
      );
      expect(
        names(archive),
        contains('zg-1234-ab/zg-1234-ab-2026-09-fuel.csv'),
      );
      expect(
        names(archive),
        contains('zg-1234-ab/zg-1234-ab-2026-09-cost.csv'),
      );
      expect(
        names(archive),
        contains('zg-1234-ab/zg-1234-ab-2026-09-service.csv'),
      );
    },
  );

  test(
    'the ledger is a PDF and the spreadsheets hold only the month',
    () async {
      final archive = await pack();
      String text(String name) =>
          utf8.decode(archive.findFile(name)!.content as List<int>);

      expect(
        utf8.decode(
          (archive.findFile('zg-1234-ab/zg-1234-ab-2026-09-ledger.pdf')!.content
                  as List<int>)
              .take(4)
              .toList(),
        ),
        '%PDF',
      );
      final fuel = text('zg-1234-ab/zg-1234-ab-2026-09-fuel.csv');
      expect(fuel, contains('2026-09-12'));
      expect(fuel, isNot(contains('2026-08-30')));
      // The two columns an accountant reads the sheet for: how it was paid,
      // and whose car it was that day.
      expect(fuel, contains('company_card'));
      expect(fuel, contains('Ana'));
      expect(text('zg-1234-ab/zg-1234-ab-2026-09-cost.csv'), contains('Ana'));
    },
  );

  test('a driver who has since left is named as a former member', () async {
    // The window is still in the log while the member list no longer has
    // the name; a blank would read as a day nobody had the car.
    final archive = await pack(
      cars: [
        VehiclePack(
          vehicle: car(),
          fuel: golf().fuel,
          services: const [],
          costs: const [],
          receipts: const [],
          assignments: golf().assignments,
          driverNames: const {},
        ),
      ],
    );
    final fuel = utf8.decode(
      archive.findFile('zg-1234-ab/zg-1234-ab-2026-09-fuel.csv')!.content
          as List<int>,
    );

    expect(fuel, contains('Former member'));
  });

  int ledgerSize(Archive archive) =>
      archive.findFile('zg-1234-ab/zg-1234-ab-2026-09-ledger.pdf')!.size;

  test('a receipt in the ledger makes the PDF longer', () async {
    final withReceipt = await pack();
    final without = await pack(withReceipt: false);
    int size(Archive archive) =>
        archive.findFile('zg-1234-ab/zg-1234-ab-2026-09-ledger.pdf')!.size;

    expect(size(withReceipt), greaterThan(size(without)));
    expect(
      names(without),
      isNot(contains('zg-1234-ab/2026-09-03-cost-12.50.png')),
    );
  });

  test('a receipt that is not a photo travels in the archive only', () async {
    final scanned = [
      ReceiptImage(
        attachment: receiptFor(
          'c1',
          fileName: 'parking.pdf',
          contentType: 'application/pdf',
        ),
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 not really')),
      ),
    ];
    final archive = await pack(cars: [golf(receipts: scanned)]);
    int size(Archive archive) =>
        archive.findFile('zg-1234-ab/zg-1234-ab-2026-09-ledger.pdf')!.size;

    expect(names(archive), contains('zg-1234-ab/2026-09-03-cost-12.50.pdf'));
    // The ledger says the entry has a receipt and stops there: the library
    // cannot place a PDF on a page, so no page was added for it.
    expect(size(archive), lessThan(size(await pack())));
  });

  test('a photo the PDF library cannot place travels in the archive', () async {
    // A HEIC camera shot is an image by content type and by extension, and
    // the pure Dart decoders have no codec for it: placing it would throw
    // while saving and take the whole pack down with it.
    final heic = [
      ReceiptImage(
        attachment: receiptFor(
          'c1',
          fileName: 'parking.heic',
          contentType: 'image/heic',
        ),
        bytes: Uint8List.fromList(List.filled(64, 0x42)),
      ),
    ];
    final archive = await pack(cars: [golf(receipts: heic)]);

    expect(names(archive), contains('zg-1234-ab/2026-09-03-cost-12.50.heic'));
    expect(ledgerSize(archive), lessThan(ledgerSize(await pack())));
  });

  test('the letterhead is printed above the ledger', () async {
    final headed = await pack(letterhead: 'Prijevoz d.o.o. · 12345678901');
    final bare = await pack(letterhead: null);

    expect(ledgerSize(headed), greaterThan(ledgerSize(bare)));
  });

  test('two receipts on one entry keep both originals', () async {
    final archive = await pack(
      cars: [
        golf(
          receipts: [
            ReceiptImage(attachment: receiptFor('c1'), bytes: onePixel),
            ReceiptImage(
              attachment: receiptFor('c1', id: 'a2'),
              bytes: onePixel,
            ),
          ],
        ),
      ],
    );

    expect(names(archive), contains('zg-1234-ab/2026-09-03-cost-12.50.png'));
    expect(names(archive), contains('zg-1234-ab/2026-09-03-cost-12.50-2.png'));
  });

  test('a receipt on an entry outside the month stays out', () async {
    final archive = await pack(
      cars: [
        golf(
          receipts: [
            ReceiptImage(
              attachment: Attachment(
                id: 'a0',
                vehicleId: 'v1',
                entryKind: AttachmentEntryKind.fuel,
                entryId: 'f0',
                storagePath: 'v1/a0-august.png',
                fileName: 'august.png',
                contentType: 'image/png',
                sizeBytes: onePixel.length,
                createdBy: 'u2',
                createdAt: DateTime.utc(2026, 8, 30),
              ),
              bytes: onePixel,
            ),
          ],
        ),
      ],
    );

    expect(names(archive).where((name) => name.endsWith('.png')), isEmpty);
  });

  test('a car with no plate is filed under its name', () async {
    final archive = await pack(
      cars: [golf(vehicle: car(plate: null))],
      letterhead: null,
    );

    expect(names(archive), contains('golf/golf-2026-09-ledger.pdf'));
  });

  test('two cars that would share a folder are told apart', () async {
    final archive = await pack(
      cars: [
        golf(vehicle: car(plate: null)),
        golf(vehicle: car(plate: null)),
      ],
    );

    expect(names(archive), contains('golf/golf-2026-09-ledger.pdf'));
    expect(names(archive), contains('golf-2/golf-2-2026-09-ledger.pdf'));
  });

  test('a month with nothing in it still yields the empty tables', () async {
    final archive = await pack(
      cars: [
        VehiclePack(
          vehicle: car(),
          fuel: const [],
          services: const [],
          costs: const [],
          receipts: const [],
          assignments: const [],
          driverNames: const {},
        ),
      ],
    );

    expect(
      names(archive),
      contains('zg-1234-ab/zg-1234-ab-2026-09-ledger.pdf'),
    );
    expect(names(archive), contains('zg-1234-ab/zg-1234-ab-2026-09-cost.csv'));
  });

  test('a folder name folds Croatian letters and drops the rest', () async {
    final archive = await pack(
      cars: [
        golf(vehicle: car(plate: 'ŠIBENIK 12 Č')),
        // Never an empty folder name, which would put the files at the root.
        golf(vehicle: car(plate: null, nickname: '🚗')),
      ],
    );

    expect(
      names(archive),
      contains('sibenik-12-c/sibenik-12-c-2026-09-ledger.pdf'),
    );
    expect(names(archive), contains('vehicle/vehicle-2026-09-ledger.pdf'));
  });
}
