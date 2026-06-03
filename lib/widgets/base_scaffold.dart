import 'package:flutter/material.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? drawer;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.drawer,
    this.bottom,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: TextStyle(
            color: buttonColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: buttonColor),
        bottom: bottom,
        actions: actions,
      ),
      drawer: drawer,
      body: body,
    );
  }
}
