import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'pages/home_page.dart';
import 'pages/explore_page.dart';

class HomeShell extends StatefulWidget {
  static const String route = '/home';
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const ExplorePage(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizbit'),
      ),
      drawer: _AppDrawer(onNavigate: (route) {
        if (route == ProfileScreen.route) {
          setState(() => _currentIndex = 2);
        }
        Navigator.of(context).pop();
      }),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category),
              label: 'Explore'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final void Function(String route) onNavigate;
  const _AppDrawer({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().userName ?? 'Guest';
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user),
            accountEmail: const Text(''),
            currentAccountPicture:
                const CircleAvatar(child: Icon(Icons.person)),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () => onNavigate(ProfileScreen.route),
          ),
          if (context.watch<AuthState>().isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin Panel'),
              onTap: () => Navigator.of(context).pushNamed('/admin'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await context.read<AuthState>().logout();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(LoginScreen.route, (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
