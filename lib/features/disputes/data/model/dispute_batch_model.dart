import 'package:intl/intl.dart';

class DisputeBatch {
  final String? objectId;
  final String batchNumber; // e.g. DC262394004038000
  final String fileName;
  final int transactionCount;
  final double totalDebitAmount;
  final double totalCreditAmount;
  final bool isBalanced;
  final String status; // NEW, ASSIGNED, AUTHORIZED, REJECTED
  final String madeBy;
  final DateTime madeAt;
  final String? assignedTo; // Checker username
  final String? assignedBy; // Manager username
  final DateTime? assignedAt;
  final String? authorizedBy; // Checker username who approved
  final DateTime? authorizedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? checkerComment;

  DisputeBatch({
    this.objectId,
    required this.batchNumber,
    required this.fileName,
    required this.transactionCount,
    required this.totalDebitAmount,
    required this.totalCreditAmount,
    required this.isBalanced,
    required this.status,
    required this.madeBy,
    required this.madeAt,
    this.assignedTo,
    this.assignedBy,
    this.assignedAt,
    this.authorizedBy,
    this.authorizedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.checkerComment,
  });

  // Duration calculations
  Duration? get durationMadeToAssigned {
    if (assignedAt == null) return null;
    return assignedAt!.difference(madeAt);
  }

  Duration? get durationAssignedToAuthorized {
    if (assignedAt == null || authorizedAt == null) return null;
    return authorizedAt!.difference(assignedAt!);
  }

  Duration? get totalTurnaroundDuration {
    final end = authorizedAt ?? rejectedAt;
    if (end == null) return null;
    return end.difference(madeAt);
  }

  // Active elapsed time since creation (for pending/in-progress batches)
  Duration get currentElapsedTime => DateTime.now().difference(madeAt);

  String formatDuration(Duration? d) {
    if (d == null) return '-';
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours.remainder(24)}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  factory DisputeBatch.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is Map && val['__type'] == 'Date' && val['iso'] != null) {
        return DateTime.tryParse(val['iso'].toString()) ?? DateTime.now();
      }
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is Map && val['__type'] == 'Date' && val['iso'] != null) {
        return DateTime.tryParse(val['iso'].toString());
      }
      return DateTime.tryParse(val.toString());
    }

    return DisputeBatch(
      objectId: json['objectId'],
      batchNumber: json['batchNumber'] ?? json['ticketId'] ?? json['batchId'] ?? '',
      fileName: json['fileName'] ?? 'Dispute_Batch_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt',
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      totalDebitAmount: (json['totalDebitAmount'] as num?)?.toDouble() ?? 0.0,
      totalCreditAmount: (json['totalCreditAmount'] as num?)?.toDouble() ?? 0.0,
      isBalanced: json['isBalanced'] ?? false,
      status: json['status'] ?? 'NEW',
      madeBy: json['madeBy'] ?? '',
      madeAt: parseDate(json['madeAt'] ?? json['createdAt']),
      assignedTo: json['assignedTo'],
      assignedBy: json['assignedBy'],
      assignedAt: parseNullableDate(json['assignedAt']),
      authorizedBy: json['authorizedBy'],
      authorizedAt: parseNullableDate(json['authorizedAt']),
      rejectedBy: json['rejectedBy'],
      rejectedAt: parseNullableDate(json['rejectedAt']),
      checkerComment: json['checkerComment'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (objectId != null) 'objectId': objectId,
      'batchNumber': batchNumber,
      'fileName': fileName,
      'transactionCount': transactionCount,
      'totalDebitAmount': totalDebitAmount,
      'totalCreditAmount': totalCreditAmount,
      'isBalanced': isBalanced,
      'status': status,
      'madeBy': madeBy,
      'madeAt': {'__type': 'Date', 'iso': madeAt.toIso8601String()},
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (assignedBy != null) 'assignedBy': assignedBy,
      if (assignedAt != null) 'assignedAt': {'__type': 'Date', 'iso': assignedAt!.toIso8601String()},
      if (authorizedBy != null) 'authorizedBy': authorizedBy,
      if (authorizedAt != null) 'authorizedAt': {'__type': 'Date', 'iso': authorizedAt!.toIso8601String()},
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (rejectedAt != null) 'rejectedAt': {'__type': 'Date', 'iso': rejectedAt!.toIso8601String()},
      if (checkerComment != null) 'checkerComment': checkerComment,
    };
  }

  DisputeBatch copyWith({
    String? objectId,
    String? batchNumber,
    String? fileName,
    int? transactionCount,
    double? totalDebitAmount,
    double? totalCreditAmount,
    bool? isBalanced,
    String? status,
    String? madeBy,
    DateTime? madeAt,
    String? assignedTo,
    String? assignedBy,
    DateTime? assignedAt,
    String? authorizedBy,
    DateTime? authorizedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? checkerComment,
  }) {
    return DisputeBatch(
      objectId: objectId ?? this.objectId,
      batchNumber: batchNumber ?? this.batchNumber,
      fileName: fileName ?? this.fileName,
      transactionCount: transactionCount ?? this.transactionCount,
      totalDebitAmount: totalDebitAmount ?? this.totalDebitAmount,
      totalCreditAmount: totalCreditAmount ?? this.totalCreditAmount,
      isBalanced: isBalanced ?? this.isBalanced,
      status: status ?? this.status,
      madeBy: madeBy ?? this.madeBy,
      madeAt: madeAt ?? this.madeAt,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      authorizedBy: authorizedBy ?? this.authorizedBy,
      authorizedAt: authorizedAt ?? this.authorizedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      checkerComment: checkerComment ?? this.checkerComment,
    );
  }
}
