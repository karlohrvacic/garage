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
import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/maintenance/recurring_costs.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../../domain/entities/attachment.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../settings/providers/unit_providers.dart';
import '../cost_category_labels.dart';
import '../providers/cost_providers.dart';

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
  final _amount = TextEditingController();
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
      rules = await ref.read(reminderRulesProvider(widget.vehicleId).future);
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
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  double? _parseAmount() {
    final normalized = _amount.text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
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
      id: widget.existing?.id ?? '',
      vehicleId: widget.vehicleId,
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
      if (widget.existing == null) {
        await ref.read(costRepositoryProvider).add(entry);
      } else {
        await ref.read(costRepositoryProvider).update(entry);
      }
      await _scheduleRecurringReminder(entry);
      ref.invalidate(costEntriesProvider(widget.vehicleId));
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
      await ref.read(maintenanceRepositoryProvider).completeOneTimeRules(
        widget.vehicleId,
        [next.serviceTypeKey],
      );
      if (_remindAgain) {
        await ref
            .read(maintenanceRepositoryProvider)
            .upsertRule(
              ReminderRule(
                id: '',
                vehicleId: widget.vehicleId,
                serviceTypeKey: next.serviceTypeKey,
                oneTime: true,
                dueDate: next.dueDate,
                issuedDate: entry.date,
              ),
            );
      }
      ref
        ..invalidate(reminderRulesProvider(widget.vehicleId))
        ..invalidate(vehicleProjectionsProvider(widget.vehicleId));
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
      final rules = await ref.read(
        reminderRulesProvider(widget.vehicleId).future,
      );
      final mine = rules
          .where(_isStandingFor(existing.category))
          .where((rule) => rule.issuedDate == existing.date)
          .map((rule) => rule.serviceTypeKey)
          .toSet()
          .toList(growable: false);
      if (mine.isEmpty) {
        return;
      }
      await ref
          .read(maintenanceRepositoryProvider)
          .completeOneTimeRules(widget.vehicleId, mine);
      ref
        ..invalidate(reminderRulesProvider(widget.vehicleId))
        ..invalidate(vehicleProjectionsProvider(widget.vehicleId));
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
      await _retractOwnReminder();
      ref.invalidate(costEntriesProvider(widget.vehicleId));
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
              Text(
                widget.existing == null ? l10n.costAdd : l10n.costEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space4),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    errorText: _amountMissing ? l10n.costAmountRequired : null,
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
                  failureMessage(l10n, _failure!),
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              if (widget.existing != null) ...[
                const SizedBox(height: GarageTokens.space4),
                EntryAttachments(
                  vehicleId: widget.vehicleId,
                  kind: AttachmentEntryKind.cost,
                  entryId: widget.existing!.id,
                ),
              ] else ...[
                const SizedBox(height: GarageTokens.space4),
                const AttachmentsAfterSaving(),
              ],
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(l10n.commonSave),
              ),
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
