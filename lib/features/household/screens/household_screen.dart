import '../../../core/widgets/dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/failure_message.dart';
import '../data/household_repository.dart';
import '../../../domain/entities/invite.dart';
import '../providers/household_providers.dart';
import '../../../core/format/unit_format.dart';
import '../../../domain/household/settlement.dart';
import '../../settings/providers/unit_providers.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../providers/member_providers.dart';
import '../providers/settlement_providers.dart';

/// Hands an invite link to whatever the platform uses to share. A seam, like
/// the URL opener: the share sheet needs a platform channel no widget test has.
typedef InviteShare = void Function(String link);

final inviteShareProvider = Provider<InviteShare>((ref) {
  return (link) {
    SharePlus.instance.share(ShareParams(text: link));
  };
});

class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  bool _busy = false;

  /// Shows a code to hand out. Reuses one that is still waiting rather than
  /// minting another: every tap used to issue a fresh code, so a household
  /// ended up with a stack of live codes it had no way to see or withdraw.
  /// Ensures a usable code exists and hands the link over.
  ///
  /// What someone wants from "Invite someone" is to give the invite to a
  /// person, not to look at it. This used to surface the code into a card
  /// above the button while the same code sat in the list below, so with a
  /// reusable code already issued the button appeared to do nothing — the card
  /// it filled in was off the top of the screen.
  Future<void> _createInvite({bool forceNew = false}) async {
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null) {
      return;
    }
    if (!forceNew) {
      final existing = Invites.reusable(
        ref.read(householdInvitesProvider).value ?? const [],
        DateTime.now().toUtc(),
      );
      if (existing != null) {
        // Reused rather than piled up, which is deliberate; see [Invites].
        _shareInviteLink(existing.code);
        return;
      }
    }
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final code = await ref
          .read(householdRepositoryProvider)
          .createInvite(household.id);
      ref.invalidate(householdInvitesProvider);
      if (mounted) {
        _shareInviteLink(code);
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

  Future<void> _revokeInvite(Invite invite) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(householdRepositoryProvider).revokeInvite(invite.id);
      ref.invalidate(householdInvitesProvider);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.householdInviteRevoked)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
        );
      }
    }
  }

  Future<void> _copyCode(String code) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.householdCopied)));
    }
  }

  Future<void> _shareInviteLink(String code) async {
    final l10n = AppLocalizations.of(context)!;
    final link = GarageLinks.invite(code).toString();
    try {
      ref.read(inviteShareProvider)(link);
    } on Object {
      // Not every platform has a share sheet — the web build in particular.
      // Falling back to the clipboard keeps the button honest rather than
      // leaving it inert.
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.householdInviteLinkCopied)));
      }
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
        actionsOverflowDirection: garageActionsOverflowDirection,
        actionsOverflowAlignment: garageActionsOverflowAlignment,
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
          SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
        );
      }
    }
  }

  Future<void> _removeMember(HouseholdMember member) async {
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null || !await confirmDelete(context) || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(householdRepositoryProvider)
          .removeMember(householdId: household.id, userId: member.userId);
      ref.invalidate(membersProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
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
    final isAdmin = ref.watch(isHouseholdAdminProvider).value ?? false;
    final currentUserId = ref.watch(currentUserIdProvider);
    final hasHousehold = ref.watch(currentHouseholdProvider).value != null;
    final invites =
        ref.watch(householdInvitesProvider).value ?? const <Invite>[];
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return GaragePageScaffold(
      title: l10n.householdTitle,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Text(
            l10n.householdMembers.toUpperCase(),
            style: GarageTheme.eyebrow(context),
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
                      // Removing somebody is an admin's to do, and never
                      // yourself: leaving is the way out of your own
                      // household.
                      trailing: isAdmin && member.userId != currentUserId
                          ? IconButton(
                              onPressed: () => _removeMember(member),
                              icon: const Icon(Icons.person_remove_outlined),
                              tooltip: l10n.householdRemoveMember,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: GarageTokens.space4),
          _SettlementCard(
            settlement: ref.watch(settlementProvider).value,
            members: members.value ?? const [],
            format: format,
          ),
          const SizedBox(height: GarageTokens.space4),
          FilledButton.icon(
            // Disabled while there is no household to invite into, rather
            // than a button that swallows the tap.
            onPressed: _busy || !hasHousehold ? null : () => _createInvite(),
            icon: const Icon(Icons.person_add_alt),
            label: Text(l10n.householdInvite),
          ),
          if (invites.isNotEmpty) ...[
            const SizedBox(height: GarageTokens.space6),
            Text(
              l10n.householdInvites.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space1),
            Text(
              l10n.householdInvitesHint,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space2),
            for (final invite in invites)
              _InviteRow(
                invite: invite,
                onCopy: () => _copyCode(invite.code),
                onShare: () => _shareInviteLink(invite.code),
                onRevoke: () => _revokeInvite(invite),
              ),
            TextButton.icon(
              onPressed: _busy ? null : () => _createInvite(forceNew: true),
              icon: const Icon(Icons.add),
              label: Text(l10n.householdInviteNew),
            ),
          ],
          const SizedBox(height: GarageTokens.space6),
          OutlinedButton.icon(
            onPressed: hasHousehold ? _leave : null,
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

/// Who has paid what into the household, and what would even it out.
///
/// Shown to everyone, not just an admin: the point is that the household can
/// see the split it is already living with.
class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.settlement,
    required this.members,
    required this.format,
  });

  final Settlement? settlement;
  final List<HouseholdMember> members;
  final UnitFormat format;

  String _name(String userId) {
    for (final member in members) {
      if (member.userId == userId) {
        return member.displayName;
      }
    }
    // Someone who has left the household still shows up in its history.
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settlement = this.settlement;
    if (settlement == null || settlement.spendByMember.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.householdSpend,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              l10n.householdSpendHint,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space3),
            for (final entry in settlement.spendByMember.entries)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space1,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_name(entry.key))),
                    Text(
                      format.formatMoney(entry.value),
                      style: GarageTheme.numeric(
                        Theme.of(context).textTheme.bodyMedium!,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Text(
              l10n.householdShareEach(format.formatMoney(settlement.fairShare)),
            ),
            const SizedBox(height: GarageTokens.space2),
            if (settlement.isSettled)
              Text(
                l10n.householdSettled,
                style: TextStyle(color: context.tokens.accent),
              )
            else
              for (final transfer in settlement.transfers)
                Text(
                  l10n.householdOwes(
                    _name(transfer.from),
                    _name(transfer.to),
                    format.formatMoney(transfer.amount),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// One issued code: what it is, whether it still works, and how to withdraw it.
class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.onCopy,
    required this.onShare,
    required this.onRevoke,
  });

  final Invite invite;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = invite.statusAt(DateTime.now().toUtc());
    final spent = status != InviteStatus.active;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        invite.code,
        style: GarageTheme.numeric(Theme.of(context).textTheme.titleMedium!)
            .copyWith(
              // A code that no longer works should not read as one that does.
              color: spent ? context.tokens.muted : null,
              decoration: spent ? TextDecoration.lineThrough : null,
            ),
      ),
      subtitle: Text(switch (status) {
        InviteStatus.active => l10n.householdInviteActive,
        InviteStatus.used => l10n.householdInviteUsed,
        InviteStatus.expired => l10n.householdInviteExpired,
      }),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == InviteStatus.active) ...[
            IconButton(
              onPressed: onShare,
              tooltip: l10n.householdShareInvite,
              icon: const Icon(Icons.ios_share),
            ),
            IconButton(
              onPressed: onCopy,
              tooltip: l10n.householdCopyCode,
              icon: const Icon(Icons.copy),
            ),
          ],
          IconButton(
            onPressed: onRevoke,
            tooltip: l10n.householdInviteRevoke,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
