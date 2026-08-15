import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/entities/attachment.dart';
import '../providers/attachment_providers.dart';

/// The receipts and documents kept with one entry, with a button to add
/// another. Shown inside an entry sheet, below the fields.
///
/// Only an entry that already exists can carry attachments — a file has to
/// hang off something — so entry sheets show this once the entry is saved.
class EntryAttachments extends ConsumerStatefulWidget {
  const EntryAttachments({
    required this.vehicleId,
    required this.kind,
    required this.entryId,
    super.key,
  });

  final String vehicleId;
  final AttachmentEntryKind kind;
  final String entryId;

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
    await _run(() async {
      await ref
          .read(attachmentRepositoryProvider)
          .upload(
            vehicleId: widget.vehicleId,
            kind: widget.kind,
            entryId: widget.entryId,
            fileName: file.name,
            bytes: await file.readAsBytes(),
            contentType: file.mimeType,
          );
    });
  }

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
