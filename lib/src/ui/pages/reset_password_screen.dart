import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../widgets/solar_auth_shell.dart';
import '../widgets/solar_primary_button.dart';
import '../widgets/solar_text_field.dart';
import 'sign_in_screen.dart';
import 'verification_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.forceRecoveryMode = false});

  static const routeName = '/reset-password';

  final bool forceRecoveryMode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isRecoveryMode(BuildContext context) {
    return widget.forceRecoveryMode ||
        SolarAppScope.of(context).isPasswordRecoveryActive;
  }

  Future<void> _sendResetEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SolarAppScope.of(
        context,
      ).sendResetPassword(email: _emailController.text);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VerificationScreen(
            details: VerificationDetails.resetPassword(
              email: _emailController.text.trim(),
            ),
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SolarAppScope.of(context).updateRecoveryPassword(
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please sign in.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecoveryMode = _isRecoveryMode(context);

    return SolarAuthShell(
      title: isRecoveryMode ? 'Create New Password' : 'Reset Password',
      subtitle: isRecoveryMode
          ? 'Choose a new password for your Solar account.'
          : 'Please enter your email address to request a password reset.',
      showBackButton: !isRecoveryMode,
      showBrand: false,
      child: Column(
        children: <Widget>[
          if (!isRecoveryMode)
            SolarTextField(
              controller: _emailController,
              hintText: 'abc@email.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
            ),
          if (isRecoveryMode)
            SolarTextField(
              controller: _newPasswordController,
              hintText: 'New password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
          if (isRecoveryMode) const SizedBox(height: 12),
          if (isRecoveryMode)
            SolarTextField(
              controller: _confirmPasswordController,
              hintText: 'Confirm new password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
          const SizedBox(height: 24),
          SolarPrimaryButton(
            label: isRecoveryMode ? 'Update password' : 'Send',
            isLoading: _isLoading,
            onPressed: isRecoveryMode ? _updatePassword : _sendResetEmail,
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
