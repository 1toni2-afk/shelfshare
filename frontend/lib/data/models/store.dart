/// Datele publice ale unui cont de anticariat/librărie.
///
/// Un magazin nu e un tip separat de cont: e un user obișnuit pe care un
/// super-admin l-a marcat ca magazin (vezi StoresService pe backend). De aici
/// vin doar datele comerciale - program, adresă, livrare - afișate pe profil.
class StoreProfile {
  final String userId;
  final String displayName;
  final String? description;
  final String? address;
  final String? city;
  final String? website;
  final String? phone;
  final String? openingHours;
  final String? deliveryPolicy;

  const StoreProfile({
    required this.userId,
    required this.displayName,
    this.description,
    this.address,
    this.city,
    this.website,
    this.phone,
    this.openingHours,
    this.deliveryPolicy,
  });

  factory StoreProfile.fromJson(Map<String, dynamic> json) {
    return StoreProfile(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      openingHours: json['openingHours'] as String?,
      deliveryPolicy: json['deliveryPolicy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'description': description ?? '',
      'address': address ?? '',
      'city': city ?? '',
      'website': website ?? '',
      'phone': phone ?? '',
      'openingHours': openingHours ?? '',
      'deliveryPolicy': deliveryPolicy ?? '',
    };
  }
}

/// Un magazin așa cum îl vede panoul de admin: profilul plus contul din
/// spatele lui și cât stoc are, ca să se vadă dintr-o privire dacă importul
/// a intrat.
class StoreAccount {
  final StoreProfile profile;
  final String userId;
  final String? name;
  final String? username;
  final String email;

  /// Magazin suspendat: profilul rămâne, dar contul nu mai e tratat ca
  /// magazin și nu mai primește stoc nou.
  final bool isActive;
  final int listingsCount;

  const StoreAccount({
    required this.profile,
    required this.userId,
    required this.name,
    required this.username,
    required this.email,
    required this.isActive,
    required this.listingsCount,
  });

  factory StoreAccount.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return StoreAccount(
      profile: StoreProfile.fromJson(json),
      userId: json['userId'] as String,
      name: user['name'] as String?,
      username: user['username'] as String?,
      email: user['email'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      listingsCount: json['listingsCount'] as int? ?? 0,
    );
  }
}
