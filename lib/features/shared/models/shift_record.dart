class ShiftRecord {
  final int id;
  final int userId;
  final String userName;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalRevenue;
  final int totalReceipts;

  ShiftRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.startTime,
    required this.endTime,
    required this.totalRevenue,
    required this.totalReceipts,
  });

  bool get isActive => endTime == null;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
}

