/// What a vehicle takes on, which decides how a fill-up reads.
///
/// The stored quantity is the same column either way — what changes is the
/// unit it is read in: litres for a tank, kilowatt-hours for a battery. Keeping
/// one column keeps the economy algorithm, the charts, and the CSV export
/// working for both without a parallel set of tables.
enum EnergyType {
  liquid,
  electric;

  bool get isElectric => this == EnergyType.electric;

  /// The energy behind a vehicle's `fuelTypeKey`.
  ///
  /// A plug-in hybrid is treated as liquid: it logs fills at a pump, and its
  /// headline economy figure is the one built from those.
  static EnergyType forFuelKey(String fuelTypeKey) {
    return fuelTypeKey == 'fuel_electric'
        ? EnergyType.electric
        : EnergyType.liquid;
  }

  /// What one fill-up is measured in: its own fuel when it names one, and
  /// [vehicle] — what the car mainly takes — when it does not.
  ///
  /// Per entry rather than per car. A plug-in hybrid kept as petrol logs its
  /// charges beside its fills, and a charge is kilowatt-hours whatever the
  /// car mainly burns. The webhook message decides it the same way.
  static EnergyType forEntry(
    String? fuelTypeKey, {
    required EnergyType vehicle,
  }) => fuelTypeKey == null ? vehicle : forFuelKey(fuelTypeKey);

  /// What a total, a smallest fill or an average over fill-ups of [energies]
  /// is measured in: liquid when any of them is, electric when all are.
  ///
  /// Litres and kilowatt-hours do not add up, so such a figure is taken over
  /// one kind and leaves the other out. Liquid wins a garage that has both:
  /// the figures were built for a tank, and an electric car's own are one
  /// choice of car away.
  static EnergyType measuredOver(Iterable<EnergyType> energies) =>
      energies.isNotEmpty && energies.every((energy) => energy.isElectric)
      ? EnergyType.electric
      : EnergyType.liquid;
}
