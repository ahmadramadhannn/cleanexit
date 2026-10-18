// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/disposal_method.dart';
import '../../core/constants.dart';
import '../../di.dart';

class SettingsState extends Equatable {
  final AppSettings settings;
  final bool saving;
  final String? statusText;

  /// Browser ids whose data folders exist on this machine — a HINT shown in
  /// the Preferred browsers section, never an automatic selection.
  final Set<String> detectedBrowserIds;

  const SettingsState({
    required this.settings,
    this.saving = false,
    this.statusText,
    this.detectedBrowserIds = const {},
  });

  SettingsState copyWith({
    AppSettings? settings,
    bool? saving,
    String? statusText,
    Set<String>? detectedBrowserIds,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      saving: saving ?? this.saving,
      statusText: statusText,
      detectedBrowserIds: detectedBrowserIds ?? this.detectedBrowserIds,
    );
  }

  @override
  List<Object?> get props =>
      [settings, saving, statusText, detectedBrowserIds];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(SettingsState(settings: Services.settings));

  Future<void> toggleRoot(int index, bool enabled) async {
    final roots = List<RootConfig>.from(state.settings.roots);
    roots[index] = roots[index].copyWith(enabled: enabled);
    final next = state.settings.copyWith(roots: roots);
    await _persist(next);
  }

  Future<void> addRoot(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    if (state.settings.roots.any(
      (r) => r.path.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return;
    }
    final label = trimmed.split(Platform.pathSeparator).last.isNotEmpty
        ? trimmed.split(Platform.pathSeparator).last
        : trimmed;
    final roots = [
      ...state.settings.roots,
      RootConfig(label: label, path: trimmed, enabled: true),
    ];
    await _persist(state.settings.copyWith(roots: roots));
  }

  Future<void> removeRoot(int index) async {
    final roots = List<RootConfig>.from(state.settings.roots)..removeAt(index);
    await _persist(state.settings.copyWith(roots: roots));
  }

  Future<void> setDefaultDisposal(DisposalMethod m) async {
    await _persist(state.settings.copyWith(defaultDisposal: m));
  }

  Future<void> setAskEach(bool v) async {
    await _persist(state.settings.copyWith(askDisposalEachRun: v));
  }

  // ------------------------------------------------- preferred browsers

  /// One-shot check of which supported browsers have data folders on this
  /// machine. Purely informational — the checkboxes stay user-controlled.
  Future<void> detectInstalledBrowsers() async {
    try {
      final apps = await Services.browserDetector.detect();
      if (isClosed) return;
      emit(state.copyWith(
        detectedBrowserIds:
            apps.where((a) => a.isDetected).map((a) => a.defId.name).toSet(),
      ));
    } catch (_) {
      // Detection is a nice-to-have hint; the section works without it.
    }
  }

  Future<void> togglePreferredBrowser(String id, bool on) async {
    final current = Set<String>.from(state.settings.preferredBrowsers);
    if (on) {
      current.add(id);
    } else {
      current.remove(id);
    }
    // Keep the stored order stable and canonical so the UI reads the same
    // way everywhere (accounts header, cleanup step, ...).
    final ordered = [
      for (final id0 in CeConstants.selectableBrowserIds)
        if (current.contains(id0)) id0,
    ];
    await _persist(state.settings.copyWith(preferredBrowsers: ordered));
  }

  /// Pre-checks every browser actually installed on this machine. Still an
  /// explicit user action — a shortcut, not a guess.
  Future<void> selectDetectedBrowsers() async {
    if (state.detectedBrowserIds.isEmpty) return;
    final ordered = [
      for (final id in CeConstants.selectableBrowserIds)
        if (state.detectedBrowserIds.contains(id)) id,
    ];
    await _persist(state.settings.copyWith(preferredBrowsers: ordered));
  }

  Future<void> clearPreferredBrowsers() async {
    await _persist(state.settings.copyWith(preferredBrowsers: const []));
  }

  Future<void> _persist(AppSettings next) async {
    emit(state.copyWith(saving: true));
    await Services.saveSettings(next);
    emit(state.copyWith(
      saving: false,
      settings: next,
      statusText: 'Saved',
    ));
  }

  void clearToast() => emit(state.copyWith(statusText: null));
}
