import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/weather/presentation/screens/home_screen.dart';

/// 路由表。
///
/// 当前只有单页，仍用 go_router 声明式管理，为后续「城市管理页 / 设置页」
/// 预留扩展点。
final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
  ],
);
