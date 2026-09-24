// Equivalent two-screen size fixture. See doc/performance.md.
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Screen('Home')));

class Screen extends StatelessWidget {
  const Screen(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const Screen('Detail')),
          ),
          child: Text(label),
        ),
      );
}
