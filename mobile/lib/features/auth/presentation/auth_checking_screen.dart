import 'package:flutter/material.dart';
import 'package:memory_map/features/auth/presentation/memory_map_brand_mark.dart';

class AuthCheckingScreen extends StatelessWidget {
  const AuthCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: memoryMapWarmBackground,
      body: SafeArea(
        child: Center(
          child: MemoryMapBrandMark(
            pinKey: ValueKey('auth-checking.memory-map.logo'),
          ),
        ),
      ),
    );
  }
}
