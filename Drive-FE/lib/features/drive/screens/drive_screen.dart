import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:drive_fe/features/drive/screens/profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/drive_file.dart';
import '../../../data/repositories/drive_repository.dart';
import '../bloc/drive_bloc.dart';
import '../widgets/file_tile.dart';
import '../widgets/storage_card.dart';

class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  final searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _dragging = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  ///files pick update
  Future<void> _pickFiles() async {
    final driveCubit = context.read<DriveCubit>();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'txt',
        'jpg',
        'jpeg',
        'png',
        'pjp',
        'mp4',
        'mov',
        'mkv',
        'avi',
        'webm',
        '3gp'
      ],
    );
    if (result == null || !mounted) return;
    await driveCubit.uploadFiles(result.files);
  }

  ///drop logic
  Future<void> _dropFiles(DropDoneDetails detail) async {
    final driveCubit = context.read<DriveCubit>();
    final files = <PlatformFile>[];
    for (final file in detail.files) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        files.add(PlatformFile(
          name: file.name,
          bytes: bytes,
          size: bytes.length,
        ));
      } else {
        files.add(PlatformFile(
          name: file.name,
          path: file.path,
          size: await file.length()
        ));
      }
    }
    if (!mounted) return;
    await driveCubit.uploadFiles(files);
  }

  ///Search logic
  void _search(String value) {
    _searchDebounce?.cancel();
    final driveCubit = context.read<DriveCubit>();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) driveCubit.load(search: value);
    });
  }

  /// Open/download a file using the authenticated API.
  Future<void> _downloadFile(DriveFile file) async {
    final repository = context.read<DriveRepository>();
    try {
      final bytes = await repository.downloadBytes(file.id);
      if (!mounted) return;
      final currentContext = context;
      final lower = file.name.toLowerCase();
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) {
        showDialog(
          context: currentContext,
          builder: (_) => Dialog(
            child: InteractiveViewer(child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain)),
          ),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}${Platform.pathSeparator}${file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}';
      final saved = await File(path).writeAsBytes(bytes, flush: true);
      await OpenFilex.open(saved.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger));
    }
  }

  ///rename file logic
  Future<void> rename(DriveFile file) async {
    final driveCubit = context.read<DriveCubit>();
    String? newName;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController(text: file.name);
        return AlertDialog(
          title: const Text('Rename file'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'File name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                newName = controller.text;
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && mounted) {
      await driveCubit.rename(file, newName!);
    }
  }

  ///Logout logic
  Future<void> _logout() async {
    final repository = context.read<DriveRepository>();
    await repository.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  ///Delete account logic
  Future<void> _deleteAccount() async {
    final repository = context.read<DriveRepository>();
    try {
      await repository.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger));
    }
  }

  ///open profile logic
    Future<void> _openProfile() async {
    final repository = context.read<DriveRepository>();
    try {
      final data = await repository.getCurrentUser();
      if (!mounted) return;
      final currentContext = context;
      final user = UserProfileModel(
        fullName: (data['name'] ?? data['username'] ?? '').toString(),
        username: (data['username'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
      );
      Navigator.of(currentContext).push(
        MaterialPageRoute(
          builder: (_) => ProfilePage(
            userProfile: user,
            onDeleteAccount: _deleteAccount,
            onLogout: _logout,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriveCubit, DriveState>(
      listenWhen: (oldState, newState) =>
          oldState.error != newState.error || oldState.message != newState.message,
      listener: (context, state) {
        final text = state.error ?? state.message;
        if (text == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            backgroundColor: state.error == null ? null : AppColors.danger,
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: AppSizes.headerHeight,

          /// Profile Icon
          leading: IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,

            icon: const Icon(Icons.account_circle_rounded),
          ),

          /// Title
          title: const Text(
            'Vault-Drive',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),

          actions: [
            /// Refresh Icon
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => context.read<DriveCubit>().load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),

        ///Body
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
            child: DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (detail) {
                setState(() => _dragging = false);
                _dropFiles(detail);
              },

              ///main body
              child: BlocBuilder<DriveCubit, DriveState>(
                builder: (context, state) {
                  return Column(
                    children: [

                      ///top controls
                      topControls(context, state),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (state.loading && state.files.isEmpty) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            return Stack(
                              children: [

                                ///bottom indicator
                                Column(
                                  children: [
                                    if (state.storage != null)
                                      StorageCard(storage: state.storage!),
                                    const SizedBox(height: 18),
                                    Expanded(child: fileArea(state)),
                                  ],
                                ),
                                if (_dragging)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.accentSoft.withValues(alpha: .96),
                                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                                        border: Border.all(color: AppColors.accent, width: 2),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.file_upload_rounded, size: 54, color: AppColors.accent),
                                            SizedBox(height: 10),
                                            Text('Drop files here', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                            SizedBox(height: 4),
                                            Text('PDF, TXT, images and videos'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (state.uploading)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 12,
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Uploading ${(state.uploadProgress * 100).round()}%'),
                                            const SizedBox(height: 8),
                                            LinearProgressIndicator(value: state.uploadProgress)
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  ///Top Header  Controls
  Widget topControls(BuildContext context, DriveState state) {
    final trash = state.view == DriveView.trash;

    final search = TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {});
        _search(value);
      },

      ///Search bor
      decoration: InputDecoration(
        hintText: 'Search files...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            searchController.clear();
            context.read<DriveCubit>().load(search: '');
            setState(() {});
          },
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );

    ///Files and Trash box
    final viewToggle = SegmentedButton<DriveView>(
      segments: const [
        ButtonSegment(
          value: DriveView.files,
          label: Text('Files'),
          icon: Icon(Icons.folder_rounded),
        ),
        ButtonSegment(
          value: DriveView.trash,
          label: Text('Trash'),
          icon: Icon(Icons.delete_outline_rounded),
        ),
      ],
      selected: {trash ? DriveView.trash : DriveView.files},
      onSelectionChanged: (selection) {
        context.read<DriveCubit>().load(view: selection.first);
      },
    );

    /// Upload Button
    final upload = FilledButton.icon(
      onPressed: trash ? null : _pickFiles,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Upload'),
    );

    /// Top layout
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: viewToggle),
                  const SizedBox(width: 10),
                  upload,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            viewToggle,
            const SizedBox(width: 12),
            upload,
          ],
        );
      },
    );
  }

  /// File show area
  Widget fileArea(DriveState state) {
    if (state.files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.view == DriveView.trash
                  ? Icons.delete_sweep_outlined
                  : Icons.cloud_outlined,
              size: 64,
              color: AppColors.slate,
            ),
            const SizedBox(height: 12),
            Text(
              state.view == DriveView.trash ? 'Trash is empty' : 'No files yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              state.view == DriveView.trash
                  ? 'Deleted files will appear here.'
                  : 'Drop a file here or use Upload to start.',
              style: const TextStyle(color: AppColors.slate),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final file = state.files[index];
        return FileTile(
          file: file,
          trashView: state.view == DriveView.trash,
          onOpen: () => _downloadFile(file),
          onRename: () => rename(file),
          onDelete: () => context.read<DriveCubit>().moveToTrash(file),
          onRestore: () => context.read<DriveCubit>().restore(file),
          onPermanentDelete: () => context.read<DriveCubit>().permanentDelete(file),
        );
      },
    );
  }

}
