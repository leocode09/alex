import 'package:flutter/material.dart';
import '../app_motion.dart';
import '../app_tokens.dart';

class AppPageScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final bool scrollable;
  final bool centerTitle;
  final bool includeSafeArea;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const AppPageScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.appBar,
    this.bottom,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.scrollable = false,
    this.centerTitle = false,
    this.includeSafeArea = true,
    this.padding = const EdgeInsets.all(AppTokens.space3),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: AnimatedSwitcher(
        duration: AppMotion.stateSwitch,
        switchInCurve: AppMotion.stateCurve,
        switchOutCurve: AppMotion.stateCurve,
        child: child,
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    if (includeSafeArea) {
      content = SafeArea(
        top: false,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar ?? _buildAppBar(),
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (title == null) {
      return null;
    }
    return AppBar(
      centerTitle: centerTitle,
      title: Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
      actions: actions,
      bottom: bottom,
    );
  }
}
