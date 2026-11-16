enum TransferType { upload, download }

extension TransferTypeExtension on TransferType {
  String get label => switch (this) {
        TransferType.upload => 'Upload',
        TransferType.download => 'Download',
      };
}
