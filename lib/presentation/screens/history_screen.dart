import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../viewmodels/history_cubit.dart';

/// Every past CleanExit session, with vault restore / purge actions.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HistoryCubit>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HistoryCubit, HistoryState>(
      listener: (context, state) {
        if (state.statusText != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.statusText!)),
          );
          context.read<HistoryCubit>().clearToast();
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: CeColors.dangerDim,
            ),
          );
          context.read<HistoryCubit>().clearToast();
        }
      },
      builder: (context, state) {
        if (state.sessions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_outlined,
                    size: 46, color: CeColors.textSecondary),
                SizedBox(height: 12),
                Text(
                  'No sessions recorded yet.',
                  style: TextStyle(color: CeColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView.separated(
              padding: const EdgeInsets.all(28),
              itemCount: state.sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final record = state.sessions[i];
                return _sessionCard(context, record);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _sessionCard(BuildContext context, SessionRecord record) {
    final cubit = context.read<HistoryCubit>();
    final manifest = cubit.manifestFor(record);
    final hasVault = manifest != null && manifest.items.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  record.mode == SessionMode.live
                      ? Icons.radar
                      : Icons.schedule,
                  color: CeColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  formatRangeLabel(record.rangeStart, record.rangeEnd),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: record.status == SessionStatus.completed
                        ? CeColors.accentDim
                        : CeColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.status.label,
                    style: const TextStyle(
                        fontSize: 10.5, color: CeColors.textPrimary),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDateTime(record.start),
                  style: const TextStyle(
                      fontSize: 11.5, color: CeColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _fact(Icons.delete_outline,
                    '${record.cleanedPaths.length} cleaned'),
                _fact(Icons.inventory_2_outlined, '${record.keptPaths.length} kept'),
                _fact(Icons.data_usage_outlined,
                    formatBytes(record.bytesCleaned)),
                _fact(
                    record.disposal == DisposalMethod.recycle
                        ? Icons.delete_outline
                        : record.disposal == DisposalMethod.vault
                            ? Icons.lock_clock_outlined
                            : Icons.local_fire_department_outlined,
                    record.disposal.label),
                if (record.browsersCleaned.isNotEmpty)
                  _fact(Icons.public,
                      '${record.sitesCleared.length} browser profile(s) cleaned'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () => _showDetails(context, record),
                  child: const Text('Details'),
                ),
                if (hasVault)
                  TextButton.icon(
                    onPressed: () => cubit.restoreVault(record),
                    icon: const Icon(Icons.restore, size: 16),
                    label: Text('Restore vault (${manifest.items.length})'),
                  ),
                if (hasVault)
                  TextButton.icon(
                    onPressed: () => _confirmPurge(context, record),
                    icon: const Icon(Icons.local_fire_department_outlined,
                        size: 16, color: CeColors.danger),
                    label: const Text(
                      'Purge vault',
                      style: TextStyle(color: CeColors.danger),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete record',
                  onPressed: () => cubit.deleteRecord(record),
                  icon: const Icon(Icons.close,
                      size: 16, color: CeColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: CeColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
              fontSize: 11.5, color: CeColors.textSecondary),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context, SessionRecord record) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Session ${formatRangeLabel(record.rangeStart, record.rangeEnd)}'),
        content: SizedBox(
          width: 560,
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Cleaned'),
                    Tab(text: 'Kept'),
                  ],
                ),
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    children: [
                      _pathList(record.cleanedPaths),
                      _pathList(record.keptPaths),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _pathList(List<String> paths) {
    if (paths.isEmpty) {
      return const Center(
        child: Text(
          'Nothing here.',
          style: TextStyle(color: CeColors.textSecondary, fontSize: 12.5),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final path in paths)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              path,
              style: CeText.mono(size: 11, color: CeColors.textPrimary),
            ),
          ),
      ],
    );
  }

  void _confirmPurge(BuildContext context, SessionRecord record) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purge the vault?'),
        content: const Text(
          'Everything parked for this session will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CeColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<HistoryCubit>().purgeVault(record);
            },
            child: const Text('Purge forever'),
          ),
        ],
      ),
    );
  }
}
