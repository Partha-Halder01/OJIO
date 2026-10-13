import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

enum LegalDocument {
  terms('Terms & Conditions'),
  privacy('Privacy Policy');

  const LegalDocument(this.title);
  final String title;
}

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.document, this.api});

  final LegalDocument document;
  final ApiService? api;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  Map<String, dynamic>? _serverDocument;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final document = await (widget.api ?? ApiService()).fetchLegalDocument(
        widget.document.name,
      );
      if (document['content'] is! String ||
          (document['content'] as String).trim().isEmpty ||
          document['slug'] != widget.document.name) {
        throw const FormatException('Invalid legal document');
      }
      if (mounted) {
        setState(() {
          _serverDocument = document;
          _offline = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _serverDocument == null
        ? widget.document == LegalDocument.terms
              ? _terms
              : _privacy
        : <(String, String)>[('', _serverDocument!['content'] as String)];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          _serverDocument?['title']?.toString() ?? widget.document.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('legal-document-scroll'),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_offline)
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Latest content could not be loaded. Showing the built-in draft.',
                          ),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  if (_serverDocument == null ||
                      _serverDocument!['is_draft'] == true)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Draft for client review\n'
                        'Business identity, contact details, retention periods and '
                        'refund terms must be confirmed before public release.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          height: 1.5,
                          color: const Color(0xFF0D1B2A),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  for (final section in sections) ...[
                    if (section.$1.isNotEmpty) ...[
                      Text(
                        section.$1,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D1B2A),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SelectableText(
                      section.$2,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        height: 1.6,
                        color: const Color(0xFF455468),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _terms = <(String, String)>[
  (
    '1. About OJIO',
    'OJIO is a classifieds marketplace that helps buyers discover listings and '
        'contact sellers. Sellers provide the items, descriptions and prices. '
        'An OJIO listing is not a guarantee of ownership, authenticity, condition '
        'or availability. Buyers and sellers are responsible for agreeing on '
        'their item transaction, inspection, delivery and payment.',
  ),
  (
    '2. Your account',
    'Provide accurate account and contact information and keep your password '
        'and login access private. Do not impersonate another person, use '
        'someone else’s contact details or create accounts to evade restrictions. '
        'You must sign in to use the marketplace and publish an ad. '
        'Tell support if you suspect unauthorised account use.',
  ),
  (
    '3. Listing responsibly',
    'Only advertise items or services you are entitled to offer. Use the '
        'correct category, honest photos, an accurate price and a clear '
        'description of condition and defects. Do not post stolen or counterfeit '
        'goods, unlawful or restricted products, fraudulent offers, abusive '
        'content, spam or material that infringes another person’s rights. '
        'Remove or mark a listing sold when it is no longer available.',
  ),
  (
    '4. Chat and safe trading',
    'Use chat and seller contact details only for genuine marketplace enquiries. '
        'Do not harass users, send scams or collect their information for '
        'unrelated purposes. Inspect items before paying and meet in a safe '
        'public place. Never share passwords, OTPs or payment PINs. OJIO does '
        'not provide escrow or guarantee payments made directly to a seller.',
  ),
  (
    '5. Moderation',
    'Listings may be reviewed, rejected or removed for policy violations. '
        'Account access may be restricted for misuse. Report suspicious listings '
        'or conduct through the available reporting or support options. '
        'Contact support if you believe a moderation decision is incorrect.',
  ),
  (
    '6. Free posting and premium packages',
    'Free posting is subject to the quota and reset period shown in the app. '
        'If your free allowance is exhausted, you can wait for its reset or '
        'purchase an available package. Check the displayed price, ad allowance, '
        'validity and benefits before paying. Premium or Diamond badges indicate '
        'an active eligible paid package; they do not independently verify a '
        'seller’s identity or an item’s quality. Badges end when eligibility expires.',
  ),
  (
    '7. Wallet and online payments',
    'The OJIO wallet holds service credits for eligible OJIO premium purchases, '
        'not for buying listed goods from other users. It is not a bank account '
        'or a seller-payout service. Razorpay processes online payments. Wallet '
        'credits and paid benefits require server-confirmed payment; opening or '
        'closing checkout is not proof of payment. Failed or cancelled payments '
        'must not grant credits or benefits. Wallet purchases require sufficient '
        'available balance. Test-mode payments are not real payments.',
  ),
  (
    '8. Payment problems and refunds',
    'If a payment is debited but the wallet or package is not updated, check '
        'its status and contact support with the order or transaction reference. '
        'Do not send your payment PIN, OTP or full card details. Any correction '
        'must follow verification of the payment and existing credit or benefits '
        'to avoid duplicate awards. The client’s refund and cancellation terms '
        'are awaiting confirmation; this draft does not establish a refund '
        'deadline or a no-refund rule. Applicable consumer rights are not waived.',
  ),
  (
    '9. Privacy and service availability',
    'Read the Privacy Policy for information about account details, listings, '
        'location, chat, payments and notifications. Network outages, maintenance '
        'or third-party service failures can temporarily affect features. '
        'No wording here guarantees uninterrupted service or excludes rights '
        'and obligations that applicable law does not allow to be excluded.',
  ),
  (
    '10. Questions and updates',
    'Use the Help & Support section for the support information available in '
        'this build. The operator’s legal name, verified contact and final '
        'terms will be added after client confirmation. Review the updated '
        'terms when a new version is published.',
  ),
];

const _privacy = <(String, String)>[
  (
    '1. Scope',
    'This policy describes data handled by the OJIO marketplace app and its '
        'backend. It covers browsing, account access, listings, chat, location, '
        'wallet and premium purchases, ads and push notifications. The '
        'operator’s legal identity and verified privacy contact are awaiting '
        'client confirmation in this review draft.',
  ),
  (
    '2. Information you provide',
    'Depending on the features you use, OJIO receives your name, email address, '
        'phone number, profile photo, city and account credentials; listing '
        'titles, descriptions, category, price, photos and location; chat '
        'messages; and payment, wallet and premium transaction records. '
        'Support or reports may include information you choose to provide. '
        'Avoid putting sensitive documents or financial credentials in '
        'photos, listings or messages.',
  ),
  (
    '3. Location and permissions',
    'When you choose automatic location detection and grant permission, '
        'location coordinates and detected city or area are used for your '
        'selected location and nearby listings. You can select a location '
        'manually instead and change permissions in device settings. Listing '
        'location information may be visible to other users. Photo or camera '
        'access supports uploading images when you choose to do so.',
  ),
  (
    '4. Why information is used',
    'Information is used to manage accounts, display and search listings, '
        'find nearby items, connect buyers with sellers, deliver chat messages, '
        'review content, prevent misuse, confirm payments and maintain wallet '
        'and premium records. Device and diagnostic information may be handled '
        'by the integrated services to operate their features and investigate '
        'delivery or service errors.',
  ),
  (
    '5. What other users can see',
    'Listing photos and descriptions, seller display information, listing '
        'location and contact details made available by the app can be seen '
        'by people viewing an ad. Messages are sent to the other chat '
        'participant and stored on the backend. Do not treat chat as '
        'end-to-end encrypted. Authorised administrators may access information '
        'needed for moderation, support and payment investigation.',
  ),
  (
    '6. Sign-in, notifications and advertising',
    'Google Sign-In supplies account identity information when you choose '
        'that method. Firebase Cloud Messaging uses a device registration '
        'token and notification payloads to deliver OJIO notifications. '
        'Notification permissions and lock-screen previews are controlled '
        'by your device; previews may expose message content to someone '
        'looking at the device. Google AdMob supplies ads and may process '
        'device identifiers, ad interactions and diagnostic information '
        'according to its settings and policies. Current test ads are for '
        'development and do not imply paid ad revenue.',
  ),
  (
    '7. Payments and service providers',
    'Razorpay handles payment checkout and payment-method information. '
        'OJIO keeps order and payment references, amounts, status and '
        'wallet or package records to reconcile purchases. OJIO does not '
        'ask you to send payment PINs or OTPs to support. Hosting, database '
        'and the integrated Google services process information needed '
        'for their functions under their own terms and privacy practices.',
  ),
  (
    '8. Security',
    'Account access and server permissions are used to restrict protected '
        'features, and passwords are stored as hashes rather than readable '
        'passwords on the backend. No system can guarantee absolute security. '
        'Protect your account credentials and notify support of suspected '
        'misuse. This policy does not claim that SMS verification is already '
        'enabled or that every seller is identity-verified.',
  ),
  (
    '9. Retention and deletion',
    'Account, listing, chat and transaction records are stored by the backend '
        'to operate the service. The client must confirm retention periods '
        'and the account/data deletion process before public release. '
        'Financial, fraud-investigation or legally required records may '
        'need separate retention rules. Logging out removes local account '
        'access but does not delete backend records. No automatic deletion '
        'deadline is promised in this draft.',
  ),
  (
    '10. Your choices and questions',
    'You can edit supported profile information, choose a city manually, '
        'manage your listings and adjust notification or device permissions. '
        'For privacy questions, consult Help & Support for available contact '
        'information. A verified privacy contact and a clear account/data '
        'deletion route must be supplied before public release. This policy '
        'will be updated when confirmed practices or app features change.',
  ),
];
