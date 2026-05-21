import 'package:flutter/material.dart';

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? drawer;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.drawer,
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
        backgroundColor: Color(0xFFFAF5EF),
        elevation: 0,
        iconTheme: IconThemeData(color: buttonColor),
      ),
      drawer: drawer,
      body: body,
    );
  }
}
