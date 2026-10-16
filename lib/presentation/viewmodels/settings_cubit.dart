// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/disposal_method.dart';
import '../../di.dart';

class SettingsState extends Equatable {
  final AppSettings settings;
  final bool saving;
  final String? statusText;

  const SettingsState({
    required this.settings,
    this.saving = false,
    this.statusText,
  });

  SettingsState copyWith({
    AppSettings? settings,
    bool? saving,
    String? statusText,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      saving: saving ?? this.saving,
      statusText: statusText,
    );
  }

  @override
  List<Object?> get props => [settings, saving, statusText];
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
