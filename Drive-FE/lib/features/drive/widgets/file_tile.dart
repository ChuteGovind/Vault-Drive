import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../../data/models/drive_file.dart';

class FileTile extends StatelessWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.trashView,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  final DriveFile file;
  final bool trashView;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(fileIcon(file.name), color: AppColors.accent),
        ),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${formatBytes(file.size)} • ${DateFormat('dd MMM yyyy, hh:mm a').format(file.createdAt.toLocal())}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              switch (value) {
                case 'open':
                  onOpen();
                  break;
                case 'rename':
                  onRename();
                  break;
                case 'delete':
                  onDelete();
                  break;
                case 'restore':
                  onRestore();
                  break;
                case 'permanent':
                  onPermanentDelete();
                  break;
              }
            });
          },
          itemBuilder: (_) => [
            if (!trashView)
              const PopupMenuItem(value: 'open', child: Text('Open / Preview')),
            if (!trashView)
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
            if (!trashView)
              const PopupMenuItem(value: 'delete', child: Text('Move to Trash')),
            if (trashView)
              const PopupMenuItem(value: 'restore', child: Text('Restore')),
            if (trashView)
              const PopupMenuItem(
                value: 'permanent',
                child: Text('Delete Permanently'),
              ),
          ],
        ),
      ),
    );
  }
}
