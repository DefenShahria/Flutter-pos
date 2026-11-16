import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transfer_provider.dart';
import '../screens/transfers_screen.dart';

class GlobalTransferBanner extends StatelessWidget {
  const GlobalTransferBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final activeCount = context.select((TransferProvider p) => p.activeCount);
    if (activeCount == 0) return const SizedBox.shrink();

    final items = context.watch<TransferProvider>().activeTransfers;
    int transferred = 0;
    int grandTotal = 0;
    for (final item in items) {
      transferred += item.bytesTransferred;
      grandTotal += item.totalBytes;
    }
    final overallProgress = grandTotal > 0 ? transferred / grandTotal : 0.0;

    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TransfersScreen()),
      ),
      child: Material(
        color: theme.colorScheme.primaryContainer,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$activeCount active transfer${activeCount > 1 ? 's' : ''}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.onPrimaryContainer.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.sync,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
