import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/transfer_status.dart';
import '../../data/models/transfer_item.dart';
import '../../providers/transfer_provider.dart';

class TransferTile extends StatelessWidget {
  final TransferItem item;

  const TransferTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(item.status, theme);
    final statusIcon = _statusIcon(item.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.fileName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(item.progress * 100).toInt()}%',
                  style:
                      theme.textTheme.labelLarge?.copyWith(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  Formatters.formatBytes(item.bytesTransferred),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  ' / ${Formatters.formatBytes(item.totalBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
              ],
            ),
            if (item.errorMessage != null &&
                item.status == TransferStatus.failed) ...[
              const SizedBox(height: 4),
              Text(
                item.errorMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (item.status == TransferStatus.completed &&
                item.filePath.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Saved: ${item.filePath}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _actionButton(
                  context,
                  icon: Icons.play_arrow,
                  label: 'Resume',
                  onTap: item.status == TransferStatus.paused
                      ? () => context.read<TransferProvider>().resume(item.id)
                      : null,
                ),
                _actionButton(
                  context,
                  icon: Icons.pause,
                  label: 'Pause',
                  onTap: item.status.isActive
                      ? () => context.read<TransferProvider>().pause(item.id)
                      : null,
                ),
                _actionButton(
                  context,
                  icon: Icons.refresh,
                  label: 'Retry',
                  onTap: item.status == TransferStatus.failed
                      ? () => context.read<TransferProvider>().retry(item.id)
                      : null,
                  color: theme.colorScheme.secondary,
                ),
                _actionButton(
                  context,
                  icon: Icons.cancel,
                  label: 'Cancel',
                  onTap: item.status.isActive ||
                          item.status == TransferStatus.pending
                      ? () => context.read<TransferProvider>().cancel(item.id)
                      : null,
                  color: theme.colorScheme.error,
                ),
                if (item.status == TransferStatus.completed)
                  _actionButton(
                    context,
                    icon: Icons.open_in_new,
                    label: 'Open',
                    onTap: () => OpenFilex.open(item.filePath),
                    color: theme.colorScheme.tertiary,
                  ),
                if (item.status.isTerminal)
                  _actionButton(
                    context,
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    onTap: () =>
                        context.read<TransferProvider>().remove(item.id),
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color ?? theme.colorScheme.primary),
      label: Text(label,
          style: TextStyle(
              color: color ?? theme.colorScheme.primary, fontSize: 12)),
    );
  }

  Color _statusColor(TransferStatus status, ThemeData theme) {
    return switch (status) {
      TransferStatus.uploading ||
      TransferStatus.downloading =>
        theme.colorScheme.primary,
      TransferStatus.paused => theme.colorScheme.onSurfaceVariant,
      TransferStatus.completed => Colors.green,
      TransferStatus.failed ||
      TransferStatus.cancelled =>
        theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
  }

  IconData _statusIcon(TransferStatus status) {
    return switch (status) {
      TransferStatus.uploading => Icons.cloud_upload_outlined,
      TransferStatus.downloading => Icons.cloud_download_outlined,
      TransferStatus.paused => Icons.pause_circle_outline,
      TransferStatus.completed => Icons.check_circle_outline,
      TransferStatus.failed => Icons.error_outline,
      TransferStatus.cancelled => Icons.cancel_outlined,
      _ => Icons.help_outline,
    };
  }
}
