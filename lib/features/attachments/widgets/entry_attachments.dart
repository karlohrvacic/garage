import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/files/image_compression.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/entities/attachment.dart';
import '../data/attachment_repository.dart';
import '../providers/attachment_providers.dart';
import '../../../core/sync/queueing_attachment_repository.dart';

/// Removes whatever was attached to an entry that was never saved.
///
/// An entry's id is minted by the sheet before the entry exists, so a receipt
/// can be attached while it is still being typed. The cost of that is this:
/// a sheet closed without saving has to take the files back down, or they
/// hang off an entry nobody created and nothing will ever show them again.
///
/// Failures are swallowed deliberately. This runs as a sheet is disposed,
/// there is nothing left on screen to report to, and an orphaned file is not
/// something the household can act on.
Future<void> discardUnsavedAttachments(
  AttachmentRepository repository, {
  required AttachmentEntryKind kind,
  required String entryId,
  List<Future<void>> pending = const [],
}) async {
  try {
    // An upload still in flight would land after the query below and stay
    // there for ever: nothing lists an attachment whose entry was never
    // created, and there is no sweeper.
    await Future.wait(pending).catchError((_) => const <void>[]);
    final stranded = await repository.forEntry(kind: kind, entryId: entryId);
    for (final attachment in stranded) {
      await repository.delete(attachment);
    }
  } on Object {
    // Nothing to say and nobody to say it to.
  }
}

/// The receipts and documents kept with one entry, with a button to add
/// another. Shown inside an entry sheet, below the fields.
///
/// Works on an entry that has not been saved yet: the id is the sheet's own,
/// minted before the first keystroke, and the attachments table keys on it
/// rather than pointing at a row. A receipt photographed at the counter is
/// the moment someone wants to attach it, and a paperclip that appears only
/// on a second visit to the entry was the least findable thing in the app.
class EntryAttachments extends ConsumerStatefulWidget {
  const EntryAttachments({
    required this.vehicleId,
    required this.kind,
    required this.entryId,
    this.onUpload,
    super.key,
  });

  final String vehicleId;
  final AttachmentEntryKind kind;
  final String entryId;

  /// Called as an upload starts, with the future it runs on, so a sheet that
  /// may have to clean up after itself knows both that something was attached
  /// and when the request is done.
  final ValueChanged<Future<void>>? onUpload;

  @override
  ConsumerState<EntryAttachments> createState() => _EntryAttachmentsState();
}

class _EntryAttachmentsState extends ConsumerState<EntryAttachments> {
  bool _busy = false;
  AppFailure? _failure;

  AttachmentTarget get _target =>
      AttachmentTarget(kind: widget.kind, entryId: widget.entryId);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
      ref.invalidate(entryAttachmentsProvider(_target));
    } on AttachmentQueued {
      // Not a failure. The file is on the phone and goes up on its own, so
      // showing an error for it would be telling somebody something went
      // wrong when nothing did.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.syncPhotoQueued),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _add() async {
    final file = await ref.read(filePickerProvider)();
    if (file == null) {
      return;
    }
    final rawBytes = await file.readAsBytes();
    final bytes = compressImage(rawBytes);
    // Compression always re-encodes as JPEG, so a mismatched
    // `image/heic` or `image/png` sent alongside JPEG bytes would tell the
    // viewer the wrong thing about what it is about to open.
    final recompressed = !identical(bytes, rawBytes);
    final contentType = recompressed ? 'image/jpeg' : file.mimeType;
    if (!mounted) {
      return;
    }
    // Checked here rather than left to the server. An oversized body does not
    // earn a clean refusal — the connection is cut — so it arrives as a
    // transport error and the app told the user "no connection, check your
    // network and retry", which is both wrong and impossible to act on for a
    // file that will never fit. Phone photos are routinely over the limit.
    if (bytes.length > Attachment.maxUploadBytes) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.attachmentTooLarge(
              _megabytes(bytes.length),
              _megabytes(Attachment.maxUploadBytes),
            ),
          ),
        ),
      );
      return;
    }
    final upload = _run(() async {
      await ref
          .read(attachmentRepositoryProvider)
          .upload(
            vehicleId: widget.vehicleId,
            kind: widget.kind,
            entryId: widget.entryId,
            fileName: file.name,
            bytes: bytes,
            contentType: contentType,
          );
    });
    widget.onUpload?.call(upload);
    await upload;
  }

  /// `12.4 MB`. Not localized through the unit formatter: this is a file size,
  /// not a distance or a volume, and MB is MB in both languages.
  String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  /// Opening goes through the same failure path as everything else here: the
  /// link is signed on demand, so a network that is down fails at the tap, and
  /// an exception out of a button callback would tell the user nothing.
  Future<void> _open(Attachment attachment) async {
    await _run(() async {
      final url = await ref
          .read(attachmentRepositoryProvider)
          .viewUrl(attachment);
      await ref.read(urlOpenerProvider)(url);
    });
  }

  Future<void> _remove(Attachment attachment) async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    await _run(() => ref.read(attachmentRepositoryProvider).delete(attachment));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final attachments =
        ref.watch(entryAttachmentsProvider(_target)).value ??
        const <Attachment>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.attachmentsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.attach_file),
              tooltip: l10n.attachmentsAdd,
            ),
          ],
        ),
        for (final attachment in attachments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              attachment.isImage
                  ? Icons.image_outlined
                  : Icons.description_outlined,
              color: context.tokens.muted,
            ),
            title: Text(attachment.fileName),
            trailing: IconButton(
              onPressed: _busy ? null : () => _remove(attachment),
              icon: const Icon(Icons.close),
              tooltip: l10n.commonDelete,
            ),
            onTap: _busy ? null : () => _open(attachment),
          ),
        if (_failure != null)
          Padding(
            padding: const EdgeInsets.only(top: GarageTokens.space2),
            child: Text(
              failureMessage(l10n, _failure!),
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
      ],
    );
  }
}
