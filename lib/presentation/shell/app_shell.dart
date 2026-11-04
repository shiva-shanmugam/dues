import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/presentation/pages/home_page.dart';
import 'package:dues/presentation/pages/settings_page.dart';
import 'package:dues/presentation/pages/subscriptions_page.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/widgets/dot_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const pages = [HomePage(), SubscriptionsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);
    return Scaffold(
      body: DotGrid(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: selected, children: pages),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        selected: selected,
        onSelect: (index) {
          HapticFeedback.selectionClick();
          ref.read(selectedTabProvider.notifier).select(index);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      (Icons.home_outlined, Icons.home, 'HOME'),
      (Icons.view_list_outlined, Icons.view_list, 'SUBS'),
      (Icons.tune_outlined, Icons.tune, 'SETTINGS'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: DuesColors.black,
        border: Border(top: BorderSide(color: DuesColors.outline)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          for (var index = 0; index < destinations.length; index++)
            Expanded(
              child: Semantics(
                selected: selected == index,
                button: true,
                child: InkWell(
                  key: ValueKey('nav-$index'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: selected == index
                          ? DuesColors.surfaceRaised
                          : Colors.transparent,
                      border: Border.all(
                        color: selected == index
                            ? DuesColors.outline
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected == index
                              ? destinations[index].$2
                              : destinations[index].$1,
                          size: 20,
                          color: selected == index
                              ? DuesColors.red
                              : DuesColors.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          destinations[index].$3,
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: .8,
                            fontWeight: FontWeight.bold,
                            color: selected == index
                                ? DuesColors.offWhite
                                : DuesColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
