import 'package:flutter/material.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? drawer;
  final PreferredSizeWidget? bottom;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.drawer,
    this.bottom,
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
      ),
      drawer: drawer,
      body: body,
    );
  }
}
