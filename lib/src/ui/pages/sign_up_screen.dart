import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../widgets/solar_auth_shell.dart';
import '../widgets/solar_primary_button.dart';
import '../widgets/solar_text_field.dart';
import 'sign_in_screen.dart';
import 'verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  static const routeName = '/sign-up';

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _teamNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _teamNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SolarAppScope.of(context).signUp(
        fullName: _fullNameController.text,
        email: _emailController.text,
        teamNumber: _teamNumberController.text,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VerificationScreen(
            details: VerificationDetails.signUp(
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
    final theme = Theme.of(context);

    return SolarAuthShell(
      title: 'Sign up',
      showBackButton: true,
      child: Column(
        children: <Widget>[
          SolarTextField(
            controller: _fullNameController,
            hintText: 'Full name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          SolarTextField(
            controller: _emailController,
            hintText: 'abc@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          SolarTextField(
            controller: _teamNumberController,
            hintText: 'Team Number',
            icon: Icons.tag_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          SolarTextField(
            controller: _passwordController,
            hintText: 'Your password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          SolarTextField(
            controller: _confirmPasswordController,
            hintText: 'Confirm password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),
          SolarPrimaryButton(
            label: 'Sign up',
            isLoading: _isLoading,
            onPressed: _signUp,
          ),
          const SizedBox(height: 28),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Already have an account?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5E647A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const SignInScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign in',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF0D6B81),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
