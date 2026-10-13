class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final List<CategoryModel> subcategories;
  final Map<String, dynamic> customAttributesSchema;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.subcategories = const [],
    this.customAttributesSchema = const {},
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    var subs = (json['subcategories'] as List? ?? [])
        .map((s) => CategoryModel.fromJson(s is Map<String, dynamic> ? s : {}))
        .toList();

    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      icon: json['icon'],
      subcategories: subs,
      customAttributesSchema: json['custom_attributes_schema'] is Map
          ? Map<String, dynamic>.from(json['custom_attributes_schema'])
          : {},
    );
  }
}

class ListingModel {
  final int id;
  final int categoryId;
  final String? categoryName;
  final String? categorySlug;
  final String title;
  final double price;
  final String city;
  final String? locality;
  final String? description;
  final String? phoneNumber;
  final bool hidePhone;
  final bool isNegotiable;
  final bool isFeatured;
  final String? primaryImageUrl;
  final List<String> images;
  final Map<String, dynamic> attributes;
  final String? sellerName;
  final int userId;
  final String status;
  final String? rejectionReason;
  final bool sellerHasDiamondBadge;
  final bool sellerIsPremium;
  final String? sellerPremiumUntil;
  final String? sellerDiamondBadgeUntil;
  final DateTime createdAt;

  ListingModel({
    required this.id,
    this.categoryId = 0,
    this.categoryName,
    this.categorySlug,
    required this.title,
    required this.price,
    required this.city,
    this.locality,
    this.description,
    this.phoneNumber,
    this.hidePhone = false,
    this.isNegotiable = false,
    this.isFeatured = false,
    this.primaryImageUrl,
    this.images = const [],
    this.attributes = const {},
    this.sellerName,
    this.userId = 0,
    this.status = 'active',
    this.rejectionReason,
    this.sellerHasDiamondBadge = false,
    this.sellerIsPremium = false,
    this.sellerPremiumUntil,
    this.sellerDiamondBadgeUntil,
    required this.createdAt,
  });

  static String sanitizeImageUrl(
    String? url, {
    String? categorySlug,
    String? title,
  }) {
    if (url == null || url.trim().isEmpty) {
      return defaultCategoryPlaceholder(categorySlug, title: title);
    }
    final trimmed = url.trim();
    if (trimmed.startsWith('local://') ||
        (!trimmed.startsWith('http://') &&
            !trimmed.startsWith('https://') &&
            !trimmed.startsWith('data:'))) {
      return defaultCategoryPlaceholder(categorySlug, title: title);
    }
    return trimmed;
  }

