class MarketplaceLocation {
  final String city;
  final double? latitude;
  final double? longitude;
  final String? state;
  final String? country;
  const MarketplaceLocation(
    this.city, {
    this.latitude,
    this.longitude,
    this.state,
    this.country,
  });
  bool get hasCoordinates => latitude != null && longitude != null;

  static MarketplaceLocation forCity(String city) {
    final key = city.trim().toLowerCase().replaceAll(' (gps)', '');
    final coordinates = switch (key) {
      'mumbai' || 'bombay' => (19.0760, 72.8777),
      'delhi' || 'new delhi' || 'delhi ncr' => (28.6139, 77.2090),
      'bengaluru' || 'bangalore' => (12.9716, 77.5946),
      'hyderabad' => (17.3850, 78.4867),
      'pune' => (18.5204, 73.8567),
      'kolkata' || 'calcutta' => (22.5726, 88.3639),
      'chennai' || 'madras' => (13.0827, 80.2707),
      'ahmedabad' => (23.0225, 72.5714),
      'jaipur' => (26.9124, 75.7873),
      'chandigarh' => (30.7333, 76.7794),
      _ => null,
    };
    return MarketplaceLocation(
      city,
      latitude: coordinates?.$1,
      longitude: coordinates?.$2,
      state: switch (key) {
        'mumbai' || 'bombay' || 'pune' => 'Maharashtra',
        'delhi' || 'new delhi' || 'delhi ncr' => 'Delhi',
        'bengaluru' || 'bangalore' => 'Karnataka',
        'hyderabad' => 'Telangana',
        'kolkata' || 'calcutta' => 'West Bengal',
        'chennai' || 'madras' => 'Tamil Nadu',
        'ahmedabad' => 'Gujarat',
        'jaipur' => 'Rajasthan',
        'chandigarh' => 'Chandigarh',
        _ => null,
      },
      country: 'India',
    );
  }
}
