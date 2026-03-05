class Client {
  final int id;
  final String name;
  final String? phone;
  final String? qrCode;
  final double bonuses;
  final double discountPercent;
  final int? createdByUserId; // ID кассира, создавшего клиента
  final String? createdByUserName; // Имя кассира (не сохраняется в БД, только для отображения)
  final DateTime? createdAt; // Дата создания
  final DateTime? updatedAt; // Дата обновления

  Client({
    required this.id,
    required this.name,
    this.phone,
    this.qrCode,
    this.bonuses = 0.0,
    this.discountPercent = 0.0,
    this.createdByUserId,
    this.createdByUserName,
    this.createdAt,
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      qrCode: json['qrCode'] as String?,
      bonuses: (json['bonuses'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount'] as num?)?.toDouble() ?? 0.0,
      createdByUserId: json['createdByUserId'] as int?,
      createdByUserName: json['createdByUserName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'qrCode': qrCode,
      'bonuses': bonuses,
      'discount': discountPercent,
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

