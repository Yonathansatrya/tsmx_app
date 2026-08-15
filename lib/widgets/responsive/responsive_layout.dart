import 'dart:math' as math;

import 'package:flutter/material.dart';

class TmsxResponsive {
  const TmsxResponsive._();

  static const double tabletBreakpoint = 600;
  static const double wideTabletBreakpoint = 840;
  static const double desktopBreakpoint = 1024;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isTablet(BuildContext context) =>
      widthOf(context) >= tabletBreakpoint;

  static bool isWideTablet(BuildContext context) =>
      widthOf(context) >= wideTabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= desktopBreakpoint;

  static double horizontalPadding(BuildContext context) {
    final width = widthOf(context);
    if (width < 360) return 12;
    if (width < tabletBreakpoint) return 16;
    if (width < wideTabletBreakpoint) return 24;
    return 32;
  }

  static double contentMaxWidth(BuildContext context) {
    final width = widthOf(context);
    if (width < tabletBreakpoint) return double.infinity;
    if (width < wideTabletBreakpoint) return 680;
    if (width < desktopBreakpoint) return 720;
    return 960;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 16,
    double bottom = 100,
  }) {
    final horizontal = horizontalPadding(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      math.max(bottom, bottomInset + 72),
    );
  }

  static int columnsFor(
    BuildContext context, {
    int phone = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return phone;
  }
}

class TmsxResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int phoneColumns;
  final int tabletColumns;
  final int wideTabletColumns;
  final int desktopColumns;

  const TmsxResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.phoneColumns = 1,
    this.tabletColumns = 2,
    this.wideTabletColumns = 2,
    this.desktopColumns = 3,
  });

  @override
  Widget build(BuildContext context) {
    final width = TmsxResponsive.widthOf(context);
    final columns = width >= TmsxResponsive.desktopBreakpoint
        ? desktopColumns
        : width >= TmsxResponsive.wideTabletBreakpoint
        ? wideTabletColumns
        : width >= TmsxResponsive.tabletBreakpoint
        ? tabletColumns
        : phoneColumns;

    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class TmsxResponsiveBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final Alignment alignment;

  const TmsxResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth =
        maxWidth ?? TmsxResponsive.contentMaxWidth(context);
    if (effectiveMaxWidth.isInfinite) return child;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: child,
      ),
    );
  }
}

class TmsxResponsiveFormGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int phoneColumns;
  final int tabletColumns;
  final int desktopColumns;

  const TmsxResponsiveFormGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.phoneColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 2,
  });

  @override
  Widget build(BuildContext context) {
    final columns = TmsxResponsive.columnsFor(
      context,
      phone: phoneColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
