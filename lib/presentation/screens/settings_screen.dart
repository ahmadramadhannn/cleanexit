import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../../di.dart';
import '../viewmodels/settings_cubit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Which supported browsers exist on this machine — shown as an
    // informational hint next to each checkbox. Never auto-selects.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsCubit>().detectInstalledBrowsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state.statusText != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.statusText!)),
          );
          context.read<SettingsCubit>().clearToast();
        }
      },
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        final settings = state.settings;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Monitored folders'),
                const SizedBox(height: 6),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < settings.roots.length; i++)
                        SwitchListTile(
                          value: settings.roots[i].enabled,
                          onChanged: (v) => cubit.toggleRoot(i, v),
                          secondary: const Icon(Icons.folder_outlined,
                              color: CeColors.accent),
                          title: Text(
                            settings.roots[i].label,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            settings.roots[i].path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CeText.mono(
                                size: 10.5, color: CeColors.textSecondary),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _AddRootRow(onAdd: cubit.addRoot),
                const SizedBox(height: 26),
                const _SectionTitle('Preferred browsers'),
                const SizedBox(height: 6),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          'Only the browsers you pick here are watched for '
                          'signed-in accounts and offered in the account '
                          'cleanup step. Nothing is scanned until you choose. '
                          'Firefox is monitored for accounts only — its cookie '
                          'cleanup is not supported yet.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: CeColors.textSecondary,
                          ),
                        ),
                      ),
                      for (final id in CeConstants.selectableBrowserIds)
                        CheckboxListTile(
                          value: settings.preferredBrowsers.contains(id),
                          onChanged: (v) =>
                              cubit.togglePreferredBrowser(id, v ?? false),
                          secondary: const Icon(Icons.public_outlined,
                              color: CeColors.accent),
                          title: Text(
                            CeConstants.browserDisplayName(id),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  CeConstants.browserDataPathHint(id) ?? id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CeText.mono(
                                      size: 10.5,
                                      color: CeColors.textSecondary),
                                ),
                              ),
                              if (!state.detectedBrowserIds.contains(id))
                                ...[
                                  const SizedBox(width: 8),
                                  const _NotDetectedChip(),
                                ],
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: cubit.selectDetectedBrowsers,
                              icon: const Icon(Icons.done_all, size: 16),
                              label: const Text('Select detected'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed:
                                  settings.preferredBrowsers.isEmpty
                                      ? null
                                      : cubit.clearPreferredBrowsers,
                              child: const Text('Clear'),
                            ),
                            const Spacer(),
                            Text(
                              settings.preferredBrowsers.isEmpty
                                  ? 'No browsers watched yet'
                                  : 'Watching '
                                      '${settings.preferredBrowsers.length} '
                                      'browser(s)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: CeColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionTitle('Disposal default'),
                const SizedBox(height: 6),
                Card(
                  child: RadioGroup<DisposalMethod>(
                    groupValue: settings.defaultDisposal,
                    onChanged: (v) {
                      if (v != null) cubit.setDefaultDisposal(v);
                    },
                    child: Column(
                      children: [
                        for (final m in DisposalMethod.values)
                          RadioListTile<DisposalMethod>(
                            value: m,
                            title: Text(
                              m.label,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              m.description,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionTitle('Vault'),
                const SizedBox(height: 6),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_clock_outlined,
                        color: CeColors.warning),
                    title: Text(
                      '${formatBytes(Services.vault.totalBytes())} parked',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      Services.vault.vaultRoot,
                      style: CeText.mono(
                          size: 10.5, color: CeColors.textSecondary),
                    ),
                    trailing: TextButton(
                      onPressed: () => _openFolder(Services.vault.vaultRoot),
                      child: const Text('Open folder'),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionTitle('About'),
                const SizedBox(height: 6),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined,
                        color: CeColors.accent),
                    title: const Text(
                      'CleanExit',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'v1.0.0 — Leave the computer like you were never here. '
                      'Files are never touched before you confirm; browser '
                      'databases are backed up before every change.',
                      style: TextStyle(fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFolder(String path) {
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [path]);
      } else {
        Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }
}

class _NotDetectedChip extends StatelessWidget {
  const _NotDetectedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CeColors.surfaceHigh,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: CeColors.border),
      ),
      child: const Text(
        'NOT FOUND',
        style: TextStyle(
          fontSize: 8.5,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w700,
          color: CeColors.textSecondary,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w800,
        color: CeColors.textSecondary,
      ),
    );
  }
}

class _AddRootRow extends StatefulWidget {
  final ValueChanged<String> onAdd;
  const _AddRootRow({required this.onAdd});

  @override
  State<_AddRootRow> createState() => _AddRootRowState();
}

class _AddRootRowState extends State<_AddRootRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Add another folder to monitor, e.g. D:\\Work or ~/projects',
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () {
            if (_controller.text.trim().isEmpty) return;
            widget.onAdd(_controller.text);
            _controller.clear();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ],
    );
  }
}
