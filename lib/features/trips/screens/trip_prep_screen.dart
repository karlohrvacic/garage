import '../../../core/widgets/unit_suffix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/trips/trip_preparation.dart';
import '../../documents/providers/document_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../documents/document_type_labels.dart';
import '../../maintenance/service_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/trip_prep_providers.dart';

/// What the garage's own records say falls due over a planned journey.
///
/// Deliberately narrow. It answers "does anything I have written down land in
/// the middle of this trip", and refuses to grow into a safety checklist: the
/// moment it says "check the lights" it implies an inspection nobody carried
/// out, on the strength of a screen.
class TripPrepScreen extends ConsumerStatefulWidget {
  const TripPrepScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<TripPrepScreen> createState() => _TripPrepScreenState();
}

class _TripPrepScreenState extends ConsumerState<TripPrepScreen> {
  final _distance = TextEditingController();
  final _newItem = TextEditingController();
  late DateTime _departOn = DateTime.now().toUtc();
  DateTime? _returnOn;
  TripPlan? _plan;

  @override
  void initState() {
    super.initState();
    // The checklist is per vehicle and lives on the device, so it has to be
    // asked for rather than derived.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripChecklistProvider.notifier).load(widget.vehicleId);
    });
  }

  @override
  void dispose() {
    _distance.dispose();
    _newItem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final checklist =
        ref.watch(tripChecklistProvider).value ?? const <String>[];

    return GaragePageScaffold(
      title: l10n.tripPrepTitle,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Text(
            l10n.tripPrepIntro,
            style: TextStyle(color: context.tokens.muted),
          ),
          const SizedBox(height: GarageTokens.space5),
          LabeledField(
            label: l10n.tripPrepDepart,
            child: OutlinedButton(
              key: const Key('prep-depart'),
              onPressed: () => _pickDate(isReturn: false),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(format.formatDate(_departOn.toLocal())),
              ),
            ),
          ),
          const SizedBox(height: GarageTokens.space4),
          LabeledField(
            label: l10n.tripPrepReturn,
            child: OutlinedButton(
              key: const Key('prep-return'),
              onPressed: () => _pickDate(isReturn: true),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _returnOn == null
                      ? l10n.tripPrepReturnNone
                      : format.formatDate(_returnOn!.toLocal()),
                ),
              ),
            ),
          ),
          const SizedBox(height: GarageTokens.space4),
          LabeledField(
            label: l10n.tripPrepDistance,
            child: TextField(
              key: const Key('prep-distance'),
              controller: _distance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GarageTheme.numericField(context),
              decoration: InputDecoration(
                suffixIcon: unitSuffix(context, format.distanceSuffix),
              ),
            ),
          ),
          const SizedBox(height: GarageTokens.space5),
          FilledButton(
            key: const Key('prep-check'),
            onPressed: _check,
            child: Text(l10n.tripPrepCheck),
          ),
          if (_plan case final plan?) ...[
            const SizedBox(height: GarageTokens.space6),
            ..._results(context, plan, format, l10n),
          ],
          const SizedBox(height: GarageTokens.space6),
          Text(
            l10n.tripPrepOwnList.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          const SizedBox(height: GarageTokens.space1),
          Text(
            l10n.tripPrepOwnListHint,
            style: TextStyle(color: context.tokens.muted),
          ),
          for (var i = 0; i < checklist.length; i++)
            ListTile(
              key: Key('prep-item-$i'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_box_outline_blank),
              title: Text(checklist[i]),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(tripChecklistProvider.notifier).removeAt(i),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('prep-new-item'),
                  controller: _newItem,
                  decoration: InputDecoration(hintText: l10n.tripPrepAddItem),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              IconButton(
                key: const Key('prep-add-item'),
                icon: const Icon(Icons.add),
                onPressed: _addItem,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    TripPlan plan,
    UnitFormat format,
    AppLocalizations l10n,
  ) {
    final tokens = context.tokens;
    if (plan.odometerUnknown) {
      return [
        Text(l10n.tripPrepNoOdometer, style: TextStyle(color: tokens.warn)),
      ];
    }
    if (!plan.anything) {
      return [Text(l10n.tripPrepNothing)];
    }

    return [
      // Dated obligations first, and under their own heading: these are facts
      // written on paper, not projections.
      if (plan.deadlines.isNotEmpty) ...[
        Text(
          l10n.tripPrepDeadlines.toUpperCase(),
          style: GarageTheme.eyebrow(context).copyWith(color: tokens.danger),
        ),
        const SizedBox(height: GarageTokens.space2),
        for (final deadline in plan.deadlines)
          Padding(
            padding: const EdgeInsets.only(bottom: GarageTokens.space2),
            child: Text(
              '${documentTypeLabel(l10n, deadline.document.type)} — '
              '${l10n.tripPrepExpiresOn(format.formatDate(deadline.expiresOn.toLocal()))}',
            ),
          ),
        const SizedBox(height: GarageTokens.space5),
      ],
      if (plan.forecast.isNotEmpty) ...[
        Text(
          l10n.tripPrepForecast.toUpperCase(),
          style: GarageTheme.eyebrow(context),
        ),
        const SizedBox(height: GarageTokens.space1),
        // The distinction the whole screen turns on: a projection is not a
        // deadline, and saying so is cheaper than being believed wrongly.
        Text(l10n.tripPrepForecastNote, style: TextStyle(color: tokens.muted)),
        const SizedBox(height: GarageTokens.space2),
        for (final item in plan.forecast)
          Padding(
            padding: const EdgeInsets.only(bottom: GarageTokens.space2),
            child: Text(
              '${serviceTypeLabel(l10n, item.projection.serviceTypeKey)} — '
              '${item.kmAway <= 0 ? l10n.tripPrepAlreadyPast : l10n.tripPrepKmAway(format.formatDistance(item.kmAway.toDouble(), decimals: 0))}',
            ),
          ),
      ],
    ];
  }

  Future<void> _addItem() async {
    await ref.read(tripChecklistProvider.notifier).add(_newItem.text);
    _newItem.clear();
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final initial = isReturn ? (_returnOn ?? _departOn) : _departOn;
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: initial,
      // Forward-looking, unlike every other date in this app: the whole screen
      // is about a journey that has not happened.
      firstDate: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().toUtc().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isReturn) {
        _returnOn = picked;
      } else {
        _departOn = picked;
        // A return before departure is not a journey.
        if (_returnOn != null && _returnOn!.isBefore(picked)) {
          _returnOn = null;
        }
      }
    });
  }

  Future<void> _check() async {
    final distance =
        double.tryParse(_distance.text.trim().replaceAll(',', '.')) ?? 0;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.read(unitPreferencesProvider),
    );

    final projections = await ref.read(
      vehicleProjectionsProvider(widget.vehicleId).future,
    );
    final documents = await ref.read(
      vehicleDocumentsProvider(widget.vehicleId).future,
    );
    final odometer = await ref.read(
      currentOdometerProvider(widget.vehicleId).future,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _plan = prepareForTrip(
        today: DateTime.now().toUtc(),
        departOn: _departOn,
        returnOn: _returnOn,
        // Typed in whatever unit the garage shows, stored and compared in km.
        distanceKm: format.preferences.displayToKm(distance),
        currentOdometerKm: odometer,
        projections: projections,
        documents: documents,
      );
    });
  }
}
