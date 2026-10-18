// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/services/os_trash_service.dart';

class TrashState extends Equatable {
  final bool loading;
  final List<TrashItem> items;
  final bool busy;
  final String? statusText;
  final String? error;

  const TrashState({
    this.loading = false,
    this.items = const [],
    this.busy = false,
    this.statusText,
    this.error,
  });

  TrashState copyWith({
    bool? loading,
    List<TrashItem>? items,
    bool? busy,
    String? statusText,
    String? error,
  }) {
    return TrashState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      busy: busy ?? this.busy,
      statusText: statusText,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, items, busy, statusText, error];
}

/// ViewModel behind the Trash tab — browse the OS trash, restore single
/// items, delete them for good, or empty everything.
class TrashCubit extends Cubit<TrashState> {
  final OsTrashService _trash;

  TrashCubit({required OsTrashService trash}) : _trash = trash, super(const TrashState());

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _trash.list();
      if (isClosed) return;
      emit(state.copyWith(loading: false, items: items));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<void> restore(TrashItem item) async {
    emit(state.copyWith(busy: true, statusText: 'Restoring ${item.name}…'));
    try {
      await _trash.restore(item);
      if (isClosed) return;
      final items = await _trash.list();
      if (isClosed) return;
      emit(state.copyWith(
        busy: false,
        items: items,
        statusText: '${item.name} was put back where it came from.',
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, error: '$e'));
    }
  }

  Future<void> deleteForever(TrashItem item) async {
    emit(state.copyWith(busy: true, statusText: 'Deleting ${item.name}…'));
    try {
      await _trash.deleteForever(item);
      if (isClosed) return;
      final items = await _trash.list();
      if (isClosed) return;
      emit(state.copyWith(
        busy: false,
        items: items,
        statusText: '${item.name} was deleted for good.',
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, error: '$e'));
    }
  }

  Future<void> emptyAll() async {
    emit(state.copyWith(busy: true, statusText: 'Emptying the trash…'));
    try {
      final count = await _trash.emptyAll();
      if (isClosed) return;
      emit(state.copyWith(
        busy: false,
        items: const [],
        statusText: 'Trash emptied — $count item(s) gone for good.',
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, error: '$e'));
    }
  }

  void clearToast() =>
      emit(state.copyWith(statusText: null, error: null));
}
