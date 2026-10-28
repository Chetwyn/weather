import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/location.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/state/selected_location_provider.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/error_view.dart';
import '../providers/search_providers.dart';
import '../state/search_state.dart';
import 'location_tile.dart';
import 'use_current_location_button.dart';

/// 搜索面板。
///
/// 用底部弹出面板而不是独立路由：选中地点属于「同一页面内的一次选择」，
/// 无需引入跨页面状态同步。
class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key});

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _select(Location location) async {
    await ref.read(selectedLocationProvider.notifier).select(location);
    await ref.read(recentSearchesProvider.notifier).add(location);
    ref.read(searchQueryProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  /// 定位成功：地点已由 notifier 写入，这里只做收尾——
  /// 清掉输入（否则下次打开面板还留着上一个关键词）并关闭面板。
  void _handleLocated() {
    ref.read(searchQueryProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  void _clearInput() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationSearchProvider);
    final recent = ref.watch(recentSearchesProvider);
    final query = ref.watch(searchQueryProvider);
    final strings = AppStrings.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        // 面板自带一层 ScaffoldMessenger + Scaffold：
        // `ScaffoldMessenger.of(context)` 默认会找到首页那个 Scaffold，
        // 提示会被整个面板盖住（键盘弹起后更看不见）。
        // 面板内自己承载，SnackBar 就落在面板底部、键盘上方。
        child: ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // 键盘高度已由外层 Padding 让出，这里再缩一次会把列表挤没。
            resizeToAvoidBottomInset: false,
            body: Column(
              children: <Widget>[
                const SizedBox(height: AppTokens.spacingSm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTokens.spacingMd),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: strings.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: strings.clearInput,
                              icon: const Icon(Icons.close),
                              onPressed: _clearInput,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                    ),
                    onChanged: ref.read(searchQueryProvider.notifier).update,
                  ),
                ),
                const Divider(height: 1),
                // 常驻入口：不随搜索状态隐藏，任何时候都能切回本地天气。
                UseCurrentLocationTile(onLocated: _handleLocated),
                const Divider(height: 1),
                Expanded(child: _buildBody(state, recent, strings)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    SearchState state,
    List<Location> recent,
    AppStrings strings,
  ) {
    switch (state) {
      case SearchIdle():
        if (recent.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spacingLg),
              child: Text(strings.emptyHint, textAlign: TextAlign.center),
            ),
          );
        }
        return ListView(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spacingMd,
                AppTokens.spacingMd,
                AppTokens.spacingMd,
                AppTokens.spacingSm,
              ),
              child: Text(
                strings.recentSearches,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            ...recent.map(
              (Location location) => LocationTile(
                key: ValueKey<int>(location.id),
                location: location,
                onTap: () => _select(location),
                onRemove: () =>
                    ref.read(recentSearchesProvider.notifier).remove(location),
              ),
            ),
          ],
        );

      case SearchTooShort():
        return Center(child: Text(strings.searchTooShort));

      case SearchLoading():
        return const Center(child: CircularProgressIndicator());

      case SearchResults(:final List<Location> results):
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (BuildContext context, int index) {
            final location = results[index];
            return LocationTile(
              key: ValueKey<int>(location.id),
              location: location,
              onTap: () => _select(location),
            );
          },
        );

      case SearchEmpty(:final String query):
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spacingLg),
            child: Text(
              '${strings.searchNoResultPrefix}「$query」'
              '${strings.searchNoResultSuffix}',
              textAlign: TextAlign.center,
            ),
          ),
        );

      case SearchError(:final failure):
        return ErrorView(
          failure: failure,
          onRetry: () => ref.read(locationSearchProvider.notifier).retry(),
        );
    }
  }
}
