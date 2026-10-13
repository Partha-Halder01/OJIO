import 'package:flutter_test/flutter_test.dart';
import 'package:ojio_mobile/core/chat_suggestions.dart';
import 'package:ojio_mobile/models/models.dart';

void main() {
  final thread = ChatThreadModel(
    id: 1,
    listingId: 5,
    buyerId: 10,
    sellerId: 20,
    lastMessageAt: DateTime(2026),
  );
  ChatMessageModel message(
    int id,
    int sender,
    String text, {
    int threadId = 1,
  }) => ChatMessageModel(
    id: id,
    chatThreadId: threadId,
    senderId: sender,
    message: text,
    isRead: true,
    createdAt: DateTime(2026),
  );
  List<String> replies(int user, List<ChatMessageModel> messages) =>
      chatSuggestions(thread: thread, currentUserId: user, messages: messages);

  test('opening suggestions differ for buyer and seller', () {
    expect(replies(10, []), contains('Is this still available?'));
    expect(replies(20, []), contains('Hello! What would you like to know?'));
    expect(replies(20, []), isNot(contains('I am interested in buying this.')));
  });
  test('unknown user and unloaded thread get no role guesses', () {
    expect(replies(30, []), isEmpty);
    expect(
      chatSuggestions(thread: null, currentUserId: 10, messages: []),
      isEmpty,
    );
    expect(
      chatSuggestions(thread: thread, currentUserId: null, messages: []),
      isEmpty,
    );
  });
  test('availability response does not falsely promise availability', () {
    final result = replies(20, [message(1, 10, 'Is this still available?')]);
    expect(result, contains('Let me confirm availability.'));
    expect(result, isNot(contains('Yes, it is available.')));
    expect(
      replies(10, [message(1, 20, 'Yes it is available')]),
      contains('When can I see the item?'),
    );
  });
  test(
    'negotiation suggestions match both roles without accepting an offer',
    () {
      expect(
        replies(20, [message(1, 10, 'Can you discount the price?')]),
        contains('Let me consider your offer.'),
      );
      expect(
        replies(10, [message(1, 20, 'The price is 5000')]),
        contains('Is the price negotiable?'),
      );
    },
  );
  test('condition, photos and meeting messages change replies', () {
    expect(
      replies(20, [message(1, 10, 'Any scratches?')]),
      contains('Which detail would you like me to check?'),
    );
    expect(
      replies(10, [message(1, 20, 'It is working')]),
      contains('Are there any defects or repairs?'),
    );
    expect(
      replies(20, [message(1, 10, 'Send photos please')]),
      contains('Which part would you like to see?'),
    );
    expect(
      replies(10, [message(1, 20, 'Here are the photos')]),
      contains('Could you share a closer photo?'),
    );
    expect(
      replies(20, [message(1, 10, 'Where can we meet?')]),
      contains('Let us arrange a public meeting place.'),
    );
    expect(
      replies(10, [message(1, 20, 'Tomorrow for pickup?')]),
      contains('What time works for you?'),
    );
  });
  test(
    'sold or unavailable takes priority over available and price keywords',
    () {
      for (final text in [
        'Not available at this price',
        'Already sold',
        'No longer available',
      ]) {
        final result = replies(10, [message(1, 20, text)]);
        expect(result, contains('Thanks for letting me know.'));
        expect(result, isNot(contains('When can I see the item?')));
      }
    },
  );
  test(
    'latest message wins even after four messages and out of order input',
    () {
      final result = replies(20, [
        message(5, 10, 'Where can we meet?'),
        message(1, 10, 'Is this available?'),
        message(2, 20, 'Let me check'),
        message(3, 10, 'What is the price?'),
        message(4, 20, 'Check listing'),
      ]);
      expect(result, contains('What time works for you?'));
    },
  );
  test('outgoing messages stop stale incoming replies and repeats', () {
    final result = replies(20, [
      message(1, 10, 'Is this available?'),
      message(2, 20, 'DO YOU HAVE ANY OTHER QUESTIONS?'),
    ]);
    expect(result, isNot(contains('Let me confirm availability.')));
    expect(result, isNot(contains('Do you have any other questions?')));
    expect(result, contains('Would you like more photos?'));
  });
  test('unrelated thread and sender do not affect suggestions', () {
    expect(
      replies(10, [
        message(1, 99, 'sold'),
        message(2, 20, 'sold', threadId: 9),
      ]),
      replies(10, []),
    );
  });
  test('unrecognized text uses neutral role-aware fallback', () {
    expect(
      replies(10, [message(1, 20, 'नमस्ते')]),
      contains('Could you share more details?'),
    );
    expect(
      replies(20, [message(1, 10, 'Hello!')]),
      contains('What would you like to know about the item?'),
    );
  });
}
