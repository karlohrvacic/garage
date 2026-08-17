import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/import/csv_import.dart';
import '../../../domain/import/csv_table.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/csv_import_action.dart';
import '../providers/unit_providers.dart';

/// Import from any app that can export a table.
///
/// The answer to "import from Drivvo", and deliberately not a Drivvo importer.
/// Reverse-engineering one export means guessing at column names, date formats
/// and decimal separators that can change under us; asking the user which
/// column is which takes a minute once and works for a spreadsheet somebody
/// kept by hand.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  CsvTable? _table;
  CsvEntryKind _kind = CsvEntryKind.fuel;
  String? _vehicleId;
  Map<String, int> _mapping = const {};
  bool _dayFirst = true;
  bool _miles = false;
  bool _gallons = false;
  bool _busy = false;
  String? _outcome;
  AppFailure? _failure;

  Future<void> _pickFile() async {
    setState(() => _failure = null);
    try {
      final file = await ref.read(backupFilePickerProvider)();
      if (file == null || !mounted) {
        return;
      }
      final table = CsvTable.parse(await file.readAsString());
      if (!mounted) {
        return;
      }
      setState(() {
        _table = table;
        _outcome = null;
        _mapping = CsvSchema.guess(_kind, table.headers);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    }
  }

  /// A different kind wants a different set of columns, so the guess is redone
  /// rather than carried over: a mapping made for fill-ups means nothing for
  /// trips, and leaving it in place looks like the app understood the file.
  void _changeKind(CsvEntryKind kind) {
    setState(() {
      _kind = kind;
      _outcome = null;
      _mapping = _table == null
          ? const {}
          : CsvSchema.guess(kind, _table!.headers);
    });
  }

  CsvImportResult? get _result {
    final table = _table;
    if (table == null) {
      return null;
    }
    return CsvImport.build(
      kind: _kind,
      table: table,
      mapping: _mapping,
      dayFirst: _dayFirst,
    );
  }

  Future<void> _import() async {
    final result = _result;
    final vehicleId = _vehicleId;
    if (result == null || vehicleId == null || !result.isUsable) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final written = await writeCsvRows(
        ref: ref,
        vehicleId: vehicleId,
        kind: _kind,
        rows: result.rows,
        units: CsvUnits(
          milesToKm: _miles,
          gallonsToLitres: _gallons,
          gallon: ref.read(unitPreferencesProvider).volume,
        ),
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _busy = false;
          _outcome = l10n.csvImported(written.written, written.skipped);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = AppFailure.from(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = ref.watch(allVehiclesProvider).value ?? const [];
    final table = _table;
    final result = _result;
    _vehicleId ??= vehicles.isEmpty ? null : vehicles.first.id;

    return GaragePageScaffold(
      title: l10n.csvImportTitle,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Text(l10n.csvImportIntro),
          const SizedBox(height: GarageTokens.space4),
          FilledButton.icon(
            key: const Key('csv-pick-file'),
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(l10n.csvPickFile),
          ),
          if (table != null && table.headers.isEmpty) ...[
            const SizedBox(height: GarageTokens.space4),
            Text(
              l10n.csvFileEmpty,
              style: TextStyle(color: context.tokens.danger),
            ),
          ],
          if (table != null && table.headers.isNotEmpty) ...[
            const SizedBox(height: GarageTokens.space6),
            LabeledField(
              label: l10n.csvWhatIsIt,
              child: DropdownButtonFormField<CsvEntryKind>(
                key: const Key('csv-kind'),
                initialValue: _kind,
                isExpanded: true,
                items: [
                  for (final kind in CsvEntryKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(_kindLabel(l10n, kind)),
                    ),
                ],
                onChanged: (value) => value == null ? null : _changeKind(value),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            LabeledField(
              label: l10n.csvWhichVehicle,
              child: DropdownButtonFormField<String>(
                key: const Key('csv-vehicle'),
                initialValue: _vehicleId,
                isExpanded: true,
                items: [
                  for (final vehicle in vehicles)
                    DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.nickname),
                    ),
                ],
                onChanged: (value) => setState(() => _vehicleId = value),
              ),
            ),
            const SizedBox(height: GarageTokens.space5),
            Text(
              l10n.csvColumns.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space2),
            for (final field in CsvSchema.fieldsFor(_kind))
              Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space3),
                child: LabeledField(
                  label: field.required
                      ? '${_fieldLabel(l10n, field.key)} · ${l10n.csvRequired}'
                      : _fieldLabel(l10n, field.key),
                  child: DropdownButtonFormField<int?>(
                    key: Key('csv-column-${field.key}'),
                    initialValue: _mapping[field.key],
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.csvColumnNone),
                      ),
                      for (var i = 0; i < table.headers.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(table.headers[i]),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      final next = Map<String, int>.from(_mapping);
                      if (value == null) {
                        next.remove(field.key);
                      } else {
                        next[field.key] = value;
                      }
                      _mapping = next;
                      _outcome = null;
                    }),
                  ),
                ),
              ),
            SwitchListTile(
              key: const Key('csv-day-first'),
              contentPadding: EdgeInsets.zero,
              value: _dayFirst,
              title: Text(l10n.csvDayFirst),
              onChanged: (value) => setState(() => _dayFirst = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _miles,
              title: Text(l10n.csvMiles),
              onChanged: (value) => setState(() => _miles = value),
            ),
            if (_kind == CsvEntryKind.fuel)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _gallons,
                title: Text(l10n.csvGallons),
                onChanged: (value) => setState(() => _gallons = value),
              ),
            const SizedBox(height: GarageTokens.space5),
            Text(
              l10n.csvPreview.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space2),
            if (result != null) _Preview(result: result, kind: _kind),
            const SizedBox(height: GarageTokens.space4),
            FilledButton.icon(
              key: const Key('csv-import'),
              onPressed:
                  _busy || _vehicleId == null || !(result?.isUsable ?? false)
                  ? null
                  : _import,
              icon: const Icon(Icons.download_done),
              label: Text(l10n.csvImportAction),
            ),
          ],
          if (_outcome != null) ...[
            const SizedBox(height: GarageTokens.space4),
            Text(
              _outcome!,
              key: const Key('csv-outcome'),
              style: TextStyle(color: context.tokens.success),
            ),
          ],
          if (_failure != null) ...[
            const SizedBox(height: GarageTokens.space4),
            Text(
              failureMessage(l10n, _failure!),
              style: TextStyle(color: context.tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// What will be written and what will not.
///
/// Shown before the import rather than reported after it: a row that cannot be
/// read is a row somebody has to go and fix in their file, and finding that out
/// afterwards means doing the whole import again.
class _Preview extends StatelessWidget {
  const _Preview({required this.result, required this.kind});

  final CsvImportResult result;
  final CsvEntryKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mappingProblems = result.problems
        .where((p) => p.rowNumber == null)
        .toList();
    final rowProblems = result.problems
        .where((p) => p.rowNumber != null)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.csvReadyToImport(result.rows.length),
              key: const Key('csv-ready'),
              style: GarageTheme.numeric(
                Theme.of(context).textTheme.titleMedium!,
              ),
            ),
            for (final problem in mappingProblems)
              Padding(
                padding: const EdgeInsets.only(top: GarageTokens.space2),
                child: Text(
                  l10n.csvMissingColumn(_fieldLabel(l10n, problem.field)),
                  style: TextStyle(color: context.tokens.danger),
                ),
              ),
            if (rowProblems.isNotEmpty) ...[
              const SizedBox(height: GarageTokens.space2),
              Text(
                l10n.csvSkippedRows(rowProblems.length),
                style: TextStyle(color: context.tokens.warn),
              ),
              // Only the first few: a file with a hundred bad rows has one
              // problem, and listing it a hundred times buries the fix.
              for (final problem in rowProblems.take(5))
                Text(
                  l10n.csvRowProblem(
                    problem.rowNumber!,
                    _fieldLabel(l10n, problem.field),
                  ),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _kindLabel(AppLocalizations l10n, CsvEntryKind kind) {
  return switch (kind) {
    CsvEntryKind.fuel => l10n.csvKindFuel,
    CsvEntryKind.cost => l10n.csvKindCost,
    CsvEntryKind.service => l10n.csvKindService,
    CsvEntryKind.odometer => l10n.csvKindOdometer,
    CsvEntryKind.trip => l10n.csvKindTrip,
    CsvEntryKind.income => l10n.csvKindIncome,
  };
}

/// The name a reader sees for a field they are mapping a column onto. Falls
/// back to the key rather than crashing, so a field added later still shows.
String _fieldLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'date' => l10n.csvFieldDate,
    'odometer' => l10n.csvFieldOdometer,
    'volume' => l10n.csvFieldVolume,
    'pricePerUnit' => l10n.csvFieldPricePerUnit,
    'total' => l10n.csvFieldTotal,
    'fullTank' => l10n.csvFieldFullTank,
    'station' => l10n.csvFieldStation,
    'notes' => l10n.csvFieldNotes,
    'amount' => l10n.csvFieldAmount,
    'category' => l10n.csvFieldCategory,
    'type' => l10n.csvFieldType,
    'cost' => l10n.csvFieldCost,
    'shop' => l10n.csvFieldShop,
    'distance' => l10n.csvFieldDistance,
    'title' => l10n.csvFieldTitle,
    'from' => l10n.csvFieldFrom,
    'to' => l10n.csvFieldTo,
    'business' => l10n.csvFieldBusiness,
    'minutes' => l10n.csvFieldMinutes,
    _ => key,
  };
}
