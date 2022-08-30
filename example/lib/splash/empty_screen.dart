import 'package:flutter/material.dart';

/// LoadingScreen is a preview screen when there is no data available.
class EmptyScreen extends StatelessWidget {
  const EmptyScreen({
    Key? key,
    this.parent = false,
  }) : super(key: key);
  final bool parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Scaffold(
      primary: parent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Flex(
            direction: Axis.vertical,
            children: [
              Text(
                'Hmmm',
                style: textTheme.displaySmall,
              ),
              const SizedBox(height: 32),
              Text(
                'There is nothing here.',
                style: textTheme.subtitle1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
