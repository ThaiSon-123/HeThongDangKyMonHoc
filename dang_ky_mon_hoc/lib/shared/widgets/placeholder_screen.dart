import 'package:flutter/material.dart';

/// Màn hình giữ chỗ cho skeleton Pha 0 — chức năng thật ở các pha sau.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('$title — đang phát triển'),
          ],
        ),
      ),
    );
  }
}