  static String defaultCategoryPlaceholder(
    String? categorySlug, {
    String? title,
  }) {
    final slug = (categorySlug ?? '').toLowerCase();
    final t = (title ?? '').toLowerCase();

    if (slug.contains('car') ||
        slug.contains('vehic') ||
        t.contains('car') ||
        t.contains('sedan')) {
      return 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=800&auto=format&fit=crop&q=80';
    } else if (slug.contains('bike') ||
        slug.contains('scooter') ||
        t.contains('bike') ||
        t.contains('motorcycle')) {
      return 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800&auto=format&fit=crop&q=80';
    } else if (slug.contains('mobil') ||
        slug.contains('phone') ||
        t.contains('phone') ||
        t.contains('samsung') ||
        t.contains('iphone')) {
      return 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800&auto=format&fit=crop&q=80';
    } else if (slug.contains('elect') ||
        slug.contains('laptop') ||
        t.contains('laptop') ||
        t.contains('macbook') ||
        t.contains('computer')) {
      return 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&auto=format&fit=crop&q=80';
    } else if (slug.contains('furnit') ||
        slug.contains('home') ||
        t.contains('sofa') ||
        t.contains('bed') ||
        t.contains('chair')) {
      return 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=800&auto=format&fit=crop&q=80';
    } else if (slug.contains('estate') ||
        slug.contains('prop') ||
        t.contains('flat') ||
        t.contains('house') ||
        t.contains('plot')) {
      return 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800&auto=format&fit=crop&q=80';
  }

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    final catSlug = json['category'] is Map
        ? json['category']['slug']?.toString()
        : null;
    final itemTitle = json['title']?.toString() ?? '';

    List<String> imgList = [];
    if (json['images'] is List) {
      imgList = (json['images'] as List)
          .map((i) => i['image_path']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .map(
            (u) => sanitizeImageUrl(u, categorySlug: catSlug, title: itemTitle),
          )
          .toList();
    }

    if (imgList.isEmpty &&
        json['primary_image'] is Map &&
        json['primary_image']['image_path'] != null) {
      imgList = [
        sanitizeImageUrl(
          json['primary_image']['image_path'].toString(),
          categorySlug: catSlug,
          title: itemTitle,
        ),
      ];
    }
    final primaryUrl = imgList.isNotEmpty
        ? imgList.first
        : sanitizeImageUrl(null, categorySlug: catSlug, title: itemTitle);

    if (imgList.isEmpty) {
      imgList = [primaryUrl];
    }

    return ListingModel(
      id: json['id'] ?? 0,
      categoryId: json['category_id'] is int
          ? json['category_id']
          : (int.tryParse(json['category_id']?.toString() ?? '0') ?? 0),
      categoryName: json['category'] is Map
          ? json['category']['name']?.toString()
          : null,
      categorySlug: catSlug,
      title: itemTitle,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      city: json['city'] ?? 'Nearby',
      locality: json['locality'],
      description: json['description'],
      phoneNumber: json['phone_number'],
      hidePhone: json['hide_phone'] == 1 || json['hide_phone'] == true,
      isNegotiable: json['is_negotiable'] == 1 || json['is_negotiable'] == true,
      isFeatured: json['is_featured'] == 1 || json['is_featured'] == true,
      primaryImageUrl: primaryUrl,
      images: imgList,
      attributes: json['attributes'] is Map<String, dynamic>
          ? json['attributes']
          : {},
      sellerName: json['user'] != null
          ? json['user']['name']
          : 'OJIO Verified User',
      userId:
          (json['user_id'] ??
              (json['user'] != null ? json['user']['id'] : 0)) ??
          0,
      status: json['status']?.toString() ?? 'active',
      rejectionReason: json['rejection_reason']?.toString(),
      sellerHasDiamondBadge:
          (json['user'] is Map &&
              (json['user']['has_diamond_badge'] == 1 ||
                  json['user']['has_diamond_badge'] == true)) ||
          (json['has_diamond_badge'] == 1 || json['has_diamond_badge'] == true),
      sellerIsPremium:
          (json['user'] is Map &&
              (json['user']['is_premium'] == 1 ||
                  json['user']['is_premium'] == true)) ||
          (json['is_premium'] == 1 || json['is_premium'] == true),
      sellerPremiumUntil:
          (json['user'] is Map
                  ? json['user']['premium_until']
                  : json['premium_until'])
              ?.toString(),
      sellerDiamondBadgeUntil:
          (json['user'] is Map
                  ? json['user']['diamond_badge_until']
                  : json['diamond_badge_until'])
              ?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class BannerModel {
  final int id;
  final String title;
  final String imageUrl;
  final String? targetUrl;

  BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.targetUrl,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    String url = json['image_url']?.toString() ?? '';
    if (url.contains('1556742049-0a67c5574f73') || url.isEmpty) {
      url =
          'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&auto=format&fit=crop&q=80';
    }
    return BannerModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: url,
      targetUrl: json['target_url'],
    );
  }
}

class ChatMessageModel {
  final int id;
  final int chatThreadId;
  final int senderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.chatThreadId,
    required this.senderId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? 0,
      chatThreadId: json['chat_thread_id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      message: json['message'] ?? '',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class ChatThreadModel {
  final int id;
  final int listingId;
  final int buyerId;
  final int sellerId;
  final DateTime lastMessageAt;
  final ListingModel? listing;
  final Map<String, dynamic>? buyer;
  final Map<String, dynamic>? seller;
  final List<ChatMessageModel> messages;
  final int unreadCount;

  ChatThreadModel({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.lastMessageAt,
    this.listing,
    this.buyer,
    this.seller,
    this.messages = const [],
    this.unreadCount = 0,
  });

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    var msgs = (json['messages'] as List? ?? [])
        .map((m) => ChatMessageModel.fromJson(m))
        .toList();

    return ChatThreadModel(
      id: json['id'] ?? 0,
      listingId: json['listing_id'] ?? 0,
      buyerId: json['buyer_id'] ?? 0,
      sellerId: json['seller_id'] ?? 0,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : DateTime.now(),
      listing: json['listing'] != null
          ? ListingModel.fromJson(json['listing'])
          : null,
      buyer: json['buyer'],
      seller: json['seller'],
      messages: msgs,
      unreadCount:
          json['unread_count'] ??
          0, // Need backend support for this if we want it, otherwise we calculate manually
    );
  }
}

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final int freeAdsPosted;
  final int freeAdsLimit;
  final DateTime? freeQuotaResetsAt;
  final int paidAdsQuota;
  final bool isPremium;
  final bool hasDiamondBadge;
  final String? premiumUntil;
  final String? diamondBadgeUntil;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.freeAdsPosted = 0,
    this.freeAdsLimit = 2,
    this.freeQuotaResetsAt,
    this.paidAdsQuota = 0,
    this.isPremium = false,
    this.hasDiamondBadge = false,
    this.premiumUntil,
    this.diamondBadgeUntil,
  });

  int get freeAdsUsed =>
      freeQuotaResetsAt != null && !freeQuotaResetsAt!.isAfter(DateTime.now())
      ? 0
      : freeAdsPosted;

  bool get canPostAd => paidAdsQuota > 0 || freeAdsUsed < freeAdsLimit;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      latitude: double.tryParse('${json['latitude']}'),
      longitude: double.tryParse('${json['longitude']}'),
      freeAdsPosted: json['free_ads_posted'] ?? 0,
      freeAdsLimit: json['free_ads_limit'] ?? 2,
      freeQuotaResetsAt: DateTime.tryParse('${json['free_quota_resets_at']}'),
      paidAdsQuota: json['paid_ads_quota'] ?? 0,
      isPremium: json['is_premium'] == 1 || json['is_premium'] == true,
      hasDiamondBadge:
          json['has_diamond_badge'] == 1 || json['has_diamond_badge'] == true,
      premiumUntil: json['premium_until'],
      diamondBadgeUntil: json['diamond_badge_until'],
    );
  }
}

class PremiumPackageModel {
  final int id;
  final String key;
  final String name;
  final double price;
  final int adsLimit;
  final int durationDays;
  final String? description;
  final bool badgeEnabled;
  final bool isActive;

  PremiumPackageModel({
    required this.id,
    required this.key,
    required this.name,
    required this.price,
    required this.adsLimit,
    required this.durationDays,
    this.description,
    this.badgeEnabled = false,
    this.isActive = true,
  });

  factory PremiumPackageModel.fromJson(Map<String, dynamic> json) {
    return PremiumPackageModel(
      id: json['id'] ?? 0,
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      adsLimit: json['ads_limit'] ?? 0,
      durationDays: json['duration_days'] ?? 0,
      description: json['description'],
      badgeEnabled: json['badge_enabled'] == 1 || json['badge_enabled'] == true,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}
