import 'package:flutter/material.dart';

class AuthCheckingScreen extends StatelessWidget {
  const AuthCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Memory Map',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking your session...'),
            ],
          ),
        ),
      ),
    );
  }
}
