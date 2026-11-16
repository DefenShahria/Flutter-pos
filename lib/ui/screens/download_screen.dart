import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/remote_file_model.dart';
import '../../providers/remote_files_provider.dart';
import '../../providers/transfer_provider.dart';
import '../widgets/error_view.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  Future<void> _refresh() async {
    await context.read<RemoteFilesProvider>().fetchFiles();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    context.read<TransferProvider>().addListener(_onTransferChanged);
  }

  @override
  void dispose() {
    context.read<TransferProvider>().removeListener(_onTransferChanged);
    super.dispose();
  }

  void _onTransferChanged() {
    if (!mounted) return;
    if (!context.read<TransferProvider>().hasActiveTransfers) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download Files')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Consumer2<RemoteFilesProvider, TransferProvider>(
          builder: (context, filesProvider, _, __) {
            if (filesProvider.isLoading && filesProvider.files.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (filesProvider.errorMessage != null &&
                filesProvider.files.isEmpty) {
              return ErrorView(
                message: filesProvider.errorMessage!,
                onRetry: _refresh,
              );
            }

            if (filesProvider.files.isEmpty) {
              return const _EmptyView();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: filesProvider.files.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final file = filesProvider.files[index];
                return _FileTile(
                  file: file,
                  onDelete: () => _onDelete(filesProvider, file.name),
                  onDownload: () => _onDownload(file.name),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _onDelete(RemoteFilesProvider provider, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "$name" from the server?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.deleteFile(name);
  }

  void _onDownload(String fileName) {
    context.read<TransferProvider>().startDownload(fileName);
    if (mounted) Navigator.pop(context);
  }
}

class _FileTile extends StatelessWidget {
  final RemoteFileModel file;
  final VoidCallback onDelete;
  final VoidCallback onDownload;

  const _FileTile({
    required this.file,
    required this.onDelete,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.cloud_download,
            color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(file.name),
      subtitle: Text(
        '${(file.size / 1024).toStringAsFixed(1)} KB'
        '${file.modifiedAt != null ? ' · ${file.modifiedAt!.toString().substring(0, 10)}' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: onDownload,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No files available', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
