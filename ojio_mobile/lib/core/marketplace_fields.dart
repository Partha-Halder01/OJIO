class MarketplaceFields {
  static bool samePlace(String first, String second) {
    String normalize(String value) {
      final name = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      return const {
            'calcutta': 'kolkata',
            'bombay': 'mumbai',
            'bangalore': 'bengaluru',
            'new delhi': 'delhi',
            'madras': 'chennai',
          }[name] ??
          name;
    }

    return normalize(first).isNotEmpty && normalize(first) == normalize(second);
  }

  static List<String> brands(String category, String subtype) {
    final sub = subtype.toLowerCase();
    final all = '$category $sub'.toLowerCase();
    bool containsAny(String value, List<String> terms) =>
        terms.any(value.contains);
    if (containsAny(category, [
      'real-estate',
      'property',
      'jobs',
      'services',
    ])) {
      return [];
    }
    if (containsAny(category, ['pets', 'animals'])) {
      return containsAny(sub, ['food', 'accessor', 'care'])
          ? ['Royal Canin', 'Pedigree', 'Whiskas', 'Drools', 'Trixie', 'Other']
          : [];
    }
    if (category.contains('fashion') && sub.contains('watch')) {
      return ['Titan', 'Fastrack', 'Casio', 'Timex', 'Seiko', 'Other'];
    }
    if (sub.contains('jewellery')) {
      return ['Tanishq', 'Malabar', 'Kalyan Jewellers', 'Other'];
    }
    if (containsAny(sub, ['accessor', 'spare part'])) {
      if (containsAny(category, ['bike', 'car', 'vehicle'])) {
        return ['Bosch', 'Castrol', 'MRF', 'CEAT', 'Michelin', 'Other'];
      }
      if (containsAny(category, ['mobil', 'elect'])) {
        return ['Anker', 'Belkin', 'boAt', 'JBL', 'Logitech', 'Other'];
      }
    }
    if (containsAny(sub, ['camera', 'photograph'])) {
      return [
        'Canon',
        'Nikon',
        'Sony',
        'Fujifilm',
        'Panasonic',
        'GoPro',
        'Other',
      ];
    }
    if (containsAny(sub, ['tv', 'television', 'monitor'])) {
      return ['Samsung', 'LG', 'Sony', 'TCL', 'Hisense', 'BenQ', 'Other'];
    }
    if (containsAny(sub, ['audio', 'speaker', 'headphone'])) {
      return ['JBL', 'Sony', 'Bose', 'boAt', 'Sennheiser', 'Other'];
    }
    if (containsAny(sub, ['laptop', 'computer'])) {
      return ['HP', 'Dell', 'Lenovo', 'Apple', 'Asus', 'Acer', 'MSI', 'Other'];
    }
    if (containsAny(sub, ['tablet', 'ipad'])) {
      return ['Apple', 'Samsung', 'Lenovo', 'Xiaomi', 'Microsoft', 'Other'];
    }
    if (containsAny(sub, ['smartwatch', 'watch'])) {
      return [
        'Apple',
        'Samsung',
        'Garmin',
        'Amazfit',
        'Noise',
        'boAt',
        'Other',
      ];
    }
    if (containsAny(sub, ['iphone'])) {
      return ['Apple'];
    }
    if (containsAny(sub, ['android'])) {
      return [
        'Samsung',
        'OnePlus',
        'Xiaomi',
        'Vivo',
        'Realme',
        'Oppo',
        'Motorola',
        'Google',
        'Nothing',
        'Other',
      ];
    }
    if (containsAny(sub, ['printer'])) {
      return ['HP', 'Canon', 'Epson', 'Brother', 'Samsung', 'Other'];
    }
    if (containsAny(sub, ['tractor', 'construction vehicle'])) {
      return [
        'Mahindra',
        'John Deere',
        'Sonalika',
        'TAFE',
        'Kubota',
        'JCB',
        'Other',
      ];
    }
    if (containsAny(sub, ['gaming', 'console'])) {
      return [
        'Sony PlayStation',
        'Microsoft Xbox',
        'Nintendo',
        'Razer',
        'Other',
      ];
    }
    if (containsAny(sub, ['electric bike', 'electric scooter'])) {
      return [
        'Ola Electric',
        'Ather',
        'TVS',
        'Bajaj',
        'Hero Electric',
        'Other',
      ];
    }
    if (RegExp(r'\b(bicycles?|cycles?)\b').hasMatch(sub.replaceAll('-', ' '))) {
      return ['Hero Cycles', 'Firefox', 'Trek', 'Giant', 'Decathlon', 'Other'];
    }
    if (containsAny(sub, ['truck', 'commercial']) &&
        !category.contains('cars')) {
      return [
        'Tata Motors',
        'Ashok Leyland',
        'Mahindra',
        'Eicher',
        'BharatBenz',
        'Other',
      ];
    }
    if (containsAny(all, ['car']) && !all.contains('game')) {
      return [
        'Maruti Suzuki',
        'Hyundai',
        'Tata Motors',
        'Mahindra',
        'Honda',
        'Toyota',
        'Kia',
        'Renault',
        'Volkswagen',
        'Skoda',
        'Other',
      ];
    }
    if (containsAny(all, ['bike', 'scooter', 'motorcycle'])) {
      return [
        'Hero',
        'Honda',
        'Bajaj',
        'Royal Enfield',
        'TVS',
        'Yamaha',
        'KTM',
        'Suzuki',
        'Other',
      ];
    }
    if (containsAny(all, ['mobil', 'phone'])) {
      return [
        'Apple',
        'Samsung',
        'OnePlus',
        'Xiaomi',
        'Vivo',
        'Realme',
        'Oppo',
        'Motorola',
        'Google',
        'Nothing',
        'Other',
      ];
    }
    if (containsAny(all, [
      'appliance',
      'kitchen',
      'refrigerator',
      'washing',
      'air condition',
    ])) {
      return [
        'Samsung',
        'LG',
        'Whirlpool',
        'Haier',
        'Godrej',
        'IFB',
        'Voltas',
        'Daikin',
        'Bosch',
        'Other',
      ];
    }
    if (containsAny(all, ['furnit', 'sofa', 'bed'])) {
      return [
        'Godrej Interio',
        'IKEA',
        'Durian',
        'Nilkamal',
        'Urban Ladder',
        'Pepperfry',
        'Other',
      ];
    }
    if (containsAny(all, ['fashion', 'cloth', 'shoe'])) {
      return ['Nike', 'Adidas', 'Puma', 'Zara', 'H&M', "Levi’s", 'Other'];
    }
    if (containsAny(all, ['sport', 'fitness'])) {
      return [
        'Cosco',
        'Nivia',
        'Yonex',
        'Decathlon',
        'Nike',
        'Adidas',
        'Other',
      ];
    }
    if (containsAny(all, ['gaming'])) {
      return [
        'Sony PlayStation',
        'Microsoft Xbox',
        'Nintendo',
        'Razer',
        'Other',
      ];
    }
    if (containsAny(all, ['elect'])) {
      return ['Samsung', 'LG', 'Sony', 'Philips', 'Panasonic', 'Other'];
    }
    if (containsAny(all, ['book', 'education'])) {
      return ['Penguin', 'Oxford', 'Arihant', 'Pearson', 'Other'];
    }
    if (containsAny(all, ['agri', 'farm'])) {
      return ['Mahindra', 'John Deere', 'Sonalika', 'TAFE', 'Kubota', 'Other'];
    }
    return [];
  }

  static String titleExample(String category, String subtype) {
    final selected = '$category $subtype'.toLowerCase();
    if (selected.contains('camera')) return 'e.g. Canon EOS 200D camera';
    if (selected.contains('laptop')) return 'e.g. Dell Inspiron 15 laptop';
    if (selected.contains('tablet')) return 'e.g. Samsung Galaxy Tab';
    if (selected.contains('television') || selected.contains('tv')) {
      return 'e.g. LG 43-inch Smart TV';
    }
    if (category.contains('car')) return 'e.g. Maruti Suzuki Swift 2020';
    if (category.contains('bike')) return 'e.g. Royal Enfield Classic 350';
    if (category.contains('mobil') || category.contains('phone')) {
      return 'e.g. Samsung Galaxy S23 128GB';
    }
    if (category.contains('estate') || category.contains('property')) {
      return 'e.g. 2 BHK apartment in Salt Lake';
    }
    if (category.contains('job')) return 'e.g. Full-time sales executive';
    if (category.contains('service')) {
      return 'e.g. Home appliance repair service';
    }
    if (category.contains('furnit')) return 'e.g. Solid wood dining table';
    if (category.contains('fashion')) return 'e.g. Men’s denim jacket';
    if (category.contains('book')) return 'e.g. Class 12 mathematics textbook';
    if (category.contains('pet')) return 'Describe the pet or pet product';
    return 'Describe your ${subtype.replaceAll('-', ' ')} clearly';
  }

  static String modelExample(String category, String subtype) {
    if (subtype.contains('camera')) return 'e.g. EOS 200D';
    if (subtype.contains('laptop')) return 'e.g. Inspiron 15';
    if (subtype.contains('tablet')) return 'e.g. Galaxy Tab';
    if (category.contains('car')) return 'e.g. Swift';
    if (category.contains('bike')) return 'e.g. Classic 350';
    if (category.contains('mobil') || category.contains('phone')) {
      return 'e.g. Galaxy S23';
    }
    return 'Enter model or variant';
  }
}
