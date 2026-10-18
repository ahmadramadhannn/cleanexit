// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/services/session_store.dart';
import '../../data/services/vault_service.dart';

class HistoryState extends Equatable {
  final bool loading;
  final List<SessionRecord> sessions;
  final String? statusText;
  final String? error;

  const HistoryState({
    this.loading = false,
    this.sessions = const [],
    this.statusText,
    this.error,
  });

  HistoryState copyWith({
    bool? loading,
    List<SessionRecord>? sessions,
    String? statusText,
    String? error,
  }) {
    return HistoryState(
      loading: loading ?? this.loading,
      sessions: sessions ?? this.sessions,
      statusText: statusText,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, sessions, statusText, error];
}

class HistoryCubit extends Cubit<HistoryState> {
  final SessionStore _store;
  final VaultService _vault;

  HistoryCubit({
    required SessionStore store,
    required VaultService vault,
  })  : _store = store,
        _vault = vault,
        super(const HistoryState());

  void refresh() {
    emit(HistoryState(sessions: _store.listAll()));
  }

  VaultManifest? manifestFor(SessionRecord record) {
    if (record.vaultDir == null) return _vault.readManifest(record.id);
    final dirName = record.vaultDir!.split('/').last.split('\\').last;
    return _vault.readManifest(dirName);
  }

  Future<void> restoreVault(SessionRecord record) async {
    emit(state.copyWith(loading: true, statusText: 'Restoring files…'));
    final restored = await _vault.restoreAll(record.id);
    final fresh = _store.byId(record.id);
    final sessions = _store.listAll();
    emit(state.copyWith(
      loading: false,
      statusText: restored > 0 ? 'Restored $restored item(s).' : null,
      error: restored == 0 ? 'Nothing left to restore.' : null,
      sessions: fresh != null
          ? sessions.map((s) => s.id == fresh.id ? fresh : s).toList()
          : sessions,
    ));
  }

  Future<void> purgeVault(SessionRecord record) async {
    emit(state.copyWith(loading: true, statusText: 'Purging vault…'));
    final count = await _vault.purgeSession(record.id);
    emit(state.copyWith(
      loading: false,
      statusText: 'Vault purged ($count item(s) gone for good).',
    ));
  }

  Future<void> deleteRecord(SessionRecord record) async {
    // Remove the JSON record AND any vault data parked under its id —
    // otherwise deleting a session left orphaned vault folders behind.
    await _store.delete(record.id);
    _vault.deleteSessionQuietly(record.id);
    emit(HistoryState(sessions: _store.listAll()));
  }

  void clearToast() =>
      emit(state.copyWith(statusText: null, error: null));
}
