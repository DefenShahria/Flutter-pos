import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/transfer_status.dart';
import '../../providers/transfer_provider.dart';
import '../widgets/transfer_tile.dart';

class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfers')),
      body: Consumer<TransferProvider>(
        builder: (context, provider, _) {
          final transfers = provider.transfers;
          if (transfers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_disabled, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No transfers yet', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: transfers.length,
            itemBuilder: (context, index) =>
                TransferTile(item: transfers[index]),
          );
        },
      ),
      bottomNavigationBar: const _BottomBar(),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final activeCount = context.select((TransferProvider p) => p.activeCount);
    final completedCount = context.select((TransferProvider p) =>
        p.transfers.where((t) => t.status == TransferStatus.completed).length);

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Chip(
              icon: Icons.hourglass_empty, label: 'Active', count: activeCount),
          _Chip(icon: Icons.check_circle, label: 'Done', count: completedCount),
          if (completedCount > 0)
            TextButton(
              onPressed: () =>
                  context.read<TransferProvider>().clearCompleted(),
              child: const Text('Clear Completed'),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _Chip({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text('$label: $count'),
      ],
    );
  }
}
