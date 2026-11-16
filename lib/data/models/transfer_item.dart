import 'transfer_status.dart';
import 'transfer_type.dart';

class TransferItem {
  final String id;
  final String fileName;
  final String filePath;
  final TransferType type;
  TransferStatus status;
  int bytesTransferred;
  int totalBytes;
  DateTime createdAt;
  DateTime? updatedAt;
  DateTime? completedAt;
  String? errorMessage;

  TransferItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.type,
    this.status = TransferStatus.pending,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress =>
      totalBytes == 0 ? 0.0 : (bytesTransferred / totalBytes).clamp(0.0, 1.0);

  TransferItem copyWith({
    String? id,
    String? fileName,
    String? filePath,
    TransferType? type,
    TransferStatus? status,
    int? bytesTransferred,
    int? totalBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return TransferItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'filePath': filePath,
        'type': type.name,
        'status': status.name,
        'bytesTransferred': bytesTransferred,
        'totalBytes': totalBytes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'errorMessage': errorMessage,
      };

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      type: json['type'] != null
          ? TransferType.values.byName(json['type'] as String)
          : TransferType.upload,
      status: json['status'] != null
          ? TransferStatus.values.byName(json['status'] as String)
          : TransferStatus.pending,
      bytesTransferred: json['bytesTransferred'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  String toString() =>
      'TransferItem(id=$id, file=$fileName, status=$status, $bytesTransferred/$totalBytes)';
}
