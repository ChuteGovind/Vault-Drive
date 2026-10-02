import 'package:flutter/material.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';

class UserProfileModel {
  final String fullName;
  final String username;
  final String email;
  const UserProfileModel({required this.fullName, required this.username, required this.email});
}

class ProfilePage extends StatelessWidget {
  final UserProfileModel? userProfile;
  final VoidCallback? onDeleteAccount;
  final VoidCallback? onLogout;

  const ProfilePage({
    super.key,
    this.userProfile,
    this.onDeleteAccount,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    // Fallback placeholder data if backend hasn't populated it yet
    final profile = userProfile ?? const UserProfileModel(fullName: '', username: '', email: '');

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSizes.headerHeight,
        title: const Text(
          'User Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pagePadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Profile Avatar Header
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.accentSoft,
                    child: Icon(
                      Icons.person_rounded,
                      size: 60,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name & Username
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // Details Information Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildProfileTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Full Name',
                      subtitle: profile.fullName,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'Username',
                      subtitle: profile.username,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildProfileTile(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: profile.email,
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 28),

              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.cardRadius)),
                ),
              ),
              const SizedBox(height: 12),

              // Delete Account Button at the bottom
              OutlinedButton.icon(
                onPressed: () => _showDeleteConfirmationDialog(context),
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and will remove all your stored files and data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (onDeleteAccount != null) {
                onDeleteAccount!();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}