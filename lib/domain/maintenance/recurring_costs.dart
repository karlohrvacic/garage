import '../entities/cost_entry.dart';

/// How long a vignette was bought for.
///
/// The periods countries actually sell, not a tidy scale: Romania's ninety days
/// is ninety days rather than three calendar months, and a "weekly" vignette is
/// seven days in Slovenia and ten in Hungary. See [VignetteCountry] for which
/// country sells which.
enum VignetteValidity {
  day1(days: 1),
  days7(days: 7),
  days10(days: 10),
  days30(days: 30),
  days60(days: 60),
  months2(months: 2),
  year(months: 12);

  const VignetteValidity({this.days = 0, this.months = 0});

  final int days;
  final int months;
}

/// The eight European countries that charge for motorways with a vignette
/// rather than at a barrier, and the periods each one sells for a car.
///
/// Picking the country first is what makes the periods honest: offering a
/// one-day vignette for Czechia, or a two-month one for Slovenia, would invent
/// products that cannot be bought. Croatia is absent on purpose — it charges by
/// the stretch driven at the barrier, which is a [CostCategories.toll], and a
/// household needs this list precisely when it leaves the country.
///
/// Durations and the operator's own shop, never prices: prices change every
/// January and would be a standing source of wrong numbers, while the periods
/// move rarely. Rarely is not never — Romania replaced its 7- and 90-day
/// vignettes with 10- and 60-day ones in July 2026 — so this list carries the
/// date it was checked, and the sheet shows the expiry it worked out rather
/// than hiding it.
///
/// **Verified August 2026** against each operator: ASFINAG (AT), BAZG (CH),
/// MyTo (CZ), NÚSZ (HU), NDS (SK), DARS (SI), BG TOLL (BG), CNAIR (RO).
///
/// [shopUrl] is deliberately the operator's own site and never a reseller.
/// Search results for these are dominated by lookalike shops charging a markup,
/// to the point that DARS publishes a warning about them, so sending a driver
/// straight to the state seller is the useful thing this can do.
///
/// Country names are localized in the UI rather than held here: this is a list
/// of places you are driving *to*, and a Croatian driver should not have to
/// pick "България" out of a menu.
enum VignetteCountry {
  austria('AT', 'ASFINAG', 'https://shop.asfinag.at', [
    VignetteValidity.day1,
    VignetteValidity.days10,
    VignetteValidity.months2,
    VignetteValidity.year,
  ]),
  bulgaria('BG', 'BG TOLL', 'https://bgtoll.bg', [
    VignetteValidity.days7,
    VignetteValidity.days30,
    VignetteValidity.year,
  ]),
  czechia('CZ', 'MyTo', 'https://edalnice.gov.cz', [
    VignetteValidity.days10,
    VignetteValidity.days30,
    VignetteValidity.year,
  ]),
  hungary('HU', 'NÚSZ', 'https://ematrica.nemzetiutdij.hu', [
    VignetteValidity.day1,
    VignetteValidity.days10,
    VignetteValidity.days30,
    VignetteValidity.year,
  ]),
  // Periods as changed by the July 2026 tariff reform, which replaced the
  // 7- and 90-day vignettes with 10- and 60-day ones.
  romania('RO', 'CNAIR', 'https://www.erovinieta.ro', [
    VignetteValidity.day1,
    VignetteValidity.days10,
    VignetteValidity.days30,
    VignetteValidity.days60,
    VignetteValidity.year,
  ]),
  slovakia('SK', 'NDS', 'https://eznamka.sk', [
    VignetteValidity.day1,
    VignetteValidity.days10,
    VignetteValidity.days30,
    VignetteValidity.year,
  ]),
  slovenia('SI', 'DARS', 'https://evinjeta.dars.si', [
    VignetteValidity.days7,
    VignetteValidity.days30,
    VignetteValidity.year,
  ]),
  // Sold only by the year, and that year is a fixed window (1 December to
  // 31 January the year after) rather than twelve months from purchase, which
  // is why the sheet prints the date it worked out.
  switzerland('CH', 'BAZG', 'https://via.admin.ch', [VignetteValidity.year]);

  const VignetteCountry(this.code, this.operator, this.shopUrl, this.products);

  /// ISO 3166-1 alpha-2.
  final String code;

  /// The state body that sells it, named so the link is visibly official.
  final String operator;

