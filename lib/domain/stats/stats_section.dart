/// The parts of the statistics screen a reader can turn off.
///
/// Statistics is the one screen where the useful set genuinely differs by
/// person: somebody tracking a company car wants cost per kilometre and does
/// not care which station they used, and somebody chasing economy is the other
/// way round. Rather than guess, everything is on and anything can be hidden.
///
/// The names are stored, so renaming one silently un-hides whatever a reader
/// had turned off. Add rather than rename.
enum StatsSection {
  /// The headline figure with its per-day and per-distance rates.
  summary('summary'),

  /// This year against last, this month against the one before.
  comparison('comparison'),

  /// Best and worst: cheapest fill, worst economy, biggest bill.
  records('records'),

  /// Spend per cost category as a list of amounts.
  categories('categories'),

  /// Donut: fuel against service against everything else.
  spendByKind('spend_by_kind'),

  /// Donut: which cost categories the non-fuel money went to.
  spendByCategory('spend_by_category'),

  /// Donut: which filling stations the fuel money went to.
  spendByStation('spend_by_station'),

  /// Money in against money out. Only ever meaningful once income is being
  /// logged, which is why it is a section rather than always on.
  balance('balance'),

  /// Donut: which kinds of income the money came from.
  incomeByKind('income_by_kind'),

  /// Bars: spend per month, fuel stacked against the rest.
  monthlySpend('monthly_spend'),

  /// Line: the odometer over time, coloured by what recorded each point.
  odometerChart('odometer_chart');

  const StatsSection(this.key);

  /// The stored key. Deliberately not [name], so a Dart rename cannot quietly
  /// reset everybody's choices.
  final String key;

  static StatsSection? fromKey(String key) {
    for (final section in values) {
      if (section.key == key) {
        return section;
      }
    }
    return null;
  }
}
