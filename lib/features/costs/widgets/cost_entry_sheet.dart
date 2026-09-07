import '../../../core/widgets/unit_suffix.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/busy_label.dart';
import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entries/duplicate_entry.dart';
import '../../../domain/format/amount_expression.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/maintenance/recurring_costs.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../../domain/entities/attachment.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../settings/providers/unit_providers.dart';
import '../cost_category_labels.dart';
import '../providers/cost_providers.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../core/ids.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/amount_calculator_dock.dart';
import '../../vehicles/widgets/sheet_vehicle_row.dart';

/// Opens the cost-entry sheet and returns true if an entry was saved.
Future<bool?> showCostEntrySheet(
  BuildContext context,
  String vehicleId, {
  CostEntry? existing,
  String? initialCategory,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => CostEntrySheet(
      vehicleId: vehicleId,
      existing: existing,
      initialCategory: initialCategory,
    ),
  );
}

class CostEntrySheet extends ConsumerStatefulWidget {
  const CostEntrySheet({
    required this.vehicleId,
    this.existing,
    this.initialCategory,
    super.key,
  });

  /// Preselected when the sheet is opened from something that already knows
  /// what is being paid — a due vignette or registration. Ignored when
  /// editing, which carries its own.
  final String? initialCategory;

  final String vehicleId;
  final CostEntry? existing;

  @override
  ConsumerState<CostEntrySheet> createState() => _CostEntrySheetState();
}

class _CostEntrySheetState extends ConsumerState<CostEntrySheet> {
  /// The car being charged. Held in state rather than read from the widget:
  /// the sheet opens on whichever car the caller had in hand, and a new entry
  /// may be moved to another before it is saved.
  late String _vehicleId = widget.vehicleId;

  /// Chosen once, so a save retried after a timeout is the same entry.
  late final _newId = newEntryId();

  /// Whether the entry reached the repository. Until it does, anything
  /// attached hangs off an id nothing else knows about, and closing the sheet
  /// has to take it back down.
  bool _saved = false;

  /// Whether a write was ever started. A save that times out is not a save
  /// that failed — the request cannot be cancelled and may well have landed —
  /// so from here the cleanup keeps its hands off. An orphaned file costs
  /// storage; deleting a receipt off a real entry costs the household its
  /// paperwork.
  bool _attemptedWrite = false;

  /// Uploads still in flight. The cleanup waits for them: a file picked and
  /// then abandoned mid-upload would otherwise be inserted after the query
  /// that was meant to find it, and nothing would ever list it again.
  final _uploads = <Future<void>>[];

  /// Whether anything was attached in this sheet, which makes it dirty: a
  /// receipt is worth more than the fields around it, and dismissing the
  /// sheet by tapping outside used to take it with no question asked.
  bool _attachedAny = false;

  /// Read in [initState], while there is still a ref to read it with: the
  /// cleanup runs from [dispose], where the element is already going away and
  /// a lazy read would throw.
  late final AttachmentRepository _attachments;
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  String _category = CostCategories.registration;

  /// Registration and insurance come round every year; the reminder is offered
  /// by default because forgetting one is what costs a household money.
  bool _remindAgain = true;

  /// Set once the household has answered the reminder question in this sheet,
  /// by toggling the switch or by changing the category — which re-asks it.
  /// After that nothing may overwrite the answer.
  bool _remindAgainChosen = false;

