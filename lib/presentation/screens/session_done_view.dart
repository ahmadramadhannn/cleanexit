import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../viewmodels/session_cubit.dart';

/// Final summary after a session completes.
class SessionDoneView extends StatelessWidget {
  const SessionDoneView({super.key});

  @override
  Widget build(BuildContext context) {
    final record = context.watch<SessionCubit>().state.lastRecord;

    if (record == null) {
      return const Center(child: Text('Session finished.'));
    }

    final sitesCleared = record.sitesCleared
        .where((s) => s.success)
        .fold(0, (n, s) => n + s.cookiesRemoved);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_outlined,
                  size: 52, color: CeColors.success),
              const SizedBox(height: 14),
              const Text(
                'You can leave like you were never here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 26),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _row('Session', formatRangeLabel(record.rangeStart, record.rangeEnd)),
                      _row(
                        'Files cleaned',
                        '${record.cleanedPaths.length} · ${formatBytes(record.bytesCleaned)}',
                      ),
                      _row('Files kept', '${record.keptPaths.length}'),
                      _row('Disposal', record.disposal.label),
                      if (record.disposal == DisposalMethod.vault)
                        _row('Vault', 'restorable from History'),
                      if (record.browsersCleaned.isNotEmpty)
                        _row(
                          'Browsers',
                          '${record.browsersCleaned.join(", ")} — $sitesCleared cookie(s) removed',
                        ),
                      if (record.historyCleared)
                        _row('History', 'cleared for the session range'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.read<SessionCubit>().reset(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Back to dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: CeColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: CeText.mono(size: 12.5, color: CeColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