  /// The operator's own shop. Never a reseller.
  final String shopUrl;

  /// The periods this country sells to a car, shortest first.
  final List<VignetteValidity> products;
}

/// When a recurring expense comes round again, and what to call it.
///
/// For a renewal this is the day it falls due again. For a vignette it is the
/// **last day it is still valid**, so a reminder that morning still leaves the
/// whole day to buy the next one.
///
/// Dates, not times. Several countries sell by the hour underneath — Romania's
/// rovinieta runs in 24-hour periods from purchase, and an Austrian vignette
/// bought at midday does not expire at midnight — so the exact moment a
/// vignette lapses is not modelled. Landing the reminder on the morning of the
/// last certainly-valid day is the safe side of that imprecision, and the date
/// is shown on the entry so it can be corrected when a driver knows better.
class RecurringCostDue {
  const RecurringCostDue({required this.serviceTypeKey, required this.dueDate});

  final String serviceTypeKey;

  /// UTC date-only, like every domain [DateTime].
  final DateTime dueDate;
}

/// Which costs are obligations that return on a cycle rather than one-off
/// spending.
///
/// Registration and insurance are the ones every household pays yearly and
/// nobody wants to be caught out by; parking, washes, tolls and fines are
/// simply spent. The interval is the calendar year the payment covers — a
/// household that pays half-yearly can still edit the reminder it creates.
abstract final class RecurringCosts {
  static const _yearly = {
    CostCategories.registration: 'service_registration',
    CostCategories.insurance: 'service_insurance',
    // Comprehensive cover renews yearly like the mandatory policy, usually
    // with a different insurer on a different date, which is exactly why it
    // needs its own reminder rather than being folded into that one.
    CostCategories.insuranceComprehensive: 'service_insurance_comprehensive',
  };

  static const vignetteServiceTypeKey = 'service_vignette';

  /// The cost category that raises a reminder of [serviceTypeKey], or null
  /// when the reminder is about work rather than about paying for something.
  ///
  /// These reminders live in the service namespace because that is where the
  /// projection engine looks, but they are not services: nobody performs a
  /// vignette. Settling one means recording the payment, and this is what lets
  /// a screen offer that instead of asking someone to log having serviced an
  /// insurance policy.
  static String? categoryFor(String serviceTypeKey) {
    if (serviceTypeKey == vignetteServiceTypeKey) {
      return CostCategories.vignette;
    }
    for (final entry in _yearly.entries) {
      if (entry.value == serviceTypeKey) {
        return entry.key;
      }
    }
    return null;
  }

  /// [validity] applies only to a vignette, which is bought for a stated
  /// period rather than for a year. Without one there is no expiry to warn
  /// about, so nothing is scheduled.
  static RecurringCostDue? nextDue({
    required String category,
    required DateTime paidOn,
    VignetteValidity? validity,
  }) {
    if (category == CostCategories.vignette) {
      if (validity == null) {
        return null;
      }
      // The last day it is still valid, not the first day it is not. A period
      // covers its own first day: ASFINAG sells the 10-day vignette as "the
      // 1st day of validity plus 9 additional calendar days", and DARS sells
      // seven consecutive days. Counting a full period from the purchase date
      // claimed a day the driver does not have, which is the direction that
      // ends in a fine rather than a wasted euro.
      final period = _add(paidOn, days: validity.days, months: validity.months);
      return RecurringCostDue(
        serviceTypeKey: vignetteServiceTypeKey,
        dueDate: period.subtract(const Duration(days: 1)),
      );
    }

    final serviceTypeKey = _yearly[category];
    if (serviceTypeKey == null) {
      return null;
    }
    return RecurringCostDue(
      serviceTypeKey: serviceTypeKey,
      dueDate: _add(paidOn, months: 12),
    );
  }

  /// Months are calendar months, so a month from 31 January is 28 February
  /// rather than 2 March: a vignette bought on the 31st does not last longer
  /// than one bought on the 1st. The same clamp gives 29 February no
  /// anniversary, which is why a yearly renewal from it lands on the 28th.
  static DateTime _add(DateTime date, {int days = 0, int months = 0}) {
    if (months == 0) {
      return DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).add(Duration(days: days));
    }
    final zeroBased = date.month - 1 + months;
    final year = date.year + zeroBased ~/ 12;
    final month = zeroBased % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, date.day.clamp(1, lastDay));
  }
}
