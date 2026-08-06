import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../app_motion.dart';
import '../app_tokens.dart';
import '../glass/glass_background.dart';

class AppPageScaffold extends StatefulWidget {
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
  State<AppPageScaffold> createState() => _AppPageScaffoldState();
}

class _AppPageScaffoldState extends State<AppPageScaffold> {
  // Stable across rebuilds so the shared backdrop layer used by every glass
  // panel on this page (via BackdropFilter.grouped) is not re-created.
  final BackdropKey _backdropKey = BackdropKey();

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: widget.padding,
      child: AnimatedSwitcher(
        duration: AppMotion.stateSwitch,
        switchInCurve: AppMotion.stateCurve,
        switchOutCurve: AppMotion.stateCurve,
        child: widget.child,
      ),
    );

    if (widget.scrollable) {
      content = SingleChildScrollView(child: content);
    }

    if (widget.includeSafeArea) {
      content = SafeArea(
        top: false,
        child: content,
      );
    }

    return Stack(
      children: [
        const Positioned.fill(child: GlassBackground()),
        Scaffold(
          backgroundColor: widget.backgroundColor ?? Colors.transparent,
          appBar: widget.appBar ?? _buildAppBar(),
          drawer: widget.drawer,
          floatingActionButton: widget.floatingActionButton,
          bottomNavigationBar: widget.bottomNavigationBar,
          body: BackdropGroup(
            backdropKey: _backdropKey,
            child: content,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (widget.title == null) {
      return null;
    }
    return AppBar(
      centerTitle: widget.centerTitle,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: AppTokens.blurBar,
            sigmaY: AppTokens.blurBar,
          ),
          child: const SizedBox.expand(),
        ),
      ),
      title: Text(
        widget.title!,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      actions: widget.actions,
      bottom: widget.bottom,
    );
  }
}
