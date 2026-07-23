import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/failure_message.dart';
import '../data/household_repository.dart';
import '../providers/household_providers.dart';
import '../providers/member_providers.dart';

class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  String? _inviteCode;
  bool _busy = false;

  Future<void> _createInvite() async {
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null) {
      return;
    }
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final code =
          await ref.read(householdRepositoryProvider).createInvite(household.id);
      if (mounted) {
        setState(() => _inviteCode = code);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyCode(String code) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.householdCopied)),
      );
    }
  }

  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.householdLeave),
        content: Text(l10n.householdLeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.householdLeave),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(householdRepositoryProvider).leave(household.id);
      ref.invalidate(currentHouseholdProvider);
      if (mounted) {
        context.go('/');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage(l10n, AppFailure.from(error))),
          ),
        );
      }
    }
  }

  String _roleLabel(AppLocalizations l10n, String role) =>
      role == 'admin' ? l10n.householdRoleAdmin : l10n.householdRoleMember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final members = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.householdTitle)),
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Text(
            l10n.householdMembers,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: GarageTokens.space2),
          AsyncValueView<List<HouseholdMember>>(
            value: members,
            onRetry: () => ref.invalidate(membersProvider),
            data: (list) => Column(
              children: [
                for (final member in list)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(member.displayName),
                      subtitle: Text(_roleLabel(l10n, member.role)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: GarageTokens.space4),
          if (_inviteCode != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(GarageTokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.householdInviteCreated(_inviteCode!)),
                    Text(
                      l10n.householdInviteExpires,
                      style: TextStyle(color: context.tokens.muted),
                    ),
                    const SizedBox(height: GarageTokens.space2),
                    Row(
                      children: [
                        SelectableText(
                          _inviteCode!,
                          style: GarageTheme.numeric(
                            Theme.of(context).textTheme.headlineSmall!,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _copyCode(_inviteCode!),
                          icon: const Icon(Icons.copy),
                          label: Text(l10n.householdCopyCode),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _createInvite,
            icon: const Icon(Icons.person_add_alt),
            label: Text(l10n.householdInvite),
          ),
          const SizedBox(height: GarageTokens.space6),
          OutlinedButton.icon(
            onPressed: _leave,
            icon: Icon(Icons.logout, color: context.tokens.danger),
            label: Text(
              l10n.householdLeave,
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}
