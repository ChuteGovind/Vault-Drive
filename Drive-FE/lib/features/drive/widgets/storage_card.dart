import 'package:flutter/material.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../../data/repositories/drive_repository.dart';

class StorageCard extends StatelessWidget {
  const StorageCard({super.key, required this.storage});
  final StorageInfo storage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : AppColors.paper,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Storage', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: storage.progress, minHeight: 8),
          const SizedBox(height: 10),
          Text('${formatBytes(storage.used)} used of 1 GB'),
          const SizedBox(height: 3),
          Text('${formatBytes(storage.remaining)} remaining',
              style: TextStyle(color: AppColors.slate)),
        ],
      ),
    );
  }
}
