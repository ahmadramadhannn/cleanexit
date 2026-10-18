import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_nav.dart';
import '../../core/theme.dart';
import '../screens/accounts_screen.dart';
import '../screens/browser_cleanup_view.dart';
import '../screens/home_screen.dart';
import '../screens/live_session_view.dart';
import '../screens/review_screen.dart';
import '../screens/session_done_view.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/trash_screen.dart';
import '../viewmodels/accounts_cubit.dart';
import '../viewmodels/history_cubit.dart';
import '../viewmodels/session_cubit.dart';
import '../viewmodels/trash_cubit.dart';

/// Root layout: a navigation rail (Sessions / Accounts / Trash / History /
/// Settings). The Sessions pane swaps between dashboard and the in-flow
/// screens depending on [SessionPhase].
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _onNavChanged() {
    if (mounted && AppNav.I.index != _index) {
      setState(() => _index = AppNav.I.index);
    }
  }

  @override
  void initState() {
    super.initState();
    AppNav.I.addListener(_onNavChanged);
  }

  @override
  void dispose() {
    AppNav.I.removeListener(_onNavChanged);
    super.dispose();
  }

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Sessions'),
    (icon: Icons.account_circle_outlined, selectedIcon: Icons.account_circle, label: 'Accounts'),
    (icon: Icons.delete_outline, selectedIcon: Icons.delete, label: 'Trash'),
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
              1 => const AccountsScreen(),
              2 => const TrashScreen(),
              3 => const HistoryScreen(),
              4 => const SettingsScreen(),
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
        AppNav.I.index = i;
        setState(() => _index = i);
        if (i == 1) context.read<AccountsCubit>().load();
        if (i == 2) context.read<TrashCubit>().refresh();
        if (i == 3) context.read<HistoryCubit>().refresh();
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
    // Direct switch — no AnimatedSwitcher here. Fading in from opacity 0
    // depends on frames being scheduled; when the pane rebuilds during a
    // busy moment the fade can stall and leave the panel permanently blank.
    final phase = context.watch<SessionCubit>().state.phase;
    return switch (phase) {
      SessionPhase.idle => const HomeScreen(),
      SessionPhase.watching => const LiveSessionView(),
      SessionPhase.scanning => const ScanProgressView(),
      SessionPhase.reviewing => const ReviewScreen(),
      SessionPhase.browserStep => const BrowserCleanupView(),
      SessionPhase.done => const SessionDoneView(),
    };
  }
}
