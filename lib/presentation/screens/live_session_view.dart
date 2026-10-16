import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/services/file_watcher_service.dart';
import '../../di.dart';
import '../viewmodels/session_cubit.dart';
import '../widgets/common.dart';

/// Live watch (workflow #1): countdown, live file-feed, stop button.
class LiveSessionView extends StatefulWidget {
  const LiveSessionView({super.key});

  @override
  State<LiveSessionView> createState() => _LiveSessionViewState();
}

class _LiveSessionViewState extends State<LiveSessionView> {
  final List<(WatchKind, String, DateTime)> _feed = [];

  @override
  void initState() {
    super.initState();
    Services.watcher.stream.listen((event) {
      if (!mounted) return;
      setState(() {
        _feed.insert(0, (event.kind, event.path, event.at));
        if (_feed.length > 7) _feed.removeLast();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        final timerEnd = state.timerEnd;
        final elapsed =
            DateTime.now().difference(state.rangeStart ?? DateTime.now());
        final total = timerEnd?.difference(state.rangeStart ?? DateTime.now());

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: CeColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'WATCHING',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: CeColors.danger,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Session started ${formatTime(state.rangeStart ?? DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CeColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          timerEnd != null
                              ? formatClock(state.remaining ?? Duration.zero)
                              : formatClock(elapsed),
                          style: CeText.mono(
                            size: 58,
                            weight: FontWeight.w800,
                            color: CeColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timerEnd != null
                              ? 'until the review prompt'
                              : 'running until you stop it',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: CeColors.textSecondary,
                          ),
                        ),
                        if (total != null) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 420,
                            child: LinearProgressIndicator(
                              value: total.inMilliseconds == 0
                                  ? null
                                  : (elapsed.inMilliseconds /
                                          total.inMilliseconds)
                                      .clamp(0.0, 1.0),
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.touch_app_outlined,
                          label: 'Files touched so far',
                          value: '${state.watchedCount}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.folder_outlined,
                          label: 'Watching folders',
                          value: '${Services.enabledRoots.length}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionHeader('Latest activity'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _feed.isEmpty
                        ? const Center(
                            child: Text(
                              'No file activity yet — download, paste or create something and it will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: CeColors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          )
                        : Card(
                            child: ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                for (final (kind, path, at) in _feed)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 5),
                                    child: Row(
                                      children: [
                                        Icon(
                                          switch (kind) {
                                            WatchKind.create =>
                                              Icons.add_circle_outline,
                                            WatchKind.modify =>
                                              Icons.edit_outlined,
                                            WatchKind.delete =>
                                              Icons.remove_circle_outline,
                                            WatchKind.move =>
                                              Icons.drive_file_move_outlined,
                                          },
                                          size: 16,
                                          color: CeColors.accent,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            path,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: CeText.mono(
                                              size: 11.5,
                                              color: CeColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatTime(at),
                                          style: CeText.mono(
                                            size: 11,
                                            color: CeColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.read<SessionCubit>().stopLive(),
                      icon: const Icon(Icons.stop),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Stop & review what to keep',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Retroactive scan progress (workflow #2 in-flight state).
class ScanProgressView extends StatelessWidget {
  const ScanProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 26),
                const Text(
                  'Scanning your folders…',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  state.rangeStart != null
                      ? 'Range: ${formatRangeLabel(state.rangeStart!, state.rangeEnd ?? DateTime.now())}'
                      : '',
                  style: CeText.mono(
                    size: 12.5,
                    color: CeColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  state.statusText ?? 'Walking Downloads, Desktop, Documents…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CeColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatCard(
                      icon: Icons.travel_explore,
                      label: 'Items scanned',
                      value: '${state.scannedCount}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
