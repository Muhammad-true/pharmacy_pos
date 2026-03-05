/// Модель производителя
class Manufacturer {
  final int id;
  final String name;
  final String? country; // Страна производителя
  final String? address; // Адрес производителя
  final String? phone; // Телефон производителя
  final String? email; // Email производителя

  Manufacturer({
    required this.id,
    required this.name,
    this.country,
    this.address,
    this.phone,
    this.email,
  });

  factory Manufacturer.fromJson(Map<String, dynamic> json) {
    return Manufacturer(
      id: json['id'] as int,
      name: json['name'] as String,
      country: json['country'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'address': address,
      'phone': phone,
      'email': email,
    };
  }

  /// Создать копию с обновленными полями
  Manufacturer copyWith({
    int? id,
    String? name,
    String? country,
    String? address,
    String? phone,
    String? email,
  }) {
    return Manufacturer(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }
}

