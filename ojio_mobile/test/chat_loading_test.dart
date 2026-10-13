import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ojio_mobile/models/models.dart';
import 'package:ojio_mobile/screens/chat_screen.dart';
import 'package:ojio_mobile/services/api_service.dart';
import 'package:ojio_mobile/services/auth_service.dart';

class PendingChatApi extends ApiService {
  final response = Completer<ChatThreadModel?>();
  int calls = 0;
  @override
  Future<ChatThreadModel?> fetchChatMessages(int threadId) {
    calls++;
    return response.future;
  }
}

void main() {
  final auth = AuthService();
  var sessionNumber = 0;
  ChatThreadModel thread({bool empty = false}) => ChatThreadModel(
    id: 321,
    listingId: 5,
    buyerId: 10,
    sellerId: 20,
    lastMessageAt: DateTime(2026),
    messages: empty
        ? []
        : [
            ChatMessageModel(
              id: 1,
              chatThreadId: 321,
              senderId: 20,
              message: 'Previous message',
              isRead: false,
              createdAt: DateTime(2026),
            ),
          ],
  );
  Widget screen(PendingChatApi api, {ChatThreadModel? initial}) => MaterialApp(
    home: ChatConversationScreen(
      threadId: 321,
      listingId: 5,
      otherUserName: 'Seller',
      itemTitle: 'Item',
      api: api,
      initialThread: initial,
    ),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth.onLogout = null;
    await auth.setAuth('chat-session-${++sessionNumber}', {
      'id': 10,
      'name': 'Buyer',
      'email': 'buyer@example.com',
    });
  });
  tearDown(() async {
    await auth.logout();
  });
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'first frame starts one request and shows loading, not empty chat',
    (tester) async {
      final api = PendingChatApi();
      await tester.pumpWidget(screen(api));
      expect(tester.takeException(), isNull);
      expect(api.calls, 1);
      expect(find.byKey(const Key('chat-messages-loading')), findsOneWidget);
      expect(find.text('Say hello! Start the negotiation.'), findsNothing);
      api.response.complete(thread());
      await tester.pump();
      expect(find.text('Previous message'), findsOneWidget);
      expect(find.byKey(const Key('chat-messages-loading')), findsNothing);
      await dispose(tester);
    },
  );
  testWidgets('chat-list preview remains visible while history loads', (
    tester,
  ) async {
    final api = PendingChatApi();
    await tester.pumpWidget(screen(api, initial: thread()));
    expect(find.text('Previous message'), findsOneWidget);
    expect(find.text('Say hello! Start the negotiation.'), findsNothing);
    expect(api.calls, 1);
    await dispose(tester);
    api.response.complete(thread());
  });
  testWidgets(
    'failed history fetch shows retry instead of pretending chat is empty',
    (tester) async {
      final api = PendingChatApi();
      await tester.pumpWidget(screen(api));
      api.response.complete(null);
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.text('Messages could not be loaded. Please retry.'),
        findsOneWidget,
      );
      expect(find.text('Say hello! Start the negotiation.'), findsNothing);
      await dispose(tester);
    },
  );
  testWidgets('confirmed empty conversation alone shows greeting', (
    tester,
  ) async {
    final api = PendingChatApi();
    await tester.pumpWidget(screen(api));
    api.response.complete(thread(empty: true));
    await tester.pump();
    expect(find.text('Say hello! Start the negotiation.'), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('reopening uses cached history immediately and refreshes', (
    tester,
  ) async {
    final api = PendingChatApi();
    await tester.pumpWidget(screen(api));
    api.response.complete(thread());
    await tester.pump();
    await dispose(tester);
    final refresh = PendingChatApi();
    await tester.pumpWidget(screen(refresh));
    expect(find.text('Previous message'), findsOneWidget);
    expect(refresh.calls, 1);
    await dispose(tester);
    refresh.response.complete(thread());
  });
  testWidgets(
    'new login cannot see previous session cached messages or late response',
    (tester) async {
      final api = PendingChatApi();
      await tester.pumpWidget(screen(api));
      await auth.setAuth('different-session', {
        'id': 30,
        'name': 'Other',
        'email': 'other@example.com',
      });
      api.response.complete(thread());
      await tester.pump();
      expect(find.text('Previous message'), findsNothing);
      await dispose(tester);
      final next = PendingChatApi();
      await tester.pumpWidget(screen(next, initial: thread()));
      expect(find.text('Previous message'), findsNothing);
      await dispose(tester);
      next.response.complete(null);
    },
  );
}
