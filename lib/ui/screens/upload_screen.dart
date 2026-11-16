import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/transfer_item.dart';
import '../../data/models/transfer_type.dart';
import '../../providers/transfer_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  PlatformFile? _pickedFile;
  bool _validating = false;
  String? _errorMessage;

  static const Set<String> _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'flv',
    'webm',
    'csv',
    'txt',
    'json',
    'xml',
    'pdf',
  };

  Future<void> _pickFile() async {
    setState(() {
      _validating = true;
      _errorMessage = null;
      _pickedFile = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() => _validating = false);
        return;
      }

      final file = result.files.first;
      if (file.path == null) {
        setState(() {
          _validating = false;
          _errorMessage = 'Could not read the selected file.';
        });
        return;
      }

      final ext = file.extension?.toLowerCase();
      if (ext != null && !_allowedExtensions.contains(ext)) {
        setState(() {
          _validating = false;
          _errorMessage = 'File type ".${ext.toUpperCase()}" is not supported.';
        });
        return;
      }

      final f = File(file.path!);
      final length = await f.length();
      if (!mounted) return;
      if (length == 0) {
        setState(() {
          _validating = false;
          _errorMessage = 'The selected file is empty.';
        });
        return;
      }

      setState(() {
        _pickedFile = file;
        _validating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _errorMessage = 'Failed to pick file: $e';
      });
    }
  }

  void _startUpload() {
    if (_pickedFile?.path == null) return;
    final file = File(_pickedFile!.path!);
    context.read<TransferProvider>().startUpload(
          file,
          _pickedFile!.name.isNotEmpty
              ? _pickedFile!.name
              : file.path.split('/').last,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Upload File')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _validating ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose File'),
            ),
            const SizedBox(height: 16),
            if (_validating)
              const Center(child: CircularProgressIndicator())
            else if (_pickedFile != null)
              _FileInfoCard(file: _pickedFile!, theme: theme)
            else if (_errorMessage != null)
              _ErrorCard(message: _errorMessage!),
            if (_pickedFile != null && !_validating) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startUpload,
                child: const Text('Upload'),
              ),
            ],
            const Spacer(),
            Consumer<TransferProvider>(
              builder: (context, provider, _) {
                final uploads = provider.transfers
                    .where((t) => t.type == TransferType.upload)
                    .toList();
                if (uploads.isEmpty) return const SizedBox.shrink();
                return _ActiveUploadCard(item: uploads.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FileInfoCard extends StatelessWidget {
  final PlatformFile file;
  final ThemeData theme;
  const _FileInfoCard({required this.file, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file,
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatBytes(file.size),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveUploadCard extends StatelessWidget {
  final TransferItem item;
  const _ActiveUploadCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.fileName,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${(item.progress * 100).toInt()}%'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: item.progress),
            const SizedBox(height: 4),
            Text(
              '${Formatters.formatBytes(item.bytesTransferred)} / ${Formatters.formatBytes(item.totalBytes)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
