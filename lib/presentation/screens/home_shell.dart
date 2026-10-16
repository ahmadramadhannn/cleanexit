import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../screens/browser_cleanup_view.dart';
import '../screens/home_screen.dart';
import '../screens/live_session_view.dart';
import '../screens/review_screen.dart';
import '../screens/session_done_view.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../viewmodels/history_cubit.dart';
import '../viewmodels/session_cubit.dart';

/// Root layout: a navigation rail (Sessions / History / Settings).
/// The Sessions pane swaps between dashboard and the in-flow screens
/// depending on [SessionPhase].
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Sessions'),
    (icon: Icons.history_outlined, selectedIcon: Icons.history, label: 'History'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _rail(context),
          const VerticalDivider(width: 1),
          Expanded(
            child: switch (_index) {
              1 => const HistoryScreen(),
              2 => const SettingsScreen(),
              _ => const _SessionsPane(),
            },
          ),
        ],
      ),
    );
  }

  Widget _rail(BuildContext context) {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) {
        setState(() => _index = i);
        if (i == 1) context.read<HistoryCubit>().refresh();
      },
      extended: MediaQuery.of(context).size.width >= 1050,
      minExtendedWidth: 190,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: CeColors.accentDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cleaning_services_outlined,
                  color: CeColors.accent),
            ),
            if (MediaQuery.of(context).size.width >= 1050) ...[
              const SizedBox(height: 6),
              const Text(
                'CleanExit',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: CeColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

/// Tab 0 content — driven entirely by the session flow phase.
class _SessionsPane extends StatelessWidget {
  const _SessionsPane();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (state.phase) {
            SessionPhase.idle => const HomeScreen(key: ValueKey('home')),
            SessionPhase.watching => const LiveSessionView(key: ValueKey('live')),
            SessionPhase.scanning => const ScanProgressView(key: ValueKey('scan')),
            SessionPhase.reviewing => const ReviewScreen(key: ValueKey('review')),
            SessionPhase.browserStep => const BrowserCleanupView(key: ValueKey('browser')),
            SessionPhase.done => const SessionDoneView(key: ValueKey('done')),
          },
        );
      },
    );
  }
}
