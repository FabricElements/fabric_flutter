import 'package:flutter/material.dart';

import 'content_container.dart';

class StepperExtended extends StatefulWidget {
  const StepperExtended({
    Key? key,
    required this.steps,
    this.size = ContentContainerSize.medium,
  }) : super(key: key);
  final List<Step> steps;
  final ContentContainerSize size;

  @override
  State<StepperExtended> createState() => _StepperExtendedState();
}

class _StepperExtendedState extends State<StepperExtended> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    List<Widget> children = List.generate(widget.steps.length, (index) {
      Step step = widget.steps[index];
      TextStyle? leadingStyle = textTheme.subtitle1?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      );
      Widget leadingContent = const SizedBox();
      const iconColor = Colors.white;
      const iconSize = 18.0;
      Color leadingColor = Colors.grey.shade800;
      switch (step.state) {
        // case StepState.indexed:
        // case StepState.disabled:
        case StepState.editing:
          leadingContent = const Icon(
            Icons.edit,
            color: iconColor,
            size: iconSize,
          );
          break;
        case StepState.complete:
          leadingContent = const Icon(
            Icons.check,
            color: iconColor,
            size: iconSize,
          );
          leadingColor = Colors.teal;
          break;
        case StepState.error:
          leadingContent = Text('!', style: leadingStyle);
          leadingColor = Colors.red;
          break;
        default:
          leadingContent = Text(
            (index + 1).toString(),
            style: leadingStyle,
          );
          break;
      }

      Widget leading = Container(
        width: 32.0,
        height: 32.0,
        decoration: BoxDecoration(
          color: leadingColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: leadingContent,
        ),
      );
      return ContentContainer(
        margin: const EdgeInsets.only(top: 16, bottom: 32, left: 0, right: 16),
        size: widget.size,
        child: Flex(
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: leading,
              title: step.title,
              subtitle: step.subtitle,
              minLeadingWidth: 32,
            ),
            Container(
              padding: const EdgeInsets.only(left: 32),
              margin: const EdgeInsets.only(left: 32),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: step.content,
            )
          ],
        ),
      );
    });

    return ListView(
      children: children,
    );
  }
}
