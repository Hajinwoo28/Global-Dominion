import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(const GlobalDominion());
}

class GlobalDominion extends StatelessWidget {
  const GlobalDominion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Dominion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/game': (context) => const GameScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// ─────────────────────────────────────────────
// SPLASH SCREEN — auto-navigates to HomeScreen
// ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)),
    );

    _controller.forward();

    // Auto-navigate to home after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          // Tap to skip splash
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => FadeTransition(
            opacity: _fadeIn,
            child: ScaleTransition(
              scale: _pulseScale,
              child: child,
            ),
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/world_map.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.65),
                  ],
                ),
              ),
              child: const Align(
                alignment: Alignment(0, 0.85),
                child: Text(
                  'TAP TO CONTINUE',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME / MAIN MENU SCREEN
// ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _menuController;
  late List<Animation<Offset>> _slideAnimations;

  final List<_MenuItem> _menuItems = [
    _MenuItem(label: 'START GAME', icon: Icons.flag_rounded, route: '/game'),
    _MenuItem(label: 'SETTINGS', icon: Icons.settings_rounded, route: '/settings'),
    _MenuItem(label: 'QUIT', icon: Icons.power_settings_new_rounded, route: null),
  ];

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnimations = List.generate(_menuItems.length, (i) {
      final start = i * 0.2;
      final end = start + 0.6;
      return Tween<Offset>(
        begin: const Offset(0, 0.6),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _menuController,
        curve: Interval(start.clamp(0, 1), end.clamp(0, 1), curve: Curves.easeOutCubic),
      ));
    });

    _menuController.forward();
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _onMenuTap(_MenuItem item) {
    if (item.route == null) {
      _showQuitDialog();
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => item.route == '/game'
              ? const GameScreen()
              : const SettingsScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
        ),
      );
    }
  }

  void _showQuitDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1208),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFAA8820), width: 2),
        ),
        title: const Text(
          'QUIT GAME?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        content: const Text(
          'Are you sure you want to exit Global Dominion?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAA3300),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => SystemNavigator.pop(),
            child: const Text('QUIT', style: TextStyle(letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/world_map.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.25),
                Colors.black.withOpacity(0.75),
              ],
            ),
          ),
          child: Row(
            children: [
              // Left spacer
              const Expanded(child: SizedBox()),
              // Center menu panel
              SizedBox(
                width: 320,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ...List.generate(_menuItems.length, (i) {
                      return SlideTransition(
                        position: _slideAnimations[i],
                        child: FadeTransition(
                          opacity: _menuController,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _MenuButtonWidget(
                              item: _menuItems[i],
                              onTap: () => _onMenuTap(_menuItems[i]),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
              // Right spacer
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final String? route;
  const _MenuItem({required this.label, required this.icon, this.route});
}

class _MenuButtonWidget extends StatefulWidget {
  final _MenuItem item;
  final VoidCallback onTap;

  const _MenuButtonWidget({required this.item, required this.onTap});

  @override
  State<_MenuButtonWidget> createState() => _MenuButtonWidgetState();
}

class _MenuButtonWidgetState extends State<_MenuButtonWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _hovered ? 310 : 290,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFFB8860B), const Color(0xFFFFD700), const Color(0xFFB8860B)]
                  : [const Color(0xFF5C4008), const Color(0xFF9A6F0A), const Color(0xFF5C4008)],
            ),
            border: Border.all(
              color: _hovered ? const Color(0xFFFFD700) : const Color(0xFF8B6914),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: _hovered
                ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.45), blurRadius: 18, spreadRadius: 2)]
                : [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.item.icon,
                  color: _hovered ? Colors.white : Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _hovered ? Colors.white : Colors.white70,
                  letterSpacing: 2.5,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GAME SCREEN (placeholder — build your game here)
// ─────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  String _status = 'Initializing command center...';

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addListener(() {
        setState(() {
          final progress = _progressController.value;
          if (progress < 0.25) {
            _status = 'Booting satellite network...';
          } else if (progress < 0.55) {
            _status = 'Deploying reconnaissance teams...';
          } else if (progress < 0.85) {
            _status = 'Activating command protocols...';
          } else {
            _status = 'Ready for global engagement.';
          }
        });
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progressController.value;
    final isReady = progress >= 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // Background tint
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [Color(0xFF1A2A1A), Color(0xFF0D1117)],
              ),
            ),
          ),
          // Top bar
          SafeArea(
            child: Column(
              children: [
                _GameTopBar(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public_rounded, size: 80, color: Color(0xFF4A7040)),
                        const SizedBox(height: 24),
                        const Text(
                          'YOUR EMPIRE AWAITS',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _status,
                          style: const TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: 280,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF14221A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF314130)),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: FractionallySizedBox(
                                  widthFactor: progress,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${(progress * 100).round()}% complete',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 32),
                        if (isReady)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: const Color(0xFF0B0B0B),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => const CommandCenterScreen(),
                                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                                ),
                              );
                            },
                            child: const Text(
                              'ENTER COMMAND CENTER',
                              style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E0A),
        border: Border(bottom: BorderSide(color: Color(0xFF2A3A2A), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700), size: 18),
            tooltip: 'Back to Menu',
          ),
          const SizedBox(width: 8),
          const Text(
            'GLOBAL DOMINION',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          // Resource bar placeholders
          _ResourceChip(icon: Icons.grain_rounded, label: '1,200', color: const Color(0xFFFFD700)),
          const SizedBox(width: 16),
          _ResourceChip(icon: Icons.people_rounded, label: '850', color: const Color(0xFF4FC3F7)),
          const SizedBox(width: 16),
          _ResourceChip(icon: Icons.shield_rounded, label: '300', color: const Color(0xFFEF9A9A)),
        ],
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ResourceChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFF090D13),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293C), width: 1.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700), size: 18),
                    tooltip: 'Back to Menu',
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'COMMAND CENTER',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  _ResourceChip(icon: Icons.grain_rounded, label: '1,200', color: const Color(0xFFFFD700)),
                  const SizedBox(width: 18),
                  _ResourceChip(icon: Icons.people_rounded, label: '850', color: const Color(0xFF4FC3F7)),
                  const SizedBox(width: 18),
                  _ResourceChip(icon: Icons.shield_rounded, label: '300', color: const Color(0xFFEF9A9A)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OMEGA DIVISION',
                            style: TextStyle(
                              color: Color(0xFFC9B96A),
                              letterSpacing: 2.4,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Global Strategy Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Monitor territory control, manage elite units, and deploy battle plans from the command center. Your nation’s strategic priority board is live.',
                            style: TextStyle(color: Color(0xFFB0B7C5), fontSize: 16, height: 1.85),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              _DashboardCard(
                                title: 'Territories',
                                value: '16 / 24',
                                accent: Color(0xFFFFD700),
                                subtitle: 'Controlled regions',
                              ),
                              const SizedBox(width: 18),
                              _DashboardCard(
                                title: 'Allies',
                                value: '4',
                                accent: Color(0xFF4FC3F7),
                                subtitle: 'Active pacts',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Mission Briefing',
                            style: TextStyle(
                              color: Color(0xFFF4E19C),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1620),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF1E2A3A)),
                            ),
                            child: const Text(
                              'Enemy forces are concentrated on the eastern front. Deploy recon sweeps and prepare armored units for the next wave. Maintain supply lines and secure key ports before dusk.',
                              style: TextStyle(color: Color(0xFFCAD3E0), fontSize: 15, height: 1.75),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              _ActionButton(
                                label: 'Deploy Army',
                                color: const Color(0xFFFFD700),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const DeployArmyScreen(),
                                      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              _ActionButton(
                                label: 'Open World Map',
                                color: const Color(0xFF4FC3F7),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const WorldMapScreen(),
                                      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF101C29), Color(0xFF071018)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: const Color(0xFF1F2B38)),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: 0.12,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage('assets/images/world_map.jpg'),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Active Battle Zones',
                                          style: TextStyle(
                                            color: Color(0xFFF4E19C),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              _MapRegionBadge(label: 'Northern Front', status: 'Engaged'),
                                              const SizedBox(width: 12),
                                              _MapRegionBadge(label: 'Coastal Port', status: 'Reinforce'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1620),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF1E2A3A)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Intel Feed',
                                  style: TextStyle(
                                    color: Color(0xFFF4E19C),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                SizedBox(height: 14),
                                Text('Air surveillance detected increased movement near the western border.', style: TextStyle(color: Color(0xFFB0B7C5), height: 1.7)),
                                SizedBox(height: 12),
                                Text('Naval convoys are ready for port deployment within 12 hours.', style: TextStyle(color: Color(0xFFB0B7C5), height: 1.7)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;
  final String subtitle;

  const _DashboardCard({required this.title, required this.value, required this.accent, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF0F1620),
          border: Border.all(color: const Color(0xFF1E2A3A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF92A1C2), fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(color: accent, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Color(0xFFB0B7C5), fontSize: 13, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF061010),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DeploymentStat extends StatelessWidget {
  final String label;
  final String value;

  const _DeploymentStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFB0B7C5), fontSize: 14)),
        Text(value, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class DeployArmyScreen extends StatelessWidget {
  const DeployArmyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D13),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Deploy Army', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deployment Command',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Select a strike force and launch your next ground operation from the forward staging zone.',
              style: TextStyle(color: Color(0xFFB0B7C5), fontSize: 16, height: 1.7),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1620),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF1E2A3A)),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Armored Division', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          const Text('Heavy tanks and mechanized infantry ready for frontal assault.', style: TextStyle(color: Color(0xFFB0B7C5), height: 1.6)),
                          const SizedBox(height: 18),
                          _DeploymentStat(label: 'Strength', value: '89%'),
                          const SizedBox(height: 10),
                          _DeploymentStat(label: 'Speed', value: '57 km/h'),
                          const SizedBox(height: 10),
                          _DeploymentStat(label: 'Supplies', value: '94%'),
                          const Spacer(),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: const Color(0xFF0B0B0B),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () {},
                            child: const Text('DEPLOY NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1620),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF1E2A3A)),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recon Squadron', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          const Text('Light airborne units prepared to survey enemy positions and relay battlefield intel.', style: TextStyle(color: Color(0xFFB0B7C5), height: 1.6)),
                          const SizedBox(height: 18),
                          _DeploymentStat(label: 'Range', value: '420 km'),
                          const SizedBox(height: 10),
                          _DeploymentStat(label: 'Detection', value: 'High'),
                          const SizedBox(height: 10),
                          _DeploymentStat(label: 'Stealth', value: '79%'),
                          const Spacer(),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4FC3F7),
                              foregroundColor: const Color(0xFF061010),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () {},
                            child: const Text('LAUNCH RECON', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D13),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('World Map', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Global Tactical Map',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Review contested zones, track allied movements, and plan your next continental push.',
              style: TextStyle(color: Color(0xFFB0B7C5), fontSize: 16, height: 1.7),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/world_map.jpg', fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.6)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 26,
                      top: 26,
                      right: 26,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Enemy forces are most active in the northern front. Dispatch strike teams or redirect reserves as needed.',
                          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.7),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 24,
                      child: _MapIndicator(label: 'Northern Front', status: 'Engaged', color: const Color(0xFFFFD700)),
                    ),
                    Positioned(
                      right: 24,
                      bottom: 24,
                      child: _MapIndicator(label: 'Coastal Port', status: 'Reinforce', color: const Color(0xFF4FC3F7)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1620),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF1E2A3A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Allied Presence', style: TextStyle(color: Color(0xFFF4E19C), fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('Three allied fleets are positioned along the southern coast.', style: TextStyle(color: Color(0xFFB0B7C5), height: 1.6)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1620),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF1E2A3A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Resource Flow', style: TextStyle(color: Color(0xFFF4E19C), fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('Supply lines are stable for 18 hours. Continue advancing before reserves are depleted.', style: TextStyle(color: Color(0xFFB0B7C5), height: 1.6)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapIndicator extends StatelessWidget {
  final String label;
  final String status;
  final Color color;

  const _MapIndicator({required this.label, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MapRegionBadge extends StatelessWidget {
  final String label;
  final String status;

  const _MapRegionBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E2A3A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Text(status, style: const TextStyle(color: Color(0xFFF4E19C), fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('ENGAGED', style: TextStyle(color: Color(0xFFD4B86F), fontSize: 12, letterSpacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _musicVol = 0.7;
  double _sfxVol = 0.9;
  bool _fullscreen = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1208), Color(0xFF0D0D0D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF3A2800), width: 1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFFFD700)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'SETTINGS',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              // Settings body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(32),
                  children: [
                    _SettingsSection(
                      title: 'AUDIO',
                      children: [
                        _SliderSetting(
                          label: 'Music Volume',
                          icon: Icons.music_note_rounded,
                          value: _musicVol,
                          onChanged: (v) => setState(() => _musicVol = v),
                        ),
                        _SliderSetting(
                          label: 'SFX Volume',
                          icon: Icons.surround_sound_rounded,
                          value: _sfxVol,
                          onChanged: (v) => setState(() => _sfxVol = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _SettingsSection(
                      title: 'DISPLAY',
                      children: [
                        _ToggleSetting(
                          label: 'Fullscreen Mode',
                          icon: Icons.fullscreen_rounded,
                          value: _fullscreen,
                          onChanged: (v) => setState(() => _fullscreen = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFAA8820),
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1208),
            border: Border.all(color: const Color(0xFF3A2800)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label, required this.icon,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(width: 14),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFFD700),
                inactiveTrackColor: const Color(0xFF3A2800),
                thumbColor: const Color(0xFFFFD700),
                overlayColor: const Color(0x33FFD700),
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
          Text('${(value * 100).round()}%',
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSetting({
    required this.label, required this.icon,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFFD700),
            activeTrackColor: const Color(0xFF3A2800),
          ),
        ],
      ),
    );
  }
}