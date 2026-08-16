import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An invite code from a link opened before the visitor had an account.
///
/// Signing in navigates away from the invite, so without somewhere to keep the
/// code the link degrades into "ask them for the code again", which is the
/// thing links exist to avoid. Held in memory only: it is wanted for the next
/// minute, not the next week, and it arrives again with the link if the app is
/// killed in between.
final pendingInviteProvider = NotifierProvider<PendingInvite, String?>(
  PendingInvite.new,
);

class PendingInvite extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String code) => state = code.toUpperCase();

  void clear() => state = null;
}
