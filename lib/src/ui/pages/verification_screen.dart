import 'package:flutter/material.dart';

import '../widgets/solar_auth_shell.dart';
import '../widgets/solar_primary_button.dart';
import 'sign_in_screen.dart';

enum VerificationKind { signUp, resetPassword }

class VerificationDetails {
  const VerificationDetails({
    required this.kind,
    required this.title,
    required this.message,
    required this.email,
    required this.primaryActionLabel,
  });

  final VerificationKind kind;
  final String title;
  final String message;
  final String email;
  final String primaryActionLabel;

  factory VerificationDetails.signUp({required String email}) {
    return VerificationDetails(
      kind: VerificationKind.signUp,
      title: 'Verification',
      message:
          "We've sent a verification link to $email. Open it from your inbox, then come back and sign in.",
      email: email,
      primaryActionLabel: 'Back to sign in',
    );
  }

  factory VerificationDetails.resetPassword({required String email}) {
    return VerificationDetails(
      kind: VerificationKind.resetPassword,
      title: 'Verification',
      message:
          "We've sent a password reset link to $email. Open it on this device and Solar will bring you to the new password screen.",
      email: email,
      primaryActionLabel: 'Back to sign in',
    );
  }
}

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({required this.details, super.key});

  static const routeName = '/verification';

  final VerificationDetails details;

  @override
  Widget build(BuildContext context) {
    return SolarAuthShell(
      title: details.title,
      subtitle: details.message,
      showBackButton: true,
      showBrand: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 24),
          SolarPrimaryButton(
            label: details.primaryActionLabel,
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
