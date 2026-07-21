import 'package:garage/l10n/app_localizations.dart';

/// Resolves a language-neutral service-type key to its localized label. Keys
/// the app does not know (household-custom types added later) fall back to the
/// raw key so nothing renders blank.
String serviceTypeLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'service_oil_change' => l10n.serviceOilChange,
    'service_oil_filter' => l10n.serviceOilFilter,
    'service_air_filter' => l10n.serviceAirFilter,
    'service_cabin_filter' => l10n.serviceCabinFilter,
    'service_spark_plugs' => l10n.serviceSparkPlugs,
    'service_brake_fluid' => l10n.serviceBrakeFluid,
    'service_brake_pads_front' => l10n.serviceBrakePadsFront,
    'service_brake_pads_rear' => l10n.serviceBrakePadsRear,
    'service_timing_belt' => l10n.serviceTimingBelt,
    'service_coolant' => l10n.serviceCoolant,
    'service_transmission_oil' => l10n.serviceTransmissionOil,
    'service_tire_rotation' => l10n.serviceTireRotation,
    'service_tire_swap_seasonal' => l10n.serviceTireSwapSeasonal,
    'service_battery' => l10n.serviceBattery,
    'service_wipers' => l10n.serviceWipers,
    'service_registration' => l10n.serviceRegistration,
    'service_technical_inspection' => l10n.serviceTechnicalInspection,
    'service_insurance' => l10n.serviceInsurance,
    _ => key,
  };
}