  /// Which country's vignette, and how long it was bought for. Both null until
  /// chosen, and deliberately without defaults: a day and a year are both
  /// ordinary purchases, and guessing would put a wrong expiry in the planner.
  ///
  /// The country comes first because it decides which periods exist. Offering
  /// Czechia a one-day vignette, or Slovenia a two-month one, would invent
  /// products that cannot be bought.
  VignetteCountry? _country;
  VignetteValidity? _validity;
  bool _busy = false;
  bool _amountMissing = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _attachments = ref.read(attachmentRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      // Opened from a due reminder that knows what is being paid.
      _category = widget.initialCategory ?? _category;
      _remindAgain = _defaultRemindAgain(_category);
      return;
    }
    _date = existing.date.toLocal();
    _category = existing.category;
    _amount.text = existing.amount.toStringAsFixed(2);
    _notes.text = existing.notes ?? '';
    // Both were being asked for and then thrown away: the sheet computed the
    // expiry from them and never wrote either onto the entry, so an edit
    // restored the amount and the notes and silently forgot what the vignette
    // was even for.
    _country = existing.vignetteCountry;
    _validity = existing.vignetteValidity;
    // Only until the real answer arrives: the category default is a guess
    // about a household that has not decided yet, and this one has.
    _remindAgain = _defaultRemindAgain(_category);
    _seedRemindFromStandingRule();
  }

  /// Whether a reminder is wanted is the household's answer, not the
  /// category's default — and on an edit that answer already exists, as a rule
  /// standing on the vehicle. Seeding the switch from the default instead
  /// showed a vignette as "off" however deliberately it had been switched on,
  /// and [_scheduleRecurringReminder] then wrote that back: correcting an
  /// amount retracted a reminder nobody asked to retract.
  ///
  /// Read rather than watched, and applied only if the household has not
  /// answered in the meantime — a slow load must never land on top of a switch
  /// somebody has just touched.
  Future<void> _seedRemindFromStandingRule() async {
    final List<ReminderRule> rules;
    try {
      rules = await ref.read(reminderRulesProvider(_vehicleId).future);
    } catch (_) {
      // The switch keeps the category default. A reminder that cannot be read
      // is not worth failing an edit of an expense over.
      return;
    }
    if (!mounted || _remindAgainChosen) {
      return;
    }
    setState(() => _remindAgain = rules.any(_isStandingFor(_category)));
  }

  /// An active one-off rule raised by [category]. Completed rules are settled
  /// history, not a preference to restore.
  static bool Function(ReminderRule) _isStandingFor(String category) {
    return (rule) =>
        rule.active &&
        rule.oneTime &&
        RecurringCosts.categoryFor(rule.serviceTypeKey) == category;
  }

  /// Registration and insurance recur for every car, every year, near
  /// certainly, which is why forgetting one is worth a nag. A vignette recurs
  /// only if the trip does, and the common case is a single crossing — buy it
  /// once, use it once. Defaulting both alike to "remind me" turned one
  /// Slovenian week into a standing reminder nobody asked for, so this is the
  /// one category that starts opted out rather than in.
  static bool _defaultRemindAgain(String category) =>
      category != CostCategories.vignette;

  @override
  void dispose() {
    if (widget.existing == null && !_saved && !_attemptedWrite) {
      // Fire and forget: the sheet is going, and there is nothing left to
      // report a failed cleanup to.
      unawaited(
        discardUnsavedAttachments(
          _attachments,
          pending: _uploads,
          kind: AttachmentEntryKind.cost,
          entryId: _newId,
        ),
      );
    }
    _amount.dispose();
    _amountFocus.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: _date,
      firstDate: firstLoggableDate(_date),
      // Already happened: dating it ahead is a typo, not a plan.
      lastDate: lastLoggableDate(_date),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  /// The field takes a sum as well as a number: a parking ticket extended by
  /// an hour is `2*1.50`, and that arithmetic belongs to the app rather than
  /// to whoever is standing at the meter.
  double? _parseAmount() => evaluateAmount(_amount.text);

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _amountMissing = false;
      _failure = null;
    });

    final amount = _parseAmount();
    if (amount == null || amount < 0) {
      setState(() => _amountMissing = true);
      return;
    }

    setState(() => _busy = true);

    final entry = CostEntry(
      id: widget.existing?.id ?? _newId,
      vehicleId: _vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      category: _category,
      amount: amount,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdBy: widget.existing?.createdBy ?? '',
      // Null for anything that is not a vignette, even if a stale value is
      // still sitting in `_country`/`_validity` from before the category was
      // switched away — the dropdown's onChanged already clears both, but the
      // entry itself should not depend on that happening first.
      vignetteCountry: _category == CostCategories.vignette ? _country : null,
      vignetteValidity: _category == CostCategories.vignette ? _validity : null,
    );

    try {
      // Set before the write, not after: a write that times out may still
      // have landed, and the cleanup must not delete the receipts off an
      // entry that exists.
      _attemptedWrite = true;
      if (widget.existing == null) {
        await writeNew(() => ref.read(costRepositoryProvider).add(entry));
      } else {
        await writeWithTimeout(ref.read(costRepositoryProvider).update(entry));
      }
      // Immediately after the entry write: the reminder below is its own
      // request and its own failure.
      _saved = true;
      await _scheduleRecurringReminder(entry);
      ref.invalidate(costEntriesProvider(_vehicleId));
      if (mounted) {
        // Like the fill-up: a sheet that closes in silence read as a
        // save that may not have happened.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.costSaved)));
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.from(error);
        _busy = false;
      });
    }
  }

  /// A yearly obligation gets a one-off reminder dated a year on, so the next
  /// registration or insurance renewal turns up in the planner rather than in
  /// a letter. An expense that does not return, or a reminder the user
  /// unticked, creates none.
  Future<void> _scheduleRecurringReminder(CostEntry entry) async {
    final next = RecurringCosts.nextDue(
      category: entry.category,
      paidOn: entry.date,
      validity: _validity,
    );
    if (next == null) {
      return;
    }
    try {
      // Clear the outstanding one before scheduling the next, or the two sit
      // side by side and the old one stays due forever. Run unconditionally,
      // not only when [_remindAgain] is on: it is also the only way to
      // *retract* a reminder. A vignette entry saved while the switch still
      // defaulted on left an active "expires" rule behind, and turning the
      // switch off on a later edit has to be able to undo that — not merely
      // skip scheduling a new one, which would leave the stale rule standing
      // and the household still told a payment is late for a trip that is
      // long over.
      //
      // Paying is what settles these. The reminder was raised by a *cost* —
      // a vignette bought, a registration paid — but only logging a *service*
      // completed it, so the way to clear "Vignette expires" was to record
      // having serviced a vignette, which is not a thing anyone does. Buying
      // the next one is the act that ends the old obligation, and this is it.
      await writeWithTimeout(
        ref.read(maintenanceRepositoryProvider).completeOneTimeRules(
          _vehicleId,
          [next.serviceTypeKey],
        ),
      );
      if (_remindAgain) {
        await writeWithTimeout(
          ref
              .read(maintenanceRepositoryProvider)
              .upsertRule(
                ReminderRule(
                  id: '',
                  vehicleId: _vehicleId,
                  serviceTypeKey: next.serviceTypeKey,
                  oneTime: true,
                  dueDate: next.dueDate,
                  issuedDate: entry.date,
                ),
              ),
        );
      }
      ref
        ..invalidate(reminderRulesProvider(_vehicleId))
        ..invalidate(vehicleProjectionsProvider(_vehicleId));
    } catch (_) {
      // The cost is what the user came to record; the reminder is a courtesy
      // on top of it. Failing the save over one would invite a retry, and a
      // second copy of the expense.
    }
  }

  /// Clears the reminder this expense raised, if it is still standing.
  ///
  /// [_submit] was careful about the rule — clear the outstanding one, write
  /// the next, invalidate both providers — and deleting touched none of it, so
  /// removing the vignette you logged by mistake left "Vignette expires" in the
  /// planner with no cost behind it. Worse, the only thing that settles such a
  /// rule is buying the next one or logging a *service* of a thing nobody
  /// services, so the orphan was effectively permanent.
  ///
  /// Matched on the day the rule was issued, not merely on the category:
  /// [_scheduleRecurringReminder] stamps the rule with the cost's own date, so
  /// a household that buys a second vignette and then deletes the first, older
  /// entry keeps the reminder the newer purchase raised.
  ///
  /// A rule written before [ReminderRule.issuedDate] existed carries none and
  /// so matches nothing. That is the safe direction: the reminder outlives the
  /// expense, exactly as it did before this existed, rather than a delete
  /// clearing one it cannot prove it raised.
  Future<void> _retractOwnReminder() async {
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    try {
      final rules = await ref.read(reminderRulesProvider(_vehicleId).future);
      final mine = rules
          .where(_isStandingFor(existing.category))
          .where((rule) => rule.issuedDate == existing.date)
          .map((rule) => rule.serviceTypeKey)
          .toSet()
          .toList(growable: false);
      if (mine.isEmpty) {
        return;
      }
      await writeWithTimeout(
        ref
            .read(maintenanceRepositoryProvider)
            .completeOneTimeRules(_vehicleId, mine),
      );
      ref
        ..invalidate(reminderRulesProvider(_vehicleId))
        ..invalidate(vehicleProjectionsProvider(_vehicleId));
    } catch (_) {
      // The same reasoning as scheduling one: the row is what the user asked
      // to be rid of, and it is already gone. Failing the delete over the
      // courtesy on top of it would invite a retry of something that has
      // already happened.
    }
  }

  /// Deleting goes through the same busy/failure path as saving: a delete the
  /// server rejects has to say so in the sheet, not throw out of the button's
  /// callback where nothing is listening.
  Future<void> _delete() async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref.read(costRepositoryProvider).delete(widget.existing!.id);
      await sweepAttachments(
        ref.read(attachmentRepositoryProvider),
        kind: AttachmentEntryKind.cost,
        entryId: widget.existing!.id,
      );
      await _retractOwnReminder();
      ref.invalidate(costEntriesProvider(_vehicleId));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.from(error);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );

    // A bill paid once and logged twice — a save retried after a timeout, or
    // a second tap on a slow button — leaves two rows nothing distinguishes.
    // Weeks later they read as two real payments and the total they inflate
    // is believed, so the only cheap moment to say so is this one.
    final typedAmount = _parseAmount();
    final duplicate =
        typedAmount != null &&
        duplicatesExistingCost(
          existing:
              ref.watch(costEntriesProvider(_vehicleId)).value ??
              const <CostEntry>[],
          editingId: widget.existing?.id,
          date: DateTime.utc(_date.year, _date.month, _date.day),
          category: _category,
          amount: typedAmount,
        );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DiscardGuard(
                alsoDirty: () => _attachedAny,
                controllers: [_amount, _notes],
              ),
              Text(
                widget.existing == null ? l10n.costAdd : l10n.costEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SheetVehicleRow(
                vehicleId: _vehicleId,
                // Locked once a receipt is on it; see the fill-up sheet.
                onSwitch: widget.existing == null && !_attachedAny
                    ? (id) => setState(() => _vehicleId = id)
                    : null,
                lockedNote: widget.existing == null && _attachedAny
                    ? l10n.sheetVehicleLockedByFile
                    : null,
              ),
              const SizedBox(height: GarageTokens.space2),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.costDate),
                subtitle: Text(format.formatShortDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              LabeledField(
                label: l10n.costCategory,
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  items: [
                    for (final key in CostCategories.all)
                      DropdownMenuItem(
                        value: key,
                        child: Text(costCategoryLabel(l10n, key)),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _category = value ?? _category;
                    // Country and validity mean nothing outside a vignette,
                    // and carrying them across a category switch would save a
                    // Slovenian week onto a car wash. The reminder default
                    // moves with the category too, the same way it would for
                    // a freshly opened sheet — a household is choosing what
                    // this row is, not editing a choice they already made.
                    if (_category != CostCategories.vignette) {
                      _country = null;
                      _validity = null;
                    }
                    _remindAgain = _defaultRemindAgain(_category);
                    _remindAgainChosen = true;
                  }),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.costAmount,
                child: TextField(
                  // Every other sheet keys its numeric field for exactly this
                  // reason: a test that finds the box by position finds a
                  // different one the moment a field is added above it.
                  key: const Key('cost-amount'),
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    suffixIcon: unitSuffix(context, format.currencySymbol),
                    errorText: _amountMissing ? l10n.costAmountRequired : null,
                    // A warning, not a refusal: two parking charges of the
                    // same size on one day are ordinary, and the household is
                    // the one who knows which this is.
                    helperText: duplicate ? l10n.costDuplicateWarning : null,
                    helperMaxLines: 2,
                    helperStyle: TextStyle(color: context.tokens.danger),
                  ),
                  // The only numeric field in the app that left its error
                  // standing while the household was busy correcting it.
                  onChanged: (_) => setState(() => _amountMissing = false),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelNotes,
                child: TextField(controller: _notes),
              ),
              // A vignette is bought for a period rather than for a year, so
              // the expiry is asked for instead of assumed. Croatia charges at
              // the barrier, which is why this appears exactly when a
              // household is recording a trip abroad.
              if (_category == CostCategories.vignette) ...[
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.costVignetteCountry,
                  child: DropdownButtonFormField<VignetteCountry>(
                    initialValue: _country,
                    isExpanded: true,
                    // Sorted by the localized name, so the menu reads
                    // alphabetically to whoever is looking at it.
                    items: [
                      for (final country
                          in [...VignetteCountry.values]..sort(
                            (a, b) => vignetteCountryLabel(
                              l10n,
                              a,
                            ).compareTo(vignetteCountryLabel(l10n, b)),
                          ))
                        DropdownMenuItem(
                          value: country,
                          child: Text(vignetteCountryLabel(l10n, country)),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _country = value;
                      // The old choice may not be sold here: Switzerland has
                      // only the annual, and Czechia no one-day at all.
                      if (value != null &&
                          !value.products.contains(_validity)) {
                        _validity = null;
                      }
                    }),
                  ),
                ),
                if (_country case final country?) ...[
                  // Straight to the state seller. Searching for these lands on
                  // resellers charging a markup often enough that DARS
                  // publishes a warning about it.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => ref.read(urlOpenerProvider)(
                        Uri.parse(country.shopUrl),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(l10n.costVignetteBuy(country.operator)),
                    ),
                  ),
                  LabeledField(
                    label: l10n.costVignetteValidity,
                    child: DropdownButtonFormField<VignetteValidity>(
                      initialValue: _validity,
                      isExpanded: true,
                      items: [
                        for (final validity in country.products)
                          DropdownMenuItem(
                            value: validity,
                            child: Text(vignetteValidityLabel(l10n, validity)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _validity = value),
                    ),
                  ),
                ],
                // Shown rather than left implicit: an annual vignette in
                // Austria, Switzerland and Hungary runs to a fixed date in the
                // new year instead of twelve months from purchase, so the
                // reader needs to see the date this worked out and can edit the
                // reminder if their own product differs.
                if (RecurringCosts.nextDue(
                      category: _category,
                      paidOn: _date,
                      validity: _validity,
                    )
                    case final due?) ...[
                  const SizedBox(height: GarageTokens.space2),
                  Text(
                    l10n.costVignetteExpires(format.formatDate(due.dueDate)),
                    style: TextStyle(color: context.tokens.muted),
                  ),
                ],
              ],
              if (RecurringCosts.nextDue(
                    category: _category,
                    paidOn: _date,
                    validity: _validity,
                  ) !=
                  null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remindAgain,
                  onChanged: (value) => setState(() {
                    _remindAgain = value;
                    _remindAgainChosen = true;
                  }),
                  title: Text(
                    _category == CostCategories.vignette
                        ? l10n.costVignetteRemind
                        : l10n.costRemindNextYear,
                  ),
                ),
              if (_failure != null) ...[
                const SizedBox(height: GarageTokens.space3),
                Text(
                  // The entry is not lost, which is the first thing a person
                  // whose save failed wants to know.
                  '${failureMessage(l10n, _failure!)} ${l10n.saveEntryKept}',
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              const SizedBox(height: GarageTokens.space4),
              // Offered while the entry is still being typed: the id
              // exists before the row does, and anything attached to a
              // sheet that is then abandoned is taken back down.
              EntryAttachments(
                vehicleId: _vehicleId,
                kind: AttachmentEntryKind.cost,
                entryId: widget.existing?.id ?? _newId,
                onUpload: (upload) {
                  _uploads.add(upload);
                  setState(() => _attachedAny = true);
                },
              ),
              const SizedBox(height: GarageTokens.space5),
              AmountCalculatorDock(
                fields: [AmountField(_amount, _amountFocus)],
                format: format,
              ),
              const SizedBox(height: GarageTokens.space2),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: BusyLabel(busy: _busy, child: Text(l10n.commonSave)),
              ),
              StillSavingNote(busy: _busy),
              if (widget.existing != null) ...[
                const SizedBox(height: GarageTokens.space3),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.tokens.danger,
                  ),
                  label: Text(
                    l10n.commonDelete,
                    style: TextStyle(color: context.tokens.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
