import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibzcheck/features/chat/data/chat_repository.dart';
import 'package:vibzcheck/features/chat/domain/message.dart';

void main() {
  const sessionId = 'session-chat';
  late FakeFirebaseFirestore firestore;
  late ChatRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = ChatRepository(firestore);
  });

  test('sendMessage writes a doc with sender metadata', () async {
    await repo.sendMessage(
      sessionId: sessionId,
      senderId: 'u1',
      senderName: 'Alice',
      text: 'hello world',
    );

    final snap = await firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .get();
    expect(snap.docs, hasLength(1));
    final data = snap.docs.single.data();
    expect(data['senderId'], 'u1');
    expect(data['senderName'], 'Alice');
    expect(data['text'], 'hello world');
    expect(data['kind'], 'text');
  });

  test('sendMessage with blank text is ignored', () async {
    await repo.sendMessage(
      sessionId: sessionId,
      senderId: 'u1',
      senderName: 'Alice',
      text: '   ',
    );
    final snap = await firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .get();
    expect(snap.docs, isEmpty);
  });

  test('system messages are distinguishable by kind', () async {
    await repo.sendMessage(
      sessionId: sessionId,
      senderId: 'u1',
      senderName: 'System',
      text: 'Mood set to chill',
      kind: MessageKind.system,
    );
    final snap = await firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .get();
    expect(snap.docs.single.data()['kind'], 'system');
  });

  test('watchMessages returns messages in ascending (oldest-first) order',
      () async {
    await repo.sendMessage(
      sessionId: sessionId,
      senderId: 'u1',
      senderName: 'Alice',
      text: 'first',
    );
    // Small gap so the server timestamps differ.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.sendMessage(
      sessionId: sessionId,
      senderId: 'u2',
      senderName: 'Bob',
      text: 'second',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.sendMessage(
      sessionId: sessionId,
      senderId: 'u1',
      senderName: 'Alice',
      text: 'third',
    );

    final messages = await repo.watchMessages(sessionId).first;
    expect(messages.map((m) => m.text).toList(), ['first', 'second', 'third']);
  });

  test('Message.isMine correctly identifies the current user', () {
    const m = Message(
      id: 'm1',
      senderId: 'u1',
      senderName: 'Alice',
      text: 'hi',
    );
    expect(m.isMine('u1'), isTrue);
    expect(m.isMine('u2'), isFalse);
  });

  test('Message.isSystem reflects kind', () {
    const text = Message(
      id: 'a',
      senderId: 'u1',
      senderName: 'Alice',
      text: 'hi',
    );
    const system = Message(
      id: 'b',
      senderId: 'u1',
      senderName: 'System',
      text: 'hi',
      kind: MessageKind.system,
    );
    expect(text.isSystem, isFalse);
    expect(system.isSystem, isTrue);
  });
}
