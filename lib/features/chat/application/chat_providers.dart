import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';

final sessionMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, sessionId) {
  return ref.watch(chatRepositoryProvider).watchMessages(sessionId);
});

/// Thin controller that injects the signed-in user's uid + display name into
/// every send so screens just call `sendMessage(text)`.
class ChatController {
  ChatController({
    required ChatRepository repository,
    required String Function() getUid,
    required String Function() getDisplayName,
  })  : _repository = repository,
        _getUid = getUid,
        _getDisplayName = getDisplayName;

  final ChatRepository _repository;
  final String Function() _getUid;
  final String Function() _getDisplayName;

  Future<void> sendText({
    required String sessionId,
    required String text,
  }) {
    return _repository.sendMessage(
      sessionId: sessionId,
      senderId: _getUid(),
      senderName: _getDisplayName(),
      text: text,
    );
  }

  Future<void> sendSystem({
    required String sessionId,
    required String text,
  }) {
    return _repository.sendMessage(
      sessionId: sessionId,
      senderId: _getUid(),
      senderName: 'System',
      text: text,
      kind: MessageKind.system,
    );
  }
}

final chatControllerProvider = Provider<ChatController>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return ChatController(
    repository: ref.watch(chatRepositoryProvider),
    getUid: () {
      final u = auth.currentUser;
      if (u == null) {
        throw StateError('ChatController used while signed out.');
      }
      return u.uid;
    },
    getDisplayName: () {
      final u = auth.currentUser;
      final name = u?.displayName?.trim();
      if (name != null && name.isNotEmpty) return name;
      return u?.email?.split('@').first ?? 'Member';
    },
  );
});
