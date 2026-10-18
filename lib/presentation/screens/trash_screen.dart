import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../viewmodels/trash_cubit.dart';

/// Trash tab — the operating system's own Recycle Bin / XDG Trash, browsed
/// straight from CleanExit: restore items, wipe them for good, or empty
/// everything with one confirmation.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TrashCubit>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrashCubit, TrashState>(
      listener: (context, state) {
        if (state.statusText != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.statusText!)),
          );
          context.read<TrashCubit>().clearToast();
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: CeColors.dangerDim,
            ),
          );
          context.read<TrashCubit>().clearToast();
        }
      },
      builder: (context, state) {
        final cubit = context.read<TrashCubit>();

        if (state.loading && state.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Trash',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${state.items.length} item(s) recoverable',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CeColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed:
                            state.loading || state.busy ? null : cubit.refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.items.isEmpty || state.busy
                            ? null
                            : () => _confirmEmpty(context),
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          size: 17,
                          color: CeColors.danger,
                        ),
                        label: const Text(
                          'Empty trash',
                          style: TextStyle(color: CeColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'The same trash your file manager uses. Items CleanExit '
                      'moves with the "Recycle Bin" option land here too.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CeColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: state.items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 46, color: CeColors.textSecondary),
                              SizedBox(height: 12),
                              Text(
                                'Trash is empty — nothing to recover or wipe.',
                                style: TextStyle(
                                    color: CeColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
                          itemCount: state.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _tile(context, state.items[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, TrashItem item) {
    final cubit = context.read<TrashCubit>();
    final state = context.watch<TrashState>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              item.isDir ? Icons.folder_outlined : Icons.insert_drive_file,
              color: CeColors.accent,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'from ${item.originalPath ?? 'unknown location'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CeText.mono(
                        size: 10.5, color: CeColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      item.deletedAt != null
                          ? 'deleted ${formatDateTime(item.deletedAt!)}'
                          : null,
                      if (item.sizeLabel.isNotEmpty) item.sizeLabel,
                    ].where((s) => s != null).join('  ·  '),
                    style: const TextStyle(
                        fontSize: 10.5, color: CeColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed:
                  state.busy ? null : () => cubit.restore(item),
              icon: const Icon(Icons.restore, size: 15),
              label: const Text('Restore'),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Delete forever',
              onPressed:
                  state.busy ? null : () => _confirmDelete(context, item),
              icon: const Icon(Icons.local_fire_department_outlined,
                  size: 18, color: CeColors.danger),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TrashItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text(
          '"${item.name}" will be wiped from the trash. This cannot be undone.',
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
              context.read<TrashCubit>().deleteForever(item);
            },
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
  }

  void _confirmEmpty(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty the trash?'),
        content: const Text(
          'Every item in the OS trash will be permanently deleted. '
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
              context.read<TrashCubit>().emptyAll();
            },
            child: const Text('Empty trash'),
          ),
        ],
      ),
    );
  }
}
