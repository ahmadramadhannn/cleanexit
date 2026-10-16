// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../data/models/models.dart';
import '../../data/services/disposal_service.dart';

class _Unset {
  const _Unset();
}

const Object _unset = _Unset();

class ReviewState extends Equatable {
  final List<TrackedFile> files;

  /// Paths the user wants to KEEP (everything else gets disposed of).
  final Set<String> keepPaths;

  final DisposalMethod disposal;

  // filters
  final String? rootFilter;
  final FileOrigin? originFilter;
  final String query;

  // execution progress
  final bool busy;
  final int done;
  final int total;
  final String? current;

  final List<DisposalOutcome>? outcomes;
  final String? error;

  const ReviewState({
    required this.files,
    required this.keepPaths,
    required this.disposal,
    this.rootFilter,
    this.originFilter,
    this.query = '',
    this.busy = false,
    this.done = 0,
    this.total = 0,
    this.current,
    this.outcomes,
    this.error,
  });

  List<TrackedFile> get visible {
    Iterable<TrackedFile> list = files;
    if (rootFilter != null) {
      list = list.where((f) => f.rootLabel == rootFilter);
    }
    if (originFilter != null) {
      list = list.where((f) => f.origin == originFilter);
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((f) => f.path.toLowerCase().contains(q));
    }
    return list.toList();
  }

  Set<String> get cleanedPaths =>
      files.map((f) => f.path).where((p) => !keepPaths.contains(p)).toSet();

  int get cleanedBytes => files
      .where((f) => !keepPaths.contains(f.path))
      .fold(0, (s, f) => s + f.sizeBytes);

  /// Sentinel-aware copyWith: pass `null` explicitly to CLEAR a field.
  ReviewState copyWith({
    List<TrackedFile>? files,
    Set<String>? keepPaths,
    DisposalMethod? disposal,
    Object? rootFilter = _unset,
    Object? originFilter = _unset,
    String? query,
    bool? busy,
    int? done,
    int? total,
    String? current,
    Object? outcomes = _unset,
    Object? error = _unset,
    bool clearCurrent = false,
  }) {
    return ReviewState(
      files: files ?? this.files,
      keepPaths: keepPaths ?? this.keepPaths,
      disposal: disposal ?? this.disposal,
      rootFilter: identical(rootFilter, _unset)
          ? this.rootFilter
          : rootFilter as String?,
      originFilter: identical(originFilter, _unset)
          ? this.originFilter
          : originFilter as FileOrigin?,
      query: query ?? this.query,
      busy: busy ?? this.busy,
      done: done ?? this.done,
      total: total ?? this.total,
      current: clearCurrent ? null : (current ?? this.current),
      outcomes: identical(outcomes, _unset)
          ? this.outcomes
          : outcomes as List<DisposalOutcome>?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }

  @override
  List<Object?> get props => [
        files, keepPaths, disposal, rootFilter, originFilter, query,
        busy, done, total, current, outcomes, error,
      ];
}

class ReviewCubit extends Cubit<ReviewState> {
  final DisposalService _disposal;
  final String sessionId;

  ReviewCubit({
    required List<TrackedFile> files,
    required this.sessionId,
    required DisposalService disposal,
    required DisposalMethod initialDisposal,
  })  : _disposal = disposal,
        super(ReviewState(
          files: files,
          keepPaths: const {},
          disposal: initialDisposal,
        ));

  void toggleKeep(String path) {
    final next = Set<String>.from(state.keepPaths);
    if (!next.add(path)) next.remove(path);
    emit(state.copyWith(keepPaths: next));
  }

  void keepEverything() =>
      emit(state.copyWith(keepPaths: state.files.map((f) => f.path).toSet()));

  void keepNothing() => emit(state.copyWith(keepPaths: const {}));

  void invertKeep() {
    final next = state.files
        .map((f) => f.path)
        .where((path) => !state.keepPaths.contains(path))
        .toSet();
    emit(state.copyWith(keepPaths: next));
  }

  /// Keep one file AND every ancestor directory it lives in, so selecting a
  /// deep file doesn't result in its parent folder being shredded around it.
  void keepWithParents(String path) {
    final next = Set<String>.from(state.keepPaths);
    next.add(path);
    for (final f in state.files) {
      if (f.isDir &&
          (path.startsWith('${f.path}/') || path.startsWith('${f.path}\\'))) {
        next.add(f.path);
      }
    }
    emit(state.copyWith(keepPaths: next));
  }

  void setDisposal(DisposalMethod m) => emit(state.copyWith(disposal: m));
  void setRootFilter(String? r) => emit(state.copyWith(rootFilter: r));
  void setOriginFilter(FileOrigin? o) => emit(state.copyWith(originFilter: o));
  void setQuery(String q) => emit(state.copyWith(query: q));

  /// Executes disposal for every non-kept path.
  /// Guards: a kept file's ancestor directory is skipped so we never delete
  /// around a kept item.
  Future<List<DisposalOutcome>> execute() async {
    final keepSet = state.keepPaths;
    final toClean = <String>[];
    final skipped = <String, String>{};

    for (final f in state.files) {
      if (keepSet.contains(f.path)) continue;
      if (f.isDir) {
        final keptChild = keepSet.any(
          (k) => k.startsWith('${f.path}/') || k.startsWith('${f.path}\\'),
        );
        if (keptChild) {
          skipped[f.path] = 'contains files you kept';
          continue;
        }
      }
      toClean.add(f.path);
    }

    emit(state.copyWith(busy: true, total: toClean.length, done: 0));
    try {
      final outcomes = await _disposal.dispose(
        paths: toClean,
        method: state.disposal,
        sessionId: sessionId,
        onProgress: (done, total, current) {
          if (isClosed) return;
          emit(state.copyWith(done: done, current: current));
        },
      );
      for (final entry in skipped.entries) {
        outcomes.add(
          DisposalOutcome(entry.key, error: 'Skipped — ${entry.value}'),
        );
      }
      if (isClosed) return outcomes;
      emit(state.copyWith(busy: false, outcomes: outcomes, clearCurrent: true));
      return outcomes;
    } catch (e) {
      if (isClosed) return const [];
      emit(state.copyWith(busy: false, error: '$e'));
      rethrow;
    }
  }

  /// Directories whose children were disposed of no longer need listing.
  /// (The disposal moves the whole folder — children vanish with it.)
  static bool childOfCleanedDir(TrackedFile f, Set<String> cleanedDirs) =>
      cleanedDirs.any((d) =>
          f.path.startsWith('$d/') || f.path.startsWith('$d\\'));

  static String parentDir(String path) => p.dirname(path);
}
