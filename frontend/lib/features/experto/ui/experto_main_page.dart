import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';
import 'package:vinas_mobile/shared/widgets/vitia_header.dart';
import 'validaciones_page.dart';
import 'anotacion_dataset_page.dart';
import 'experto_mapa_page.dart';

class ExpertoMainPage extends StatefulWidget {
  const ExpertoMainPage({super.key});

  @override
  State<ExpertoMainPage> createState() => _ExpertoMainPageState();
}

class _ExpertoMainPageState extends State<ExpertoMainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ValidacionesPage(),
    const AnotacionDatasetPage(),
    const ExpertoMapaPage(),
  ];

  final List<String> _titles = [
    "Validaciones",
    "Dataset",
    "Mapa Global",
  ];

  @override
  Widget build(BuildContext context) {
    const Color darkBarColor = AppColors.negroVitIA;
    const Color activeTabColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_currentIndex != 2)
              VitiaHeader(
                title: _titles[_currentIndex],
                actionIcon: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.negroVitIA, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        child: Container(
          decoration: BoxDecoration(
            color: darkBarColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: darkBarColor.withValues(alpha: 0.5),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: GNav(
              gap: 8,
              color: Colors.white70,
              activeColor: Colors.black,
              tabBackgroundColor: activeTabColor,
              tabBorderRadius: 100,
              padding: const EdgeInsets.all(12),
              selectedIndex: _currentIndex,
              onTabChange: (index) {
                setState(() => _currentIndex = index);
              },
              tabs: const [
                GButton(
                  icon: Icons.pending_actions_rounded,
                  iconSize: 28,
                ),
                GButton(
                  icon: Icons.dataset_rounded,
                  iconSize: 28,
                ),
                GButton(
                  icon: Icons.map_rounded,
                  iconSize: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
