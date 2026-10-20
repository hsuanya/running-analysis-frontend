import 'package:flutter/material.dart';

class RoundedBoxWidget extends StatelessWidget {
  const RoundedBoxWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Theme.of(context).primaryColor,
      ),
      child: child,
    );
  }
}
