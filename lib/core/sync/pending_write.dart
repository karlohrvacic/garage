import '../errors/app_failure.dart';

/// What kind of entry is waiting to be sent.
///
/// The key is stored, deliberately not [Object.name]: renaming a Dart value
/// would otherwise reinterpret rows already sitting in a queue on somebody's
/// phone. Every stored enum in this app follows the same rule.
enum PendingWriteKind {
  fuel('fuel'),
  odometer('odometer'),

  /// The four things logged away from a good connection: a journey finished in
  /// a car park, a receipt taken at a workshop, the work that workshop did,
  /// and a rattle noticed on the way home. Fuel and readings were queued from
  /// the start because a filling station is the obvious bad-signal place; a
  /// basement workshop is the same problem and these were losing the write.
  trip('trip'),
  cost('cost'),
  service('service'),
  observation('observation'),

  /// A photo waiting to go up. Queued in its own right rather than hung off an
  /// entry, because a receipt can be attached to a fill-up that saved
  /// perfectly well an hour earlier.
  attachment('attachment');

  const PendingWriteKind(this.key);

  final String key;

  static PendingWriteKind? fromKey(String key) {
    for (final kind in values) {
      if (kind.key == key) {
        return kind;
      }
    }
    // A queue written by a newer build and opened by an older one. Dropping
    // the row loses one entry; throwing would strand the whole queue.
    return null;
  }
}

/// How many times a write is retried before the app stops carrying it.
///
/// Not a network budget — a connection failure does not count against it in
/// practice, since those are the common case and resolve on their own. This
/// catches the write that fails in some way nobody foresaw, which looks
/// retryable and is not, and which would otherwise be carried for months.
const int maxReplayAttempts = 25;

/// An entry typed while there was nothing to send it to.
///
/// It holds the row the repository would have sent, rather than the entity:
/// the mapping from entity to row already exists and is tested, and a second
/// serialisation of the same thing is a second thing to keep in step.
class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.kind,
    required this.vehicleId,
    required this.row,
    required this.queuedAt,
    this.attempts = 0,
    this.attachment,
  });

  /// The entry's own id, minted by the sheet. It is also the queue's dedupe
  /// key, which is what makes a replay idempotent and a merge into a fetched
  /// list exact rather than approximate.
  final String id;

  final PendingWriteKind kind;
  final String vehicleId;
  final Map<String, dynamic> row;

  /// When the person actually made the entry, which is also what the server
  /// row's `created_at` should say once it lands.
  final DateTime queuedAt;

  final int attempts;

  /// A photo taken with the entry, held on disk until the entry itself has
  /// landed. Null on the web, which has nowhere private to put one.
  final PendingAttachment? attachment;

  bool get exhausted => attempts >= maxReplayAttempts;

  PendingWrite withAttempt() => PendingWrite(
    id: id,
    kind: kind,
    vehicleId: vehicleId,
    row: row,
    queuedAt: queuedAt,
    attempts: attempts + 1,
    attachment: attachment,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.key,
    'vehicleId': vehicleId,
    'row': row,
    'queuedAt': queuedAt.toIso8601String(),
    'attempts': attempts,
    'attachment': attachment?.toJson(),
  };

  /// Null when the stored row cannot be understood by this build. The caller
  /// drops it rather than failing: one unreadable entry must not take the
  /// rest of somebody's unsent work with it.
  static PendingWrite? fromJson(Map<String, dynamic> json) {
    final kind = PendingWriteKind.fromKey(json['kind'] as String? ?? '');
    if (kind == null) {
      return null;
    }
    return PendingWrite(
      id: json['id'] as String,
      kind: kind,
      vehicleId: json['vehicleId'] as String,
      row: Map<String, dynamic>.from(json['row'] as Map),
      queuedAt: DateTime.parse(json['queuedAt'] as String).toUtc(),
      attempts: json['attempts'] as int? ?? 0,
      attachment: switch (json['attachment']) {
        final Map<String, dynamic> it => PendingAttachment.fromJson(it),
        _ => null,
      },
    );
  }
}

/// A file waiting to go up with its entry.
class PendingAttachment {
  const PendingAttachment({
    required this.path,
    required this.fileName,
    this.contentType,
  });

  /// Somewhere inside the app's own directory. Deleted once uploaded.
  final String path;
  final String fileName;
  final String? contentType;

  Map<String, dynamic> toJson() => {
    'path': path,
    'fileName': fileName,
    'contentType': contentType,
  };

  static PendingAttachment fromJson(Map<String, dynamic> json) =>
      PendingAttachment(
        path: json['path'] as String,
        fileName: json['fileName'] as String,
        contentType: json['contentType'] as String?,
      );
}

/// Whether a failed write should be kept for later rather than shown.
///
/// Only the two failures that mean "the network did not carry this". Anything
/// else is the server answering — a refusal, a bad value, a row that already
/// exists — and silently queueing those would turn a message the person could
/// act on into an entry that never arrives.
bool shouldQueue(AppFailure failure) =>
    failure.kind == AppFailureKind.network ||
    failure.kind == AppFailureKind.timeout;

/// What to do with a queued write after an attempt to send it failed.
enum ReplayOutcome {
  /// Still no connection. Leave it where it is.
  keep,

  /// It is already on the server. Take it off the queue.
  done,

  /// It can never succeed. Take it off the queue and tell somebody.
  discard,
}

ReplayOutcome replayOutcome(AppFailure failure) => switch (failure.kind) {
  AppFailureKind.network || AppFailureKind.timeout => ReplayOutcome.keep,
  // The entry carries its own id, so a duplicate key means the earlier
  // attempt arrived after the app stopped waiting for it. The row is there,
  // once, which is what the person wanted.
  AppFailureKind.conflict => ReplayOutcome.done,
  // The vehicle was handed to another garage, the session is gone, the row is
  // malformed. Every future attempt fails identically.
  AppFailureKind.permission ||
  AppFailureKind.auth ||
  AppFailureKind.notFound ||
  AppFailureKind.invalid => ReplayOutcome.discard,
  _ => ReplayOutcome.keep,
};
