import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_nav.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../../di.dart';
import '../viewmodels/browser_cubit.dart';
import '../viewmodels/session_cubit.dart';

/// Optional second step after file review: log the session's websites out
/// by clearing their cookies (and optionally the history rows in range).
class BrowserCleanupView extends StatelessWidget {
  const BrowserCleanupView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionCubit>().state;
    final rangeStart = session.rangeStart ?? DateTime.now().subtract(const Duration(hours: 1));
    final rangeEnd = session.rangeEnd ?? DateTime.now();
    final sessionId = session.sessionId ?? newSessionId();

    return BlocProvider(
      create: (_) => BrowserCubit(
        detector: Services.browserDetector,
        chromium: Services.chromium,
        preferredBrowserIds: Set<String>.from(
          Services.settings.preferredBrowsers,
        ),
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        sessionId: sessionId,
      )..load(),
      child: const _BrowserBody(),
    );
  }
}

class _BrowserBody extends StatelessWidget {
  const _BrowserBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BrowserCubit, BrowserState>(
      listener: (context, state) {
        if (state.error != null && !state.busy) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: CeColors.dangerDim),
          );
        }
      },
      builder: (context, state) {
        final sessionCubit = context.read<SessionCubit>();
        final hasResults = state.outcomes != null;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account cleanup',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Optional — sign the session\'s websites out of '
                            'the browsers you picked in Settings → Preferred '
                            'browsers.',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: CeColors.textSecondary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => sessionCubit.recordBrowserStep(skipped: true),
                        child: const Text('Skip this step'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (state.detecting)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.noBrowsersSelected)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const Icon(Icons.manage_accounts_outlined,
                                size: 40, color: CeColors.accent),
                            const SizedBox(height: 12),
                            const Text(
                              'You have not chosen any browsers to watch yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: CeColors.textSecondary,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pick your browsers in Settings → Preferred '
                              'browsers — the cleanup step only touches the '
                              'ones you chose.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: CeColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => AppNav.I.goTo(4),
                                  icon: const Icon(Icons.settings_outlined,
                                      size: 16),
                                  label: const Text('Choose browsers'),
                                ),
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: () => sessionCubit
                                      .recordBrowserStep(skipped: true),
                                  child: const Text('Skip and finish'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (state.detected.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const Icon(Icons.public_off_outlined,
                                size: 40, color: CeColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text(
                              'None of the browsers you picked is installed '
                              'on this machine (or it keeps no readable '
                              'profile data).',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: CeColors.textSecondary,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  sessionCubit.recordBrowserStep(skipped: true),
                              child: const Text('Finish session'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final app in state.detected)
                            _browserCard(context, app),
                          const SizedBox(height: 10),
                          _optionsRow(context, state),
                        ],
                      ),
                    ),
                  if (state.busy)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            state.statusText ?? 'Working…',
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: CeColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasResults
                              ? 'Done. Browser databases were backed up to the vault before any change.'
                              : 'Removing a site\'s cookies is what actually logs you out. Backups are kept automatically.',
                          style: const TextStyle(
                              fontSize: 12, color: CeColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!hasResults)
                        FilledButton.icon(
                          onPressed: state.busy || state.selectedDomains.isEmpty
                              ? null
                              : () => _execute(context),
                          icon: const Icon(Icons.logout),
                          label: Text(
                            'Log out ${state.selectedDomains.length} site(s)',
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: () => sessionCubit
                              .recordBrowserStep(
                            sites: state.outcomes!,
                            browsers: state.detected
                                .map((a) => a.displayName)
                                .toList(),
                            historyCleared: state.historyRemoved > 0,
                          ),
                          child: const Text('Finish session'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _browserCard(BuildContext context, BrowserApp app) {
    final cubit = context.read<BrowserCubit>();
    final state = context.watch<BrowserState>();
    final id = app.defId.name;
    final sites = state.sites[id] ?? const <SiteActivity>[];
    final isScanned = state.scanned.contains(id);
    final isActive = state.activeBrowserId == id;
    final running = state.running[id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              if (!isScanned) {
                cubit.inspect(app);
              } else {
                cubit.selectBrowser(id);
              }
            },
            leading: const Icon(Icons.public, color: CeColors.accent),
            title: Text(
              app.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${app.profiles.length} profile(s) · '
              '${isScanned ? "${sites.length} site(s) with session activity" : "not scanned yet"}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (running)
                  const Tooltip(
                    message: 'Browser is running — close it before cleanup',
                    child: Icon(Icons.error_outline,
                        color: CeColors.danger, size: 20),
                  ),
                const SizedBox(width: 8),
                Icon(
                  isActive
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: CeColors.textSecondary,
                ),
              ],
            ),
          ),
          if (isActive && isScanned) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: cubit.selectAllDomains,
                        child: const Text('Select all'),
                      ),
                      TextButton(
                        onPressed: cubit.clearDomainSelection,
                        child: const Text('Select none'),
                      ),
                      const Spacer(),
                      Text(
                        '${sites.where((s) => state.selectedDomains.contains(s.domain)).length} selected',
                        style: const TextStyle(
                            fontSize: 12, color: CeColors.textSecondary),
                      ),
                    ],
                  ),
                  if (sites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'No site activity found in this time range.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: CeColors.textSecondary),
                      ),
                    )
                  else
                    ...sites.map(
                      (s) => CheckboxListTile(
                        dense: true,
                        value: state.selectedDomains.contains(s.domain),
                        onChanged: (_) => cubit.toggleDomain(s.domain),
                        title: Text(
                          s.domain,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${s.cookieCount} cookie(s)'
                          '${s.visitCount > 0 ? " · ${s.visitCount} visit(s)" : ""}'
                          '${s.lastVisit != null ? " · last ${formatTime(s.lastVisit!)}" : ""}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionsRow(BuildContext context, BrowserState state) {
    final cubit = context.read<BrowserCubit>();
    return Card(
      child: SwitchListTile(
        value: state.clearHistory,
        onChanged: (_) => cubit.toggleClearHistory(),
        title: const Text(
          'Also clear history entries from this session',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Visits, searches and downloads from the time range are removed from browser history.',
          style: TextStyle(fontSize: 11.5),
        ),
      ),
    );
  }

  Future<void> _execute(BuildContext context) async {
    final cubit = context.read<BrowserCubit>();
    final state = cubit.state;
    final running =
        state.detected.where((a) => state.running[a.defId.name] ?? false);

    if (running.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Close the browser first'),
          content: Text(
            '${running.map((a) => a.displayName).join(", ")} is still running. '
            'Quit it completely (including the tray icon), then press Retry.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log out ${state.selectedDomains.length} site(s)?',
        ),
        content: const Text(
          'All cookies for the selected sites will be deleted — every account '
          'on those sites is signed out of this browser. The cookie databases '
          'are backed up first, so this is recoverable from the vault if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out sites'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await cubit.execute();
  }
}
