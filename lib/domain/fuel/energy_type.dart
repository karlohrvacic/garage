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
}
