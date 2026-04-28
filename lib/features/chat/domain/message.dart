import 'package:cloud_firestore/cloud_firestore.dart';

/// Distinguishes human-written chat from system events (mood changes,
/// track-now-playing announcements, etc.). Keeping the type inline lets the
/// UI render system events with a different style without a second query.
enum MessageKind { text, system }

extension MessageKindX on MessageKind {
  String get asString => name;

  static MessageKind parse(String? raw) {
    return MessageKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => MessageKind.text,
    );
  }
}

/// Chat message persisted at `sessions/{sessionId}/messages/{messageId}`.
///
/// Kept intentionally small: a long-running session can accumulate thousands
/// of messages, and every extra field is multiplied across that collection.
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.kind = MessageKind.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final MessageKind kind;
  final DateTime? createdAt;

  bool isMine(String uid) => senderId == uid;
  bool get isSystem => kind == MessageKind.system;

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'kind': kind.asString,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return Message(
      id: snapshot.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? 'Member',
      text: (data['text'] as String?) ?? '',
      kind: MessageKindX.parse(data['kind'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
