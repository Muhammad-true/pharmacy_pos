/// Модель рекламы/баннера для приложения
class Advertisement {
  final int id;
  final String title;
  final String? description;
  final String? mediaUrl;
  final String mediaType; // 'gif', 'video', 'image'
  final String? discountText;
  final String? qrCode;
  final String? qrCodeText;
  final bool isActive;
  final int displayOrder;
  final int? createdByUserId;
  final int? targetUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Advertisement({
    required this.id,
    required this.title,
    this.description,
    this.mediaUrl,
    this.mediaType = 'gif',
    this.discountText,
    this.qrCode,
    this.qrCodeText,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdByUserId,
    this.targetUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Создать из JSON
  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: json['mediaType'] as String? ?? 'gif',
      discountText: json['discountText'] as String?,
      qrCode: json['qrCode'] as String?,
      qrCodeText: json['qrCodeText'] as String?,
      isActive: (json['isActive'] as bool?) ?? true,
      displayOrder: (json['displayOrder'] as int?) ?? 0,
      createdByUserId: json['createdByUserId'] as int?,
      targetUserId: json['targetUserId'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Преобразовать в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'discountText': discountText,
      'qrCode': qrCode,
      'qrCodeText': qrCodeText,
      'isActive': isActive,
      'displayOrder': displayOrder,
      'createdByUserId': createdByUserId,
      'targetUserId': targetUserId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Создать копию с изменениями
  Advertisement copyWith({
    int? id,
    String? title,
    String? description,
    String? mediaUrl,
    String? mediaType,
    String? discountText,
    String? qrCode,
    String? qrCodeText,
    bool? isActive,
    int? displayOrder,
    int? createdByUserId,
    int? targetUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Advertisement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      discountText: discountText ?? this.discountText,
      qrCode: qrCode ?? this.qrCode,
      qrCodeText: qrCodeText ?? this.qrCodeText,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      targetUserId: targetUserId ?? this.targetUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

