import 'package:flutter/material.dart';

import '../data/case_state.dart';
import '../data/notifications.dart';
import '../data/treatments.dart';
import 'router.dart';
import 'theme.dart';

/// Port of react-js/src/components/app-shell.tsx
///
/// Hosts the profile header + notification bell, the bottom navigation
/// (Dashboard/History/Treatment/Feeding), the Techi AI floating button on the
/// dashboard, and hides all chrome on Techi chat routes.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child, required this.currentRoute});

  final Widget child;
  final String currentRoute;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    CaseStateStore.instance.load();
    TreatmentStore.instance.load();
    NotificationsModel.instance.addListener(_onStoresChanged);
  }

  @override
  void dispose() {
    NotificationsModel.instance.removeListener(_onStoresChanged);
    super.dispose();
  }

  void _onStoresChanged() {
    if (mounted) setState(() {});
  }

  bool get _isStandalone =>
      widget.currentRoute.startsWith('${FutechiRoutes.techi}/') ||
      widget.currentRoute == FutechiRoutes.techi ||
      widget.currentRoute == FutechiRoutes.batchRegistration;

  @override
  Widget build(BuildContext context) {
    if (_isStandalone) return widget.child;
    return Scaffold(
      appBar: _buildHeader(context),
      body: widget.child,
      floatingActionButton: widget.currentRoute == FutechiRoutes.dashboard
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context)
                  .pushNamed('${FutechiRoutes.techi}/dashboard'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              splashColor: Colors.transparent,
              tooltip: 'Techi AI',
              child: Image.asset(
                'assets/images/icon_chatbot.png',
                width: 54,
                height: 54,
                fit: BoxFit.contain,
              ),
            )
          : null,
      bottomNavigationBar: _BottomNav(currentRoute: widget.currentRoute),
    );
  }

  PreferredSizeWidget _buildHeader(BuildContext context) {
    final unread = NotificationsModel.instance.unread;
    return AppBar(
      backgroundColor: FutechiColors.card,
      surfaceTintColor: FutechiColors.card,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: InkWell(
        onTap: () => Navigator.of(context).pushNamed(FutechiRoutes.profile),
        borderRadius: BorderRadius.circular(12),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: FutechiColors.secondarySoft,
              child: Text(
                'M',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: FutechiColors.primary,
                ),
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mulyo',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Manajer Kandang',
                    style: TextStyle(
                        fontSize: 12, color: FutechiColors.mutedForeground)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context)
                    .pushNamed(FutechiRoutes.notifications),
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifikasi',
              ),
              if (unread > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: FutechiColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FutechiColors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem(this.route, this.label, this.icon);
  final String route;
  final String label;
  final IconData icon;
}

const _navItems = [
  _NavItem(FutechiRoutes.dashboard, 'Dashboard', Icons.home_outlined),
  _NavItem(FutechiRoutes.history, 'History', Icons.history_outlined),
  _NavItem(
      FutechiRoutes.treatment, 'Treatment', Icons.medical_services_outlined),
  _NavItem(FutechiRoutes.feeding, 'Feeding', Icons.rice_bowl_outlined),
];

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentRoute});
  final String currentRoute;

  bool _isActive(_NavItem item) => item.route == FutechiRoutes.dashboard
      ? currentRoute == FutechiRoutes.dashboard
      : currentRoute.startsWith(item.route);

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: FutechiColors.card,
        indicatorColor: FutechiColors.primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: FutechiColors.onPrimary,
              size: 22,
            );
          }
          return const IconThemeData(
            color: FutechiColors.mutedForeground,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? FutechiColors.primary
                  : FutechiColors.mutedForeground,
            )),
      ),
      child: NavigationBar(
        elevation: 0,
        backgroundColor: FutechiColors.card,
        selectedIndex:
            _navItems.indexWhere(_isActive).clamp(0, _navItems.length - 1),
        onDestinationSelected: (index) {
          final target = _navItems[index].route;
          final current = currentRoute;
          if (current == target) return;
          // From detail pages, replace the stack so back does not jump tabs.
          Navigator.of(context)
              .pushNamedAndRemoveUntil(target, (route) => route.isFirst);
        },
        destinations: [
          for (final item in _navItems)
            NavigationDestination(
              icon: Icon(item.icon,
                  size: 22, color: FutechiColors.mutedForeground),
              selectedIcon:
                  Icon(item.icon, size: 22, color: FutechiColors.onPrimary),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
