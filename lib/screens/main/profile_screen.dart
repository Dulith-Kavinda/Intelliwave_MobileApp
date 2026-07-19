import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/service_locator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();

    // Proactively refresh profile if needed (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUserModel == null && authProvider.isAuthenticated) {
        authProvider.refreshUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ImagePickerBottomSheet(),
    );

    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      try {
        setState(() => _isUploadingImage = true);
        await authProvider.updateUserProfile(
          name: authProvider.currentUserModel!.name,
          birthday: authProvider.currentUserModel!.birthday,
          weight: authProvider.currentUserModel!.weight,
          height: authProvider.currentUserModel!.height,
          bloodGroup: authProvider.currentUserModel!.bloodGroup,
          phoneNumber: authProvider.currentUserModel!.phoneNumber,
          address: authProvider.currentUserModel!.address,
          gender: authProvider.currentUserModel!.gender,
          profilePictureUrl: null,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove photo: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
      return;
    }

    try {
      setState(() => _isUploadingImage = true);
      final File? imageFile = choice == 'camera'
          ? await imageUploadService.pickImageFromCamera()
          : await imageUploadService.pickImageFromGallery();

      if (imageFile == null || !mounted) {
        setState(() => _isUploadingImage = false);
        return;
      }

      final url = await imageUploadService.uploadProfileImage(
        userId: userId,
        imageFile: imageFile,
      );

      if (mounted) {
        await authProvider.updateUserProfile(
          name: authProvider.currentUserModel!.name,
          birthday: authProvider.currentUserModel!.birthday,
          weight: authProvider.currentUserModel!.weight,
          height: authProvider.currentUserModel!.height,
          bloodGroup: authProvider.currentUserModel!.bloodGroup,
          phoneNumber: authProvider.currentUserModel!.phoneNumber,
          address: authProvider.currentUserModel!.address,
          gender: authProvider.currentUserModel!.gender,
          profilePictureUrl: url,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile(AuthProvider authProvider) async {
    setState(() => _isSaving = true);
    try {
      await authProvider.updateUserProfile(
        name: _nameController.text.trim(),
        birthday: authProvider.currentUserModel!.birthday,
        weight: authProvider.currentUserModel!.weight,
        height: authProvider.currentUserModel!.height,
        bloodGroup: authProvider.currentUserModel!.bloodGroup,
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        gender: authProvider.currentUserModel!.gender,
        profilePictureUrl: authProvider.currentUserModel!.profilePictureUrl,
      );
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUserModel;

        // Pre-fill controllers once data is available
        if (user != null && !_isEditing) {
          _nameController.text = user.name;
          _phoneController.text = user.phoneNumber;
          _addressController.text = user.address;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
              if (user != null)
                IconButton(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isEditing ? Icons.done_rounded : Icons.edit_outlined),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_isEditing) {
                            await _saveProfile(authProvider);
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                ),
            ],
          ),
          body: user == null
              ? _buildLoadingOrEmpty(authProvider)
              : RefreshIndicator(
                  onRefresh: () => authProvider.refreshUserProfile(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Hero Card
                        _buildProfileHeroCard(user),
                        const SizedBox(height: 24),

                        // Personal Information
                        _buildSectionTitle(context, 'Personal Information'),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _ProfileInfoRow(
                                  label: 'Name',
                                  value: user.name,
                                  icon: Icons.person_outline,
                                  isEditing: _isEditing,
                                  controller: _nameController,
                                ),
                                const Divider(height: 24),
                                _ProfileInfoRow(
                                  label: 'Email',
                                  value: user.email,
                                  icon: Icons.email_outlined,
                                  isEditing: false,
                                ),
                                const Divider(height: 24),
                                _ProfileInfoRow(
                                  label: 'Phone',
                                  value: user.phoneNumber.isEmpty
                                      ? 'Not set'
                                      : user.phoneNumber,
                                  icon: Icons.phone_outlined,
                                  isEditing: _isEditing,
                                  controller: _phoneController,
                                ),
                                const Divider(height: 24),
                                _ProfileInfoRow(
                                  label: 'Address',
                                  value: user.address.isEmpty
                                      ? 'Not set'
                                      : user.address,
                                  icon: Icons.location_on_outlined,
                                  isEditing: _isEditing,
                                  controller: _addressController,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Health Information
                        _buildSectionTitle(context, 'Health Information'),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _ProfileInfoRow(
                                  label: 'Birthday',
                                  value: DateFormat('dd MMMM yyyy')
                                      .format(user.birthday),
                                  icon: Icons.cake_outlined,
                                  isEditing: false,
                                ),
                                const Divider(height: 24),
                                _ProfileInfoRow(
                                  label: 'Gender',
                                  value: user.gender.isEmpty
                                      ? 'Not set'
                                      : user.gender,
                                  icon: Icons.wc,
                                  isEditing: false,
                                ),
                                const Divider(height: 24),
                                _ProfileInfoRow(
                                  label: 'Blood Group',
                                  value: user.bloodGroup.isEmpty
                                      ? 'Not set'
                                      : user.bloodGroup,
                                  icon: Icons.bloodtype_outlined,
                                  isEditing: false,
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _HealthStatChip(
                                        icon: Icons.monitor_weight_outlined,
                                        label: 'Weight',
                                        value: user.weight > 0
                                            ? '${user.weight.toStringAsFixed(1)} kg'
                                            : '–',
                                        color: AppColors.info,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _HealthStatChip(
                                        icon: Icons.height,
                                        label: 'Height',
                                        value: user.height > 0
                                            ? '${user.height.toStringAsFixed(0)} cm'
                                            : '–',
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Support Section
                        _buildSectionTitle(context, 'Support'),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              _SupportTile(
                                icon: Icons.help_outline,
                                title: 'Help & FAQ',
                                subtitle: 'Find answers to common questions',
                                color: AppColors.warning,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/help'),
                              ),
                              const Divider(height: 1, indent: 56),
                              _SupportTile(
                                icon: Icons.support_agent,
                                title: 'Contact Us',
                                subtitle: 'Get in touch with our support team',
                                color: AppColors.info,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/contact'),
                              ),
                              const Divider(height: 1, indent: 56),
                              _SupportTile(
                                icon: Icons.gavel,
                                title: 'Terms & Conditions',
                                subtitle: 'Read our terms of service',
                                color: AppColors.primary,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/terms'),
                              ),
                              const Divider(height: 1, indent: 56),
                              _SupportTile(
                                icon: Icons.privacy_tip_outlined,
                                title: 'Privacy Policy',
                                subtitle: 'How we handle your data',
                                color: AppColors.success,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/privacy'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Account Actions
                        _buildSectionTitle(context, 'Account'),
                        const SizedBox(height: 8),

                        // Change Password
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showChangePasswordDialog(context, authProvider),
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Change Password'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Logout
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showLogoutDialog(context, authProvider),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Delete Account
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showDeleteDialog(context, authProvider),
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('Delete Account'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLoadingOrEmpty(AuthProvider authProvider) {
    if (authProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading profile...', style: TextStyle(color: AppColors.grey)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_outlined,
              size: 64, color: AppColors.lightGrey),
          const SizedBox(height: 16),
          const Text('Profile not found'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => authProvider.refreshUserProfile(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeroCard(dynamic user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ProfileHeaderPatternPainter(),
              ),
            ),
            Positioned(
              right: -25,
              top: -15,
              bottom: -15,
              width: 180,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar with upload button
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          image: user.profilePictureUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(user.profilePictureUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user.profilePictureUrl == null
                            ? Center(
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : _isUploadingImage
                                ? const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)
                                : null,
                      ),
                      // Camera button
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickAndUploadImage,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _isUploadingImage ? AppColors.grey : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 1.5),
                          ),
                          child: _isUploadingImage
                              ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Icon(Icons.camera_alt,
                                  size: 14, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Name and email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isEmpty ? 'User' : user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.bloodGroup.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user.bloodGroup,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.darkGrey,
          ),
    );
  }

  void _showChangePasswordDialog(
      BuildContext context, AuthProvider authProvider) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            hintText: 'New Password (min 6 characters)',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.length >= 6) {
                try {
                  await authProvider.updatePassword(passwordController.text);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password updated successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              authProvider.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              authProvider.deleteAccount();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Bottom sheet for image picker choice
class _ImagePickerBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Profile Photo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use your camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.info),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick from your photos'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
              title: const Text('Remove Photo',
                  style: TextStyle(color: AppColors.danger)),
              subtitle: const Text('Clear profile picture'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isEditing;
  final TextEditingController? controller;

  const _ProfileInfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isEditing,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.grey),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey,
                ),
          ),
        ),
        Expanded(
          flex: 2,
          child: isEditing && controller != null
              ? TextField(
                  controller: controller,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textAlign: TextAlign.end,
                )
              : Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }
}

class _HealthStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HealthStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.grey,
            ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
    );
  }
}

class ProfileHeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    // Draw abstract overlapping circular shapes on the right side
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.1),
      size.width * 0.45,
      strokePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.1),
      size.width * 0.45,
      fillPaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.1),
      size.width * 0.65,
      strokePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.95),
      size.width * 0.25,
      strokePaint,
    );

    // Dynamic wave/curve from bottom-left to bottom-right
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.6,
      size.width * 0.7,
      size.height * 0.9,
    );
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 1.05,
      size.width,
      size.height * 0.85,
    );
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
