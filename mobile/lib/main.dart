import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/app/app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MemoryMapApp(),
    ),
  );
}
