import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/service_locator.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({Key? key}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedBloodGroup;
  double _weight = 70;
  double _height = 170;
  File? _selectedProfileImage;
  String? _profilePictureUrl;
  String? _socialEmail;
  String? _socialProvider;
  
  bool _isLoading = false;
  bool _isUploadingImage = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user != null) {
        final meta = user.userMetadata ?? {};

        // Detect social provider from app_metadata
        final appMeta = user.appMetadata;
        final provider = appMeta['provider'] as String?;
        if (provider != null && provider != 'email') {
          setState(() {
            _socialProvider = provider[0].toUpperCase() + provider.substring(1);
          });
        }

        // Pre-fill name from social metadata
        final metaName = meta['name'] as String?;
        final metaAvatar = meta['avatar_url'] as String?;
        if (metaName != null && metaName.isNotEmpty && _nameController.text.isEmpty) {
          setState(() {
            _nameController.text = metaName;
          });
        }

        // Pre-fill avatar
        if (metaAvatar != null && metaAvatar.isNotEmpty) {
          setState(() {
            _profilePictureUrl = metaAvatar;
          });
        }

        // Pre-fill email display (read-only)
        if (user.email != null && user.email!.isNotEmpty) {
          setState(() {
            _socialEmail = user.email;
          });
        }
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

  Future<void> _pickProfileImage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    try {
      setState(() => _isUploadingImage = true);
      final File? imageFile = choice == 'camera'
          ? await imageUploadService.pickImageFromCamera()
          : await imageUploadService.pickImageFromGallery();

      if (imageFile == null || !mounted) {
        setState(() => _isUploadingImage = false);
        return;
      }

      setState(() {
        _selectedProfileImage = imageFile;
      });

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      if (userId != null) {
        final url = await imageUploadService.uploadProfileImage(
          userId: userId,
          imageFile: imageFile,
        );
        setState(() {
          _profilePictureUrl = url;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your birthday')),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }
    if (_selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your blood group')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.updateUserProfile(
        name: _nameController.text.trim(),
        birthday: _selectedDate!,
        weight: _weight,
        height: _height,
        bloodGroup: _selectedBloodGroup!,
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        gender: _selectedGender!,
        profilePictureUrl: _profilePictureUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        // AppHome will automatically switch to HomeScreen on auth status rebuild.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('CompleteProfileScreen: build method called');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await authProvider.signOut();
              }
            },
          ),
        ],
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: isDarkMode
            ? const BoxDecoration(color: AppColors.darkBg)
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEEF2FF),
                    Color(0xFFF8FAFC),
                    Colors.white,
                  ],
                ),
              ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : AppColors.darkGrey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please fill in your details to start using IntelIWave.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                        ),
                  ),
                  const SizedBox(height: 24),
                  
                  // ── Social Welcome Banner ────────────────────────────────
                  if (_socialProvider != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.12),
                            const Color(0xFF8B5CF6).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Signed in with $_socialProvider',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkMode ? Colors.white : AppColors.darkGrey,
                                  ),
                                ),
                                if (_socialEmail != null)
                                  Text(
                                    _socialEmail!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                                    ),
                                  ),
                                Text(
                                  'Your name and photo were pre-filled. Please complete your health profile.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode ? Colors.grey[500] : AppColors.grey,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Profile Photo
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickProfileImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode ? AppColors.darkBorder : AppColors.lightGrey,
                                  image: _selectedProfileImage != null
                                      ? DecorationImage(
                                          image: FileImage(_selectedProfileImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : (_profilePictureUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(_profilePictureUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: _selectedProfileImage == null && _profilePictureUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 40,
                                        color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                                      )
                                    : null,
                              ),
                              if (_isUploadingImage)
                                const Positioned.fill(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedProfileImage == null && _profilePictureUrl == null
                              ? 'Add Photo (Optional)'
                              : 'Tap to Change',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isLoading,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : AppColors.darkGrey,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      prefixIcon: Icon(
                        Icons.person,
                        color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Full name required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : AppColors.darkGrey,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Phone Number',
                      prefixIcon: Icon(
                        Icons.phone,
                        color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Phone number required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    enabled: !_isLoading,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : AppColors.darkGrey,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Address',
                      prefixIcon: Icon(
                        Icons.location_on,
                        color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Address required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Birthday Date Picker
                  GestureDetector(
                    onTap: _isLoading ? null : _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cake,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate == null
                                ? 'Select Birthday'
                                : 'Birthday: ${DateFormat('dd MMMM yyyy').format(_selectedDate!)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedDate == null
                                  ? (isDarkMode ? Colors.grey[500] : Colors.grey[600])
                                  : (isDarkMode ? Colors.white : AppColors.darkGrey),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_drop_down,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender and Blood Group Row
                  Row(
                    children: [
                      // Gender
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGender,
                          dropdownColor: isDarkMode ? AppColors.darkSurface3 : Colors.white,
                          decoration: InputDecoration(
                            hintText: 'Gender',
                            prefixIcon: Icon(
                              Icons.wc,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.darkGrey,
                          ),
                          items: _genders
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : AppColors.darkGrey,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: _isLoading ? null : (val) => setState(() => _selectedGender = val),
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Blood Group
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedBloodGroup,
                          dropdownColor: isDarkMode ? AppColors.darkSurface3 : Colors.white,
                          decoration: InputDecoration(
                            hintText: 'Blood Group',
                            prefixIcon: Icon(
                              Icons.bloodtype_outlined,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.darkGrey,
                          ),
                          items: _bloodGroups
                              .map((bg) => DropdownMenuItem(
                                    value: bg,
                                    child: Text(
                                      bg,
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : AppColors.darkGrey,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: _isLoading ? null : (val) => setState(() => _selectedBloodGroup = val),
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weight Slider
                  Text(
                    'Weight: ${_weight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.darkGrey,
                    ),
                  ),
                  Slider(
                    value: _weight,
                    min: 30,
                    max: 200,
                    divisions: 170,
                    label: '${_weight.toStringAsFixed(1)} kg',
                    activeColor: AppColors.primary,
                    inactiveColor: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    onChanged: _isLoading ? null : (val) => setState(() => _weight = val),
                  ),
                  const SizedBox(height: 12),

                  // Height Slider
                  Text(
                    'Height: ${_height.toStringAsFixed(0)} cm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.darkGrey,
                    ),
                  ),
                  Slider(
                    value: _height,
                    min: 100,
                    max: 250,
                    divisions: 150,
                    label: '${_height.toStringAsFixed(0)} cm',
                    activeColor: AppColors.success,
                    inactiveColor: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    onChanged: _isLoading ? null : (val) => setState(() => _height = val),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
