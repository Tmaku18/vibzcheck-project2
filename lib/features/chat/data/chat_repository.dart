import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/message.dart';

/// Reads and writes on `sessions/{sessionId}/messages/*`.
///
/// Messages are append-only from the client: Firestore rules (see
/// [firestore.rules]) reject updates, so we never have to worry about
/// clients editing history after the fact. Chat is read oldest->newest and
/// capped to the most recent `limit` messages to keep demo sessions cheap.
class ChatRepository {
  ChatRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messagesRef(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages');
  }

  /// Live message list ordered oldest->newest so the UI can append at the
  /// bottom without re-sorting. A hard cap of [limit] messages protects the
  /// client from replaying thousands of lines on reconnect.
  Stream<List<Message>> watchMessages(
    String sessionId, {
    int limit = 200,
  }) {
    return _messagesRef(sessionId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((query) {
      final list = query.docs.map((d) => Message.fromFirestore(d)).toList();
      // Re-reverse so the UI gets ascending order.
      return list.reversed.toList();
    });
  }

  Future<void> sendMessage({
    required String sessionId,
    required String senderId,
    required String senderName,
    required String text,
    MessageKind kind = MessageKind.text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final doc = Message(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: trimmed,
      kind: kind,
    );
    await _messagesRef(sessionId).add(doc.toFirestore());
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(firestoreProvider));
});
