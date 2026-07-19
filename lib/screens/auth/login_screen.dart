import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Heartbeat-style pulse micro-animation for the logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await context.read<AuthProvider>().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted && context.read<AuthProvider>().isAuthenticated) {
        navigator.pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
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

  Future<void> _handleGoogleLogin() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();

    try {
      // Browser OAuth: just launch — auth listener + AppHome handle navigation.
      await authProvider.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Google Sign In failed: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();

    try {
      // Apple is native — response is direct, AppHome handles navigation.
      await authProvider.signInWithApple();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Apple Sign In failed: ${e.toString()}'),
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

  Future<void> _handleFacebookLogin() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();

    try {
      // Browser OAuth: just launch — auth listener + AppHome handle navigation.
      await authProvider.signInWithFacebook();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Facebook Sign In failed: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showForgotPasswordBottomSheet() {
    final emailResetController = TextEditingController(text: _emailController.text);
    final bottomSheetFormKey = GlobalKey<FormState>();
    bool isResetLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final navigator = Navigator.of(context);
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final authProvider = context.read<AuthProvider>();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface3 : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: bottomSheetFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBorder2 : AppColors.darkBorder,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Reset Password',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.darkGrey,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the email address associated with your account and we\'ll send you a link to reset your password.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : AppColors.grey,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Email Address',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : AppColors.darkGrey,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailResetController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isResetLoading,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.darkGrey,
                        ),
                        decoration: InputDecoration(
                          hintText: 'name@example.com',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBg : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
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
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isResetLoading
                                ? null
                                : () async {
                                    if (!bottomSheetFormKey.currentState!.validate()) return;
                                    setModalState(() => isResetLoading = true);
                                    try {
                                      await authProvider.resetPassword(
                                            emailResetController.text.trim(),
                                          );
                                      navigator.pop();
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Password reset link sent to your email'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } catch (e) {
                                      setModalState(() => isResetLoading = false);
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: isResetLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Send Reset Link',
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
            );
          },
        );
      },
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required Widget logo,
    required bool isDarkMode,
  }) {
    return Container(
      width: 80,
      height: 56,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface3 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: logo,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Stack(
          children: [
            Scaffold(
              body: Container(
        height: double.infinity,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Navigator.of(context).canPop())
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: isDarkMode ? Colors.white : AppColors.darkGrey,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: null,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: ClipOval(
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Image.asset(
                                    'assets/images/app_logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'IntelIWave',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDarkMode ? Colors.white : AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cardiac monitoring, made simple',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isLoading,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.darkGrey,
                          ),
                          decoration: InputDecoration(
                            hintText: 'name@example.com',
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                            ),
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                            ),
                            filled: true,
                            fillColor: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : AppColors.darkGrey,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            filled: true,
                            fillColor: isDarkMode ? AppColors.darkSurface3 : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _showForgotPasswordBottomSheet,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
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
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
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
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Or continue with',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: isDarkMode ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        onPressed: _isLoading ? null : _handleGoogleLogin,
                        logo: const GoogleLogo(size: 20),
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        onPressed: _isLoading ? null : _handleAppleLogin,
                        logo: Icon(
                          Icons.apple,
                          size: 26,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        onPressed: _isLoading ? null : _handleFacebookLogin,
                        logo: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1877F2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.facebook,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => Navigator.of(context).pushNamed('/register'),
                      child: RichText(
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            const TextSpan(
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
                  const SizedBox(height: 24),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: 'By using IntelIWave, you agree to the\n',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[500] : AppColors.grey,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context).pushNamed('/terms');
                              },
                          ),
                          TextSpan(
                            text: ' and ',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[500] : AppColors.grey,
                            ),
                          ),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context).pushNamed('/privacy');
                              },
                          ),
                          TextSpan(
                            text: '.',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[500] : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
            ), // Scaffold
            // ── Browser OAuth pending overlay ─────────────────────────────
            if (authProvider.isSocialAuthPending)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    margin: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkSurface3 : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Completing Sign In...',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please return to the app\nafter signing in with your browser.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.grey[400] : AppColors.grey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ], // Stack children
        ); // Stack
      }, // Consumer builder
    ); // Consumer
  }
}

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Paint paint = Paint()..isAntiAlias = true;

    // Shift by 0.05 and scale by 0.9 to stay within bounds
    double x(double val) => (0.05 + 0.9 * val) * s;
    double y(double val) => (0.05 + 0.9 * val) * s;

    // Draw Blue part (right side and bar)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(x(0.98), y(0.52))
      ..cubicTo(x(0.98), y(0.47), x(0.97), y(0.41), x(0.96), y(0.36))
      ..lineTo(x(0.50), y(0.36))
      ..lineTo(x(0.50), y(0.64))
      ..lineTo(x(0.77), y(0.64))
      ..cubicTo(x(0.76), y(0.71), x(0.71), y(0.79), x(0.64), y(0.84))
      ..lineTo(x(0.64), y(0.84))
      ..lineTo(x(0.78), y(0.95))
      ..cubicTo(x(0.90), y(0.84), x(0.98), y(0.68), x(0.98), y(0.52));
    canvas.drawPath(bluePath, paint);

    // Draw Green part (bottom)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(x(0.64), y(0.84))
      ..cubicTo(x(0.60), y(0.87), x(0.55), y(0.89), x(0.50), y(0.89))
      ..cubicTo(x(0.38), y(0.89), x(0.28), y(0.81), x(0.24), y(0.70))
      ..lineTo(x(0.10), y(0.81))
      ..cubicTo(x(0.18), y(0.97), x(0.33), y(1.00), x(0.50), y(1.00))
      ..cubicTo(x(0.64), y(1.00), x(0.72), y(0.96), x(0.78), y(0.95))
      ..lineTo(x(0.64), y(0.84));
    canvas.drawPath(greenPath, paint);

    // Draw Yellow part (left)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(x(0.24), y(0.70))
      ..cubicTo(x(0.22), y(0.64), x(0.21), y(0.58), x(0.21), y(0.50))
      ..cubicTo(x(0.21), y(0.42), x(0.22), y(0.36), x(0.24), y(0.30))
      ..lineTo(x(0.10), y(0.19))
      ..cubicTo(x(0.04), y(0.29), x(0.00), y(0.39), x(0.00), y(0.50))
      ..cubicTo(x(0.00), y(0.61), x(0.04), y(0.71), x(0.10), y(0.81))
      ..lineTo(x(0.24), y(0.70));
    canvas.drawPath(yellowPath, paint);

    // Draw Red part (top)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(x(0.24), y(0.30))
      ..cubicTo(x(0.28), y(0.19), x(0.38), y(0.11), x(0.50), y(0.11))
      ..cubicTo(x(0.62), y(0.11), x(0.72), y(0.16), x(0.79), y(0.24))
      ..lineTo(x(0.93), y(0.10))
      ..cubicTo(x(0.82), y(0.00), x(0.67), y(-0.05), x(0.50), y(-0.05))
      ..cubicTo(x(0.33), y(-0.05), x(0.18), y(0.03), x(0.10), y(0.19))
      ..lineTo(x(0.24), y(0.30));
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
