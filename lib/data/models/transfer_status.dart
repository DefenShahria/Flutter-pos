enum TransferStatus {
  pending,
  uploading,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

extension TransferStatusExtension on TransferStatus {
  bool get isActive =>
      this == TransferStatus.uploading || this == TransferStatus.downloading;

  bool get isTerminal =>
      this == TransferStatus.completed ||
      this == TransferStatus.cancelled ||
      this == TransferStatus.failed;
}
