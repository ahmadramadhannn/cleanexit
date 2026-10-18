import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_nav.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../../di.dart';
import '../viewmodels/accounts_cubit.dart';
import '../viewmodels/session_cubit.dart';
import '../widgets/common.dart';

/// Dashboard — the two entry points plus context about what gets watched.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // First scan only; the Accounts tab re-scans on demand.
        context.read<AccountsCubit>().load(force: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final roots = Services.settings.enabledRoots;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text(
              CeConstants.tagline,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Watch a session while it happens, or scan back in time — '
              'then keep what you need and make everything else disappear.',
              style: TextStyle(fontSize: 13.5, color: CeColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _accountsBanner(context),
            const SizedBox(height: 4),
            // IntrinsicHeight is REQUIRED here: CrossAxisAlignment.stretch
            // inside an unbounded-height ListView forces every card to try
            // to be infinitely tall, which throws during layout and leaves
            // the whole dashboard blank. IntrinsicHeight bounds the row to
            // the tallest card's intrinsic height instead.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ActionCard(
                      icon: Icons.radar,
                      title: 'Start a watched session',
                      subtitle:
                          'Begin now (optionally with a timer). CleanExit records every file that appears while you work and asks what to keep when you stop.',
                      onTap: () => _openSetup(context, SessionMode.live),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ActionCard(
                      icon: Icons.schedule,
                      title: 'Clean up past activity',
                      subtitle:
                          'Already used the PC? Pick a time range — like 11:00 to 11:25 — and CleanExit finds everything from that window.',
                      onTap: () => _openSetup(context, SessionMode.retroactive),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SectionHeader(
              'Monitored folders',
              trailing: TextButton(
                onPressed: () {}, // user switches tabs via the rail
                child: const Text('Adjust in Settings'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in roots)
                  Chip(
                    avatar: const Icon(Icons.folder_outlined,
                        size: 16, color: CeColors.accent),
                    label: Text(r.label),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            const SectionHeader('Recent sessions'),
            const SizedBox(height: 8),
            _recentSessions(context),
          ],
        ),
      ),
    );
  }

  /// Live "who is still logged in" strip. Reads the app-level AccountsCubit
  /// (first scan fired once from initState).
  Widget _accountsBanner(BuildContext context) {
    return BlocBuilder<AccountsCubit, AccountsState>(
      builder: (context, accounts) {
        if (accounts.loading && accounts.total == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Checking for signed-in browser accounts…',
                  style: TextStyle(
                      fontSize: 12, color: CeColors.textSecondary),
                ),
              ],
            ),
          );
        }
        if (accounts.signedIn.isEmpty) return const SizedBox.shrink();

        final browsers =
            accounts.signedIn.map((a) => a.browserName).toSet().toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Card(
            color: CeColors.surfaceHigh,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => AppNav.I.goTo(1),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle,
                        color: CeColors.warning, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${accounts.signedIn.length} browser account(s) are '
                            'still signed in'
                        '${browsers.isEmpty ? "" : " — ${browsers.join(", ")}"}. '
                            'Sign them out before leaving this PC.',
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: CeColors.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => AppNav.I.goTo(1),
                      child: const Text('Review'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _recentSessions(BuildContext context) {
    final recent = Services.sessions.listAll().take(3).toList();
    if (recent.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'No sessions yet. Your first cleanup will show up here.',
            style: TextStyle(color: CeColors.textSecondary, fontSize: 12.5),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final s in recent)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                s.mode == SessionMode.live
                    ? Icons.radar
                    : Icons.schedule,
                color: CeColors.accent,
              ),
              title: Text(
                '${formatRangeLabel(s.rangeStart, s.rangeEnd)}  ·  '
                '${s.cleanedPaths.length} cleaned, ${s.keptPaths.length} kept',
                style: const TextStyle(fontSize: 13.5),
              ),
              subtitle: Text(
                '${formatDateTime(s.start)}  ·  ${s.disposal.label}',
                style: const TextStyle(
                    fontSize: 11.5, color: CeColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: CeColors.textSecondary),
            ),
          ),
      ],
    );
  }

  void _openSetup(BuildContext context, SessionMode mode) {
    showDialog<void>(
      context: context,
      builder: (_) => SessionSetupDialog(mode: mode),
    );
  }
}

/// Setup dialog — duration picking (live) or time range (retroactive).
class SessionSetupDialog extends StatefulWidget {
  final SessionMode mode;

  const SessionSetupDialog({super.key, required this.mode});

  @override
  State<SessionSetupDialog> createState() => _SessionSetupDialogState();
}

