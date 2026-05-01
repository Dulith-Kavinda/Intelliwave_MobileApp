import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted && context.read<AuthProvider>().isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      await context.read<AuthProvider>().signInWithGoogle();
      
      if (mounted && context.read<AuthProvider>().isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Google Sign In failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.2),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'iW',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title
                  Text(
                    'IntelIWave',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGrey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Heart Rate Monitoring System',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.grey,
                        ),
                  ),
                  const SizedBox(height: 48),
                  // Form
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGrey,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your account',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.grey,
                            ),
                      ),
                      const SizedBox(height: 24),
                      // Email Field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Email address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          prefixIconColor: AppColors.primary,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.lightGrey,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.lightGrey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          prefixIconColor: AppColors.primary,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.grey,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.lightGrey,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.lightGrey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : () {},
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // OR Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.lightGrey,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.lightGrey,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Google Sign In Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleLogin,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: AppColors.lightGrey,
                              width: 1.5,
                            ),
                            foregroundColor: AppColors.darkGrey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Sign Up Link
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register'),
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: Theme.of(context).textTheme.bodyMedium,
                              children: [
                                TextSpan(
                                  text: 'Sign Up',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
