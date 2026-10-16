import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/models.dart';
import '../../di.dart';
import '../viewmodels/settings_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
