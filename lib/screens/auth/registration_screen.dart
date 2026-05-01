import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedBloodGroup;
  double _weight = 70;
  double _height = 170;
  bool _obscurePassword = true;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Email required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  hintText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Phone required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  hintText: 'Address',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Address required' : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Birthday',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dayController,
                      decoration: InputDecoration(
                        hintText: 'DD',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      textAlign: TextAlign.center,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Day required';
                        final day = int.tryParse(value!);
                        if (day == null || day < 1 || day > 31) return 'Invalid day';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _monthController,
                      decoration: InputDecoration(
                        hintText: 'MM',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      textAlign: TextAlign.center,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Month required';
                        final month = int.tryParse(value!);
                        if (month == null || month < 1 || month > 12) return 'Invalid month';
                        return null;
                      },
                      onChanged: (value) {
                        if (value.length == 2) {
                          FocusScope.of(context).nextFocus();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      decoration: InputDecoration(
                        hintText: 'YYYY',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      textAlign: TextAlign.center,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Year required';
                        final year = int.tryParse(value!);
                        if (year == null || year < 1950 || year > DateTime.now().year) {
                          return 'Invalid year';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.length == 4) {
                          FocusScope.of(context).unfocus();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    color: AppColors.primary,
                    onPressed: _selectDate,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Current Health Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        hintText: 'Gender',
                        prefixIcon: Icon(Icons.wc),
                      ),
                      items: _genders
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedGender = value);
                      },
                      validator: (value) =>
                          value == null ? 'Gender required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedBloodGroup,
                      decoration: const InputDecoration(
                        hintText: 'Blood Group',
                        prefixIcon: Icon(Icons.bloodtype),
                      ),
                      items: _bloodGroups
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedBloodGroup = value);
                      },
                      validator: (value) =>
                          value == null ? 'Blood group required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Weight',
                        labelText: 'Weight (kg)',
                        prefixIcon: Icon(Icons.monitor_weight),
                      ),
                      initialValue: _weight.toStringAsFixed(1),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Weight required';
                        final weight = double.tryParse(value!);
                        if (weight == null || weight < 30 || weight > 150) {
                          return 'Enter weight between 30-150 kg';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        final weight = double.tryParse(value);
                        if (weight != null) {
                          setState(() => _weight = weight);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Height',
                        labelText: 'Height (cm)',
                        prefixIcon: Icon(Icons.height),
                      ),
                      initialValue: _height.toStringAsFixed(0),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Height required';
                        final height = double.tryParse(value!);
                        if (height == null || height < 130 || height > 220) {
                          return 'Enter height between 130-220 cm';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        final height = double.tryParse(value);
                        if (height != null) {
                          setState(() => _height = height);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Security',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Password required';
                  if (value!.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  hintText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Confirm password';
                  if (value != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return CustomButton(
                    label: 'Create Account',
                    isLoading: authProvider.isLoading,
                    onPressed: () => _handleRegister(context, authProvider),
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _dayController.text = date.day.toString().padLeft(2, '0');
        _monthController.text = date.month.toString().padLeft(2, '0');
        _yearController.text = date.year.toString();
      });
    }
  }

  DateTime? _parseBirthday() {
    try {
      final day = int.tryParse(_dayController.text);
      final month = int.tryParse(_monthController.text);
      final year = int.tryParse(_yearController.text);
      
      if (day == null || month == null || year == null) return null;
      if (day < 1 || day > 31 || month < 1 || month > 12) return null;
      if (year < 1950 || year > DateTime.now().year) return null;
      
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  void _handleRegister(BuildContext context, AuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;
    
    final birthday = _parseBirthday();
    if (birthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid birthday')),
      );
      return;
    }

    try {
      await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text,
        birthday: birthday,
        weight: _weight,
        height: _height,
        bloodGroup: _selectedBloodGroup!,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        gender: _selectedGender!,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Registration failed')),
        );
      }
    }
  }
}
