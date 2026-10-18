import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_nav.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../viewmodels/accounts_cubit.dart';

/// Accounts tab — every account signed into a browser on this machine,
/// recorded over time from the browsers' own preference files.
///
/// This is the "who is still logged in before I hand this PC back" view.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AccountsCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountsCubit, AccountsState>(
      listener: (context, state) {
        if (state.statusText != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.statusText!)),
          );
          context.read<AccountsCubit>().clearToast();
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: CeColors.dangerDim,
            ),
          );
          context.read<AccountsCubit>().clearToast();
        }
      },
      builder: (context, state) {
        final cubit = context.read<AccountsCubit>();

        if (state.loading && state.total == 0) {
          return const Center(child: CircularProgressIndicator());
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Row(
                  children: [
                    const Text(
                      'Browser accounts',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Rescan browsers',
                      onPressed: state.loading || state.busy
                          ? null
                          : cubit.load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'CleanExit reads the browsers\' own user-preference files to '
                  'detect and record every account signed in on this machine '
                  '— Chrome profiles, Chromium browsers and Firefox Sync. '
                  'Passwords are never touched.',
                  style: TextStyle(
                      fontSize: 12.5, color: CeColors.textSecondary,
                      height: 1.45),
                ),
                const SizedBox(height: 8),
                _watchingLine(context, state),
                const SizedBox(height: 18),
                if (state.noBrowsersSelected)
                  _chooseBrowsersCard(context)
                else if (state.signedIn.isNotEmpty) ...[
                  _statsRow(state),
                  const SizedBox(height: 20),
                  const _SectionLabel('Signed in right now'),
                  const SizedBox(height: 8),
                  for (final account in state.signedIn)
                    _accountCard(context, account, current: true),
                ] else
                  _emptyCurrent(state),
                if (!state.noBrowsersSelected &&
                    state.previouslySeen.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const _SectionLabel('Seen before — no longer detected'),
                  const SizedBox(height: 8),
                  for (final account in state.previouslySeen)
                    _accountCard(context, account, current: false),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The user's own choice, always visible: which browsers are being
  /// watched, with a one-tap way to change it.
  Widget _watchingLine(BuildContext context, AccountsState state) {
    if (state.noBrowsersSelected) {
      return Text(
        'No browsers are being watched yet — pick yours below or in Settings.',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: CeColors.warning,
        ),
      );
    }
    if (state.watching.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.visibility_outlined,
            size: 15, color: CeColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Watching: ${state.watching.join(", ")}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CeColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => AppNav.I.goTo(4),
          child: const Text('Change'),
        ),
      ],
    );
  }

  /// Shown instead of any scan results until the user picks at least one
  /// browser — the scan is NEVER run against browsers the user did not pick.
  Widget _chooseBrowsersCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.manage_accounts_outlined,
                size: 40, color: CeColors.accent),
            const SizedBox(height: 12),
            const Text(
              'Choose which browsers to watch',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CeColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'CleanExit does not guess. Select the browsers you actually '
              'use — Chrome, Edge, Brave, Vivaldi, Opera, Chromium or '
              'Firefox — in Settings → Preferred browsers. Their signed-in '
              'accounts will be monitored here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CeColors.textSecondary,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => AppNav.I.goTo(4),
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Choose browsers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(AccountsState state) {
    final browsers = state.signedIn.map((a) => a.browserName).toSet();
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.account_circle_outlined,
            label: 'Accounts signed in',
            value: '${state.signedIn.length}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.public,
            label: 'Browsers affected',
            value: '${browsers.length}',
          ),
        ),
      ],
    );
  }

  Widget _emptyCurrent(AccountsState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 40,
              color: state.total == 0
                  ? CeColors.textSecondary
                  : CeColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              state.total == 0
                  ? 'No signed-in browser accounts detected.\n'
                      'If you log into Chrome or Firefox, the account will '
                      'show up here.'
                  : 'No accounts are signed in right now — nicely done.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CeColors.textSecondary,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(
    BuildContext context,
    BrowserAccount account, {
    required bool current,
  }) {
    final cubit = context.read<AccountsCubit>();
    final state = context.watch<AccountsState>();
    final isChromium = account.browserKey != 'firefox';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: current
                    ? CeColors.accentDim
                    : CeColors.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                account.initial,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: current ? CeColors.accent : CeColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: current
                          ? CeColors.textPrimary
                          : CeColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${account.browserName} · profile '
                    '"${account.profileLabel.isEmpty ? account.profileDir : account.profileLabel}"'
                    ' · first seen ${formatDay(account.firstSeen)}'
                    ' · last seen ${formatDay(account.lastSeen)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CeColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (current)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CeColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SIGNED IN',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: CeColors.warning,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: state.busy ? null : () => cubit.forget(account),
                child: const Text('Forget'),
              ),
            if (current && isChromium) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : () => _confirmLogout(context, account),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Log out sites'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, BrowserAccount account) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log every website out of ${account.browserName}?'),
        content: Text(
          'All cookies in the "${account.profileLabel}" profile will be '
          'deleted, signing every website account in that profile out. '
          'The cookie databases are backed up to the vault first.\n\n'
          'Note: the browser-level sign-in (the ${account.browserName} '
          'profile itself) can only be removed from the browser\'s own '
          'settings menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AccountsCubit>().logOutProfile(account);
            },
            child: const Text('Log out sites'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w800,
        color: CeColors.textSecondary,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CeColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CeColors.accent),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: CeColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: CeText.mono(
                  size: 15,
                  weight: FontWeight.w700,
                  color: CeColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
