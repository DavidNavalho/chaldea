import 'package:flutter/material.dart';

import 'package:chaldea/custom/box_coverage/box_coverage_page.dart';

class CustomGalleryItemDefinition {
  final String name;
  final String title;
  final IconData icon;
  final String? url;
  final Widget page;
  final bool isDetail;
  final bool shownDefault;

  const CustomGalleryItemDefinition({
    required this.name,
    required this.title,
    required this.icon,
    required this.url,
    required this.page,
    required this.isDetail,
    this.shownDefault = true,
  });
}

class CustomRouteDefinition {
  final String path;
  final Widget page;
  final bool isMasterRoute;

  const CustomRouteDefinition({required this.path, required this.page, this.isMasterRoute = false});
}

class CustomIntegration {
  static const String myBoxCoverageRoute = '/my-box-coverage';

  static const List<CustomGalleryItemDefinition> galleryItems = [
    CustomGalleryItemDefinition(
      name: 'my_box_coverage',
      title: 'My Box Coverage',
      icon: Icons.table_chart_outlined,
      url: myBoxCoverageRoute,
      page: BoxCoveragePage(),
      isDetail: true,
    ),
  ];

  static const List<CustomRouteDefinition> routes = [
    CustomRouteDefinition(path: myBoxCoverageRoute, page: BoxCoveragePage()),
  ];

  static bool isMasterRoute(String? path) {
    if (path == null) return false;
    for (final route in routes) {
      if (route.path == path && route.isMasterRoute) return true;
    }
    return false;
  }

  static Widget? resolveRoute(String? path) {
    if (path == null) return null;
    for (final route in routes) {
      if (route.path == path) return route.page;
    }
    return null;
  }
}
