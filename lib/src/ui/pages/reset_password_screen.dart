import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../widgets/solar_auth_shell.dart';
import '../widgets/solar_primary_button.dart';
import '../widgets/solar_text_field.dart';
import 'verification_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  static const routeName = '/reset-password';

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return SolarAuthShell(
      title: 'Reset Password',
      subtitle: 'Please enter your email address to request a password reset.',
      showBackButton: true,
      showBrand: false,
      child: Column(
        children: <Widget>[
          SolarTextField(
            controller: _emailController,
            hintText: 'abc@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          SolarPrimaryButton(
            label: 'Send',
            isLoading: _isLoading,
            onPressed: _sendResetEmail,
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