class _SessionSetupDialogState extends State<SessionSetupDialog> {
  Duration? _liveDuration; // null = until I stop
  String? _livePreset;
  final _customMinutes = TextEditingController();

  // retro state
  int? _retroPresetIndex;
  DateTime? _customStart;
  DateTime? _customEnd;

  static const _livePresets = [
    (label: '15 min', duration: Duration(minutes: 15)),
    (label: '30 min', duration: Duration(minutes: 30)),
    (label: '1 hour', duration: Duration(hours: 1)),
    (label: '2 hours', duration: Duration(hours: 2)),
    (label: '4 hours', duration: Duration(hours: 4)),
  ];

  @override
  void dispose() {
    _customMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.mode == SessionMode.live;
    return AlertDialog(
      title: Text(isLive
          ? 'Start a watched session'
          : 'Clean up past activity'),
      content: SizedBox(
        width: 460,
        child: isLive ? _liveBody() : _retroBody(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canStart() ? _start : null,
          child: Text(isLive ? 'Start watching' : 'Scan range'),
        ),
      ],
    );
  }

  Widget _liveBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How long will you use the computer? '
          'When time is up, CleanExit asks what to keep.',
          style: TextStyle(fontSize: 13, color: CeColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _livePresets)
              ChoiceChip(
                label: Text(p.label),
                selected: _livePreset == p.label,
                onSelected: (_) => setState(() {
                  _livePreset = p.label;
                  _liveDuration = p.duration;
                }),
              ),
            ChoiceChip(
              label: const Text('Until I stop'),
              selected: _livePreset == 'until',
              onSelected: (_) => setState(() {
                _livePreset = 'until';
                _liveDuration = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Custom minutes:'),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _customMinutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 45'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _retroBody() {
    final now = DateTime.now();
    final presets = [
      (label: 'Last 15 min', start: now.subtract(const Duration(minutes: 15))),
      (label: 'Last 30 min', start: now.subtract(const Duration(minutes: 30))),
      (label: 'Last 1 hour', start: now.subtract(const Duration(hours: 1))),
      (label: 'Last 2 hours', start: now.subtract(const Duration(hours: 2))),
      (label: 'Last 4 hours', start: now.subtract(const Duration(hours: 4))),
      (label: 'Today so far', start: DateTime(now.year, now.month, now.day)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When did you start using the computer? CleanExit will scan '
          'everything from that moment until now.',
          style: TextStyle(fontSize: 13, color: CeColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < presets.length; i++)
              ChoiceChip(
                label: Text(presets[i].label),
                selected: _retroPresetIndex == i,
                onSelected: (_) => setState(() => _retroPresetIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickCustomRange,
              icon: const Icon(Icons.edit_calendar_outlined, size: 17),
              label: Text(_customStart == null
                  ? 'Custom range…'
                  : '${formatTime(_customStart!)} – ${formatTime(_customEnd ?? now)}'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _customStart ?? now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (date == null) return;
    if (!mounted) return;
    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customStart ?? now),
    );
    if (startTime == null) return;
    if (!mounted) return;
    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_customEnd ?? now),
    );
    if (endTime == null) return;
    setState(() {
      _customStart =
          DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);
      _customEnd = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
      if (_customEnd!.isBefore(_customStart!)) {
        _customEnd = _customEnd!.add(const Duration(days: 1));
      }
      _retroPresetIndex = null;
    });
  }

  bool _canStart() {
    if (widget.mode == SessionMode.live) {
      final custom = int.tryParse(_customMinutes.text.trim());
      return custom != null && custom > 0 || _liveDuration != null || _livePreset == 'until';
    }
    return _retroPresetIndex != null || _customStart != null;
  }

  void _start() {
    final sessionCubit = context.read<SessionCubit>();
    Navigator.of(context).pop();

    if (widget.mode == SessionMode.live) {
      final custom = int.tryParse(_customMinutes.text.trim());
      final duration = custom != null && custom > 0
          ? Duration(minutes: custom)
          : _liveDuration;
      sessionCubit.startLive(duration: duration);
    } else {
      final now = DateTime.now();
      final presets = [
        now.subtract(const Duration(minutes: 15)),
        now.subtract(const Duration(minutes: 30)),
        now.subtract(const Duration(hours: 1)),
        now.subtract(const Duration(hours: 2)),
        now.subtract(const Duration(hours: 4)),
        DateTime(now.year, now.month, now.day),
      ];
      final start =
          _customStart ?? presets[_retroPresetIndex ?? presets.length - 1];
      sessionCubit.startRetroactive(start, _customEnd ?? now);
    }
  }
}
