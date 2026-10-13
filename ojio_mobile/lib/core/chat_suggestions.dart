import '../models/models.dart';

/// Local suggestions only: conversation text is never sent to an AI service.
List<String> chatSuggestions({
  required ChatThreadModel? thread,
  required int? currentUserId,
  required List<ChatMessageModel> messages,
}) {
  if (thread == null || currentUserId == null || currentUserId <= 0) return [];
  final seller = currentUserId == thread.sellerId;
  if (!seller && currentUserId != thread.buyerId) return [];
  final otherId = seller ? thread.buyerId : thread.sellerId;
  final conversation =
      messages
          .where(
            (message) =>
                message.chatThreadId == thread.id &&
                (message.senderId == currentUserId ||
                    message.senderId == otherId),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  String normalize(String text) => text
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final sent = conversation
      .where((message) => message.senderId == currentUserId)
      .map((message) => normalize(message.message))
      .toSet();
  final last = conversation.isEmpty ? null : conversation.last;
  final text = last?.senderId == otherId ? normalize(last!.message) : '';
  bool mentions(String pattern) => RegExp(pattern).hasMatch(text);
  List<String> candidates;
  if (conversation.isEmpty) {
    candidates = seller
        ? [
            'Hello! What would you like to know?',
            'Do you have any questions?',
            'Would you like more photos?',
          ]
        : [
            'Is this still available?',
            'I am interested in buying this.',
            'When can I see the item?',
          ];
  } else if (last?.senderId == currentUserId) {
    // Do not repeatedly answer an older incoming message while awaiting a reply.
    candidates = seller
        ? ['Do you have any other questions?', 'Would you like more photos?']
        : ['Could you share more details?', 'Could you send more photos?'];
  } else if (mentions(
    r'\b(sold|unavailable|not available|no longer available|not for sale)\b',
  )) {
    candidates = ['Thanks for letting me know.', 'Okay, thank you.'];
  } else if (mentions(
    r'\b(price|cost|offer|discount|negotiable|negotiate|budget|lowest|final price|how much)\b',
  )) {
    candidates = seller
        ? [
            'What price would you like to offer?',
            'Let me consider your offer.',
            'Please check the listed price.',
          ]
        : [
            'Is the price negotiable?',
            'What is your best price?',
            'Let me consider the price.',
          ];
  } else if (mentions(
    r'\b(photo|photos|picture|pictures|image|images|video)\b',
  )) {
    candidates = seller
        ? [
            'Which part would you like to see?',
            'Let me check for more photos.',
            'You can also check the listing photos.',
          ]
        : [
            'Could you show the item from another angle?',
            'Could you share a closer photo?',
            'Thank you for the photos.',
          ];
  } else if (mentions(
    r'\b(condition|damage|damaged|scratch|scratches|defect|working|warranty|repair|repaired)\b',
  )) {
    candidates = seller
        ? [
            'Which detail would you like me to check?',
            'You can inspect the item before deciding.',
            'Please check the condition details in the listing.',
          ]
        : [
            'Are there any defects or repairs?',
            'Can I check it before buying?',
            'Is everything working properly?',
          ];
  } else if (mentions(
    r'\b(location|address|where|meet|meeting|pickup|pick up|collect|visit|when|time|today|tomorrow)\b',
  )) {
    candidates = seller
        ? [
            'What time works for you?',
            'Let us arrange a public meeting place.',
            'Which day would you prefer?',
          ]
        : [
            'Where can we meet to inspect the item?',
            'What time works for you?',
            'Please confirm the pickup location.',
          ];
  } else if (mentions(
    r'\b(available|availability|interested|buy|buying|purchase)\b',
  )) {
    candidates = seller
        ? [
            'Let me confirm availability.',
            'What would you like to know about the item?',
            'Would you like to inspect the item?',
          ]
        : [
            'When can I see the item?',
            'Is the price negotiable?',
            'Could you share more details?',
          ];
  } else {
    candidates = seller
        ? [
            'What would you like to know about the item?',
            'Do you have any other questions?',
            'Would you like to inspect the item?',
          ]
        : [
            'Could you share more details?',
            'Can I inspect the item before buying?',
            'Thank you for the information.',
          ];
  }
  return candidates
      .where((suggestion) => !sent.contains(normalize(suggestion)))
      .take(3)
      .toList();
}
