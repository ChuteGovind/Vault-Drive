import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/drive_file.dart';
import '../../../data/repositories/drive_repository.dart';

enum DriveView { files, trash }

class DriveState {
  const DriveState({
    this.files = const [],
    this.storage,
    this.view = DriveView.files,
    this.search = '',
    this.loading = false,
    this.uploading = false,
    this.uploadProgress = 0,
    this.error,
    this.message,
  });

  final List<DriveFile> files;
  final StorageInfo? storage;
  final DriveView view;
  final String search;
  final bool loading;
  final bool uploading;
  final double uploadProgress;
  final String? error;
  final String? message;

  DriveState copyWith({
    List<DriveFile>? files,
    StorageInfo? storage,
    DriveView? view,
    String? search,
    bool? loading,
    bool? uploading,
    double? uploadProgress,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) =>
      DriveState(
        files: files ?? this.files,
        storage: storage ?? this.storage,
        view: view ?? this.view,
        search: search ?? this.search,
        loading: loading ?? this.loading,
        uploading: uploading ?? this.uploading,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        error: clearError ? null : error ?? this.error,
        message: clearMessage ? null : message ?? this.message,
      );
}

class DriveCubit extends Cubit<DriveState> {
  DriveCubit(this.repo) : super(const DriveState());

  final DriveRepository repo;

  Future<void> load({String? search, DriveView? view}) async {
    final nextSearch = search ?? state.search;
    final nextView = view ?? state.view;
    emit(state.copyWith(
      loading: true,
      search: nextSearch,
      view: nextView,
      clearError: true,
      clearMessage: true,
    ));
    try {
      final results = await repo.list(
        search: nextSearch,
        trash: nextView == DriveView.trash,
      );
      final storage = await repo.storage();
      emit(state.copyWith(
        files: results,
        storage: storage,
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: _message(e),
      ));
    }
  }

  Future<void> uploadFiles(List<PlatformFile> files) async {
    if (files.isEmpty) return;
    emit(state.copyWith(
      uploading: true,
      uploadProgress: 0,
      clearError: true,
      clearMessage: true,
    ));
    try {
      for (var i = 0; i < files.length; i++) {
        final base = i / files.length;
        await repo.upload(
          files[i],
          onProgress: (p) =>
              emit(state.copyWith(uploadProgress: base + p / files.length)),
        );
      }
      emit(state.copyWith(
        uploading: false,
        uploadProgress: 1,
        message: '${files.length} file(s) uploaded',
      ));
      await load();
    } catch (e) {
      emit(state.copyWith(
        uploading: false,
        error: _message(e),
      ));
    }
  }

  Future<void> rename(DriveFile file, String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean == file.name) return;

    // Optimistically update local state so UI updates instantly
    final updatedFiles = state.files.map((f) {
      if (f.id == file.id) {
        return f.copyWith(name: clean);
      }
      return f;
    }).toList();

    emit(state.copyWith(files: updatedFiles, clearError: true, clearMessage: true));

    try {
      await repo.rename(file.id, clean);
      emit(state.copyWith(message: 'Renamed successfully'));
      await load();
    } catch (e) {
      await load();
      emit(state.copyWith(error: _message(e)));
    }
  }

  Future<void> moveToTrash(DriveFile file) async {
    try {
      await repo.trash(file.id);
      emit(state.copyWith(message: 'Moved to trash'));
      await load();
    } catch (e) {
      emit(state.copyWith(error: _message(e)));
    }
  }

  Future<void> restore(DriveFile file) async {
    try {
      await repo.restore(file.id);
      emit(state.copyWith(message: 'Restored'));
      await load();
    } catch (e) {
      emit(state.copyWith(error: _message(e)));
    }
  }

  Future<void> permanentDelete(DriveFile file) async {
    try {
      await repo.permanentDelete(file.id);
      emit(state.copyWith(message: 'Permanently deleted'));
      await load();
    } catch (e) {
      emit(state.copyWith(error: _message(e)));
    }
  }

  String _message(Object error) {
    final text = error.toString();
    if (text.contains('1 GB') || text.contains('storage')) {
      return text.replaceFirst('Exception: ', '');
    }
    return 'Action failed. Check that the backend is running.';
  }
}
