import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../../di.dart';
import '../viewmodels/review_cubit.dart';
import '../viewmodels/session_cubit.dart';
import '../widgets/disposal_chooser.dart';
import '../widgets/file_tile.dart';

/// Review what the session produced: tick the keepers, choose how the rest
/// disappears, confirm, done.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionCubit>().state;
    return BlocProvider(
      create: (_) => ReviewCubit(
        files: session.files,
        sessionId: session.sessionId ?? newSessionId(),
        disposal: Services.disposal,
        initialDisposal: Services.settings.askDisposalEachRun
            ? DisposalMethod.recycle
            : Services.settings.defaultDisposal,
      ),
      child: const _ReviewView(),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReviewCubit>();
    final sessionCubit = context.read<SessionCubit>();
    final session = sessionCubit.state;

    return Column(
      children: [
        _header(context, session),
        Expanded(
          child: BlocConsumer<ReviewCubit, ReviewState>(
            listener: (context, state) {
              // Nothing reactive yet; outcomes handled after execute().
            },
            builder: (context, state) {
              final visible = state.visible;
              return Column(
                children: [
                  _statsBar(context, state),
                  _filterBar(context, state),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_open_outlined,
                                    size: 44, color: CeColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  state.files.isEmpty
                                      ? 'Nothing found in this range.\nEither nothing happened, or the folders in Settings need adjusting.'
                                      : 'No files match the current filter.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: CeColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                            itemCount: visible.length,
                            itemBuilder: (_, i) {
                              final f = visible[i];
                              return FileTile(
                                file: f,
                                keep: state.keepPaths.contains(f.path),
                                onKeepChanged: (_) => cubit.toggleKeep(f.path),
                              );
                            },
                          ),
                  ),
                  _bottomBar(context, state, sessionCubit),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, SessionState session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.mode == SessionMode.live
                    ? 'Session review'
                    : 'Range review',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                'Range  ${formatRangeLabel(session.rangeStart ?? DateTime.now(), session.rangeEnd ?? DateTime.now())}',
                style: CeText.mono(
                  size: 12,
                  color: CeColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _confirmDiscard(context),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Discard session'),
          ),
        ],
      ),
    );
  }

  Widget _statsBar(BuildContext context, ReviewState state) {
    final toClean = state.files.length - state.keepPaths.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
      child: Row(
        children: [
          Expanded(
            child: _miniStat('Files found', '${state.files.length}'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniStat(
              'Will be cleaned',
              '$toClean  ·  ${formatBytes(state.cleanedBytes)}',
              accent: CeColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniStat('Marked to keep', '${state.keepPaths.length}',
                accent: CeColors.success),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: CeColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CeText.mono(
              size: 14,
              weight: FontWeight.w700,
              color: accent ?? CeColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar(BuildContext context, ReviewState state) {
    final cubit = context.read<ReviewCubit>();
    final roots = state.files.map((f) => f.rootLabel).toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 4),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              onChanged: cubit.setQuery,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 19),
                hintText: 'Search path…',
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownMenu<String>(
            width: 220,
            initialSelection: state.rootFilter ?? '',
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: '', label: 'All folders'),
              for (final r in roots)
                DropdownMenuEntry(value: r, label: r),
            ],
            onSelected: (v) =>
                cubit.setRootFilter((v == null || v.isEmpty) ? null : v),
          ),
          const Spacer(),
          TextButton(
            onPressed: cubit.keepNothing,
            child: const Text('Keep none'),
          ),
          TextButton(
            onPressed: cubit.keepEverything,
            child: const Text('Keep all'),
          ),
          TextButton(
            onPressed: cubit.invertKeep,
            child: const Text('Invert'),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    ReviewState state,
    SessionCubit sessionCubit,
  ) {
    final cubit = context.read<ReviewCubit>();
    final toClean = state.files.length - state.keepPaths.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
      decoration: const BoxDecoration(
        color: CeColors.bg,
        border: Border(top: BorderSide(color: CeColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT HAPPENS TO THE REST?',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
              color: CeColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DisposalChooser(
            selected: state.disposal,
            onChanged: cubit.setDisposal,
          ),
          const SizedBox(height: 6),
          disposalDescription(state.disposal),
          const SizedBox(height: 14),
          Row(
            children: [
              if (state.busy)
                Expanded(child: _busyRow(state))
              else ...[
                Expanded(
                  child: Text(
                    toClean == 0
                        ? 'Nothing selected for cleanup.'
                        : '$toClean file(s) · ${formatBytes(state.cleanedBytes)} will be '
                            '${state.disposal == DisposalMethod.recycle ? "moved to the Recycle Bin" : state.disposal == DisposalMethod.vault ? "parked in the vault" : "shredded"}.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CeColors.textSecondary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      toClean == 0 ? null : () => _confirmAndExecute(context),
                  icon: Icon(
                    switch (state.disposal) {
                      DisposalMethod.recycle => Icons.delete_outline,
                      DisposalMethod.vault => Icons.lock_clock_outlined,
                      DisposalMethod.shred =>
                        Icons.local_fire_department_outlined,
                    },
                  ),
                  label: const Text('Clean up now'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _busyRow(ReviewState state) => Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Working… ${state.current ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CeText.mono(size: 12, color: CeColors.textSecondary),
            ),
          ),
        ],
      );

  Future<void> _confirmAndExecute(BuildContext context) async {
    final cubit = context.read<ReviewCubit>();
    final state = cubit.state;
    final method = state.disposal;
    final count = state.files.length - state.keepPaths.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          switch (method) {
            DisposalMethod.recycle => 'Move $count item(s) to the Recycle Bin?',
            DisposalMethod.vault => 'Park $count item(s) in the vault?',
            DisposalMethod.shred => 'Shred $count item(s) permanently?',
          },
        ),
        content: Text(
          switch (method) {
            DisposalMethod.recycle =>
              'You can restore them from the OS trash until it gets emptied.',
            DisposalMethod.vault =>
              'They stay hidden inside CleanExit and can be restored any time from History.',
            DisposalMethod.shred =>
              'Data will be overwritten with zeroes and deleted. There is NO undo — double-check your keep list!',
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: method == DisposalMethod.shred
                ? FilledButton.styleFrom(backgroundColor: CeColors.danger)
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final outcomes = await cubit.execute();
    if (!context.mounted) return;

    final success = outcomes.where((o) => o.success).toList();
    final failures = outcomes.where((o) => !o.success).toList();
    final sessionCubit = context.read<SessionCubit>();
    final sessionId = cubit.sessionId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          failures.isEmpty
              ? 'Cleanup complete'
              : 'Cleanup finished with ${failures.length} issue(s)',
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${success.length} item(s) '
                '${method == DisposalMethod.recycle ? "moved to the Recycle Bin" : method == DisposalMethod.vault ? "parked in the vault — restore from History" : "shredded"}.',
                style: const TextStyle(fontSize: 13.5),
              ),
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Not handled:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                ...failures.take(6).map(
                      (f) => Text(
                        '• ${p.basename(f.path)} — ${f.error}',
                        style: const TextStyle(
                            fontSize: 11.5, color: CeColors.warning),
                      ),
                    ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    await sessionCubit.finishReview(
      keptPaths: state.keepPaths.toList(),
      cleanedPaths: success.map((o) => o.path).toList(),
      method: method,
      vaultDir: method == DisposalMethod.vault
          ? Services.vault.sessionDir(sessionId).path
          : null,
    );
  }

  void _confirmDiscard(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this session?'),
        content: const Text(
          'Nothing has been deleted yet — your files stay exactly where they are. '
          'The session record will be thrown away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SessionCubit>().reset();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
