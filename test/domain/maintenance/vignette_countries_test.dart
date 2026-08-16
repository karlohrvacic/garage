import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';

/// Durations come from each operator's own 2026 product list (ASFINAG, FedRO,
/// MyTo, NUSZ, NDS, DARS, BG TOLL, CNAIR). Prices change every year and are
/// deliberately not modelled; which periods are sold changes rarely.
void main() {
  group('the countries that sell vignettes', () {
    test('every one offers at least one period', () {
      for (final country in VignetteCountry.values) {
        expect(country.products, isNotEmpty, reason: country.name);
      }
    });

    test('Switzerland sells only the annual, and nothing shorter', () {
      expect(VignetteCountry.switzerland.products, [VignetteValidity.year]);
    });

    // The four a Croatian household actually drives into, so these are the
    // ones worth getting right.
    test('Slovenia sells a week, a month and a year', () {
      expect(VignetteCountry.slovenia.products, [
        VignetteValidity.days7,
        VignetteValidity.days30,
        VignetteValidity.year,
      ]);
    });

    test('Austria sells a day, ten days, two months and a year', () {
      expect(VignetteCountry.austria.products, [
        VignetteValidity.day1,
        VignetteValidity.days10,
        VignetteValidity.months2,
        VignetteValidity.year,
      ]);
    });

    test('Hungary sells a day, ten days, a month and a year', () {
      expect(VignetteCountry.hungary.products, [
        VignetteValidity.day1,
        VignetteValidity.days10,
        VignetteValidity.days30,
        VignetteValidity.year,
      ]);
    });

    // Romania replaced its 7- and 90-day vignettes with 10- and 60-day ones in
    // the July 2026 tariff reform; sources still carrying the old pair are out
    // of date rather than describing a different vehicle class.
    test('Romania sells the sixty-day nobody else does', () {
      expect(
        VignetteCountry.romania.products,
        contains(VignetteValidity.days60),
      );
    });

    // Search results for these are dominated by resellers charging a markup —
    // DARS publishes a warning about them — so the value here is that every
    // link goes to the state seller.
    test('every shop link is the operator, on its own domain', () {
      const official = {
        VignetteCountry.austria: 'shop.asfinag.at',
        VignetteCountry.bulgaria: 'bgtoll.bg',
        VignetteCountry.czechia: 'edalnice.gov.cz',
        VignetteCountry.hungary: 'ematrica.nemzetiutdij.hu',
        VignetteCountry.romania: 'www.erovinieta.ro',
        VignetteCountry.slovakia: 'eznamka.sk',
        VignetteCountry.slovenia: 'evinjeta.dars.si',
        VignetteCountry.switzerland: 'via.admin.ch',
      };

      for (final country in VignetteCountry.values) {
        final url = Uri.parse(country.shopUrl);

        expect(url.scheme, 'https', reason: country.name);
        expect(url.host, official[country], reason: country.name);
        expect(country.operator, isNotEmpty, reason: country.name);
      }
    });

    test('each country is identifiable by its ISO code', () {
      final codes = VignetteCountry.values.map((c) => c.code).toList();

      expect(
        codes,
        containsAll(['AT', 'CH', 'CZ', 'HU', 'SK', 'SI', 'BG', 'RO']),
      );
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('a period a country does not sell is not offered for it', () {
      // Czechia has no one-day vignette; offering one would invent a product.
      expect(
        VignetteCountry.czechia.products,
        isNot(contains(VignetteValidity.day1)),
      );
    });
  });

  // An N-day vignette covers N calendar days *including* the day it starts:
  // ASFINAG describes the 10-day one as "the 1st day of validity plus 9
  // additional calendar days", and DARS sells 7 consecutive days. Adding a
  // full N claimed a day of validity the driver does not have, which is the
  // direction that ends in a fine.
  group('the last day a vignette is valid', () {
    test('a seven-day one bought on the 16th runs through the 22nd', () {
      final next = RecurringCosts.nextDue(
        category: 'vignette',
        paidOn: DateTime.utc(2026, 8, 16),
        validity: VignetteValidity.days7,
      );

      expect(next?.dueDate, DateTime.utc(2026, 8, 22));
    });

    test('a ten-day one is the first day plus nine more', () {
      final next = RecurringCosts.nextDue(
        category: 'vignette',
        paidOn: DateTime.utc(2026, 8, 16),
        validity: VignetteValidity.days10,
      );

      expect(next?.dueDate, DateTime.utc(2026, 8, 25));
    });

    test('a one-day one is the day it was bought', () {
      final next = RecurringCosts.nextDue(
        category: 'vignette',
        paidOn: DateTime.utc(2026, 8, 16),
        validity: VignetteValidity.day1,
      );

      expect(next?.dueDate, DateTime.utc(2026, 8, 16));
    });

    test('a two-month one ends the day before the same date', () {
      final next = RecurringCosts.nextDue(
        category: 'vignette',
        paidOn: DateTime.utc(2026, 8, 16),
        validity: VignetteValidity.months2,
      );

      expect(next?.dueDate, DateTime.utc(2026, 10, 15));
    });

    // Yearly *renewals* are a different thing: registration paid on the 14th
    // is due again on the 14th, not the 13th.
    test('but a yearly renewal still lands on its anniversary', () {
      final next = RecurringCosts.nextDue(
        category: CostCategories.insurance,
        paidOn: DateTime.utc(2026, 3, 14),
      );

      expect(next?.dueDate, DateTime.utc(2027, 3, 14));
    });
  });

  group('when a vignette bought abroad runs out', () {
    test('a sixty-day one runs sixty days, not two calendar months', () {
      final next = RecurringCosts.nextDue(
        category: 'vignette',
        paidOn: DateTime.utc(2026, 1, 1),
        validity: VignetteValidity.days60,
      );

      // 1 January plus 59 more days.
      expect(next?.dueDate, DateTime.utc(2026, 3, 1));
    });

    test('a one-day one is valid only on the day it was bought', () {
      final next = RecurringCosts.nextDue(
        category: 'vignette',
        paidOn: DateTime.utc(2026, 3, 14),
        validity: VignetteValidity.day1,
      );

      expect(next?.dueDate, DateTime.utc(2026, 3, 14));
    });
  });
}
