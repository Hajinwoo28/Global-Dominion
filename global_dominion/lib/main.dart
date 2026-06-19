import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final apiService = ApiService(
    baseUrl: 'http://localhost:5000',
  ); // Assuming local backend

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameManager(apiService: apiService),
      child: const GlobalDominion(),
    ),
  );
}

class GameManager extends ChangeNotifier {
  final ApiService apiService;
  Map<String, dynamic>? _state;
  bool _isLoading = false;

  GameManager({required this.apiService});

  Map<String, dynamic>? get state => _state;
  bool get isLoading => _isLoading;

  Future<void> refreshState() async {
    _isLoading = true;
    notifyListeners();
    try {
      _state = await apiService.getState();
    } catch (e) {
      debugPrint('Error refreshing state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await apiService.login(identifier, password);
      if (success) {
        await refreshState();
      }
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    String confirmPassword,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await apiService.register(
        username,
        email,
        password,
        confirmPassword,
      );
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> attack(int territoryId, {String? spell}) async {
    final result = await apiService.attack(territoryId, spell: spell);
    await refreshState();
    return result;
  }
}

class GlobalDominion extends StatelessWidget {
  const GlobalDominion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Dominion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFFD700),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFF4FC3F7),
          surface: Color(0xFF1A1208),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
          bodyLarge: TextStyle(color: Colors.white70),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A1E12).withValues(alpha: 0.7),
          labelStyle: const TextStyle(color: Color(0xFFAA8820)),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF5C4008), width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/country_selection': (context) => const CountrySelectionScreen(),
        '/home': (context) => const HomeScreen(),
        '/game': (context) => const GameScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/rankings': (context) => const RankingsScreen(),
      },
    );
  }
}

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/world_map.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'RANKING SYSTEM',
                      style: TextStyle(
                        color: Color(0xFFF4E19C),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Image.asset('assets/images/game_logo.png', width: 150),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Table Area
                      Expanded(
                        flex: 3,
                        child: GameCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              TabBar(
                                controller: _tabController,
                                indicatorColor: const Color(0xFFFFD700),
                                labelColor: const Color(0xFFFFD700),
                                unselectedLabelColor: Colors.white54,
                                tabs: const [
                                  Tab(text: 'GLOBAL RANKINGS'),
                                  Tab(text: 'COUNTRY RANKINGS'),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    _RankSubTab(
                                      label: 'Total Power',
                                      isActive: true,
                                    ),
                                    _RankSubTab(label: 'Territory'),
                                    _RankSubTab(label: 'Wins'),
                                    _RankSubTab(label: 'Alliance Score'),
                                  ],
                                ),
                              ),
                              const _RankTableHeader(),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: 10,
                                  itemBuilder: (context, index) =>
                                      _RankTableRow(index: index),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                      // Sidebar
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _SidebarSection(
                              title: 'YOUR RANK',
                              child: _ProfileRankCard(
                                label: 'Rank: 42',
                                sublabel: '273.23M',
                              ),
                            ),
                            const SizedBox(height: 20),
                            _SidebarSection(
                              title: 'Strongest General',
                              child: _MiniProfileCard(
                                name: 'GeneralDominus',
                                stat: 'Power: 206,557',
                              ),
                            ),
                            const SizedBox(height: 20),
                            _SidebarSection(
                              title: 'Most Conquered Land',
                              child: _MiniProfileCard(
                                name: 'Kusnia',
                                stat: 'Land Area: 230,634',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TacticalButton(
                  label: 'CLOSE',
                  width: 200,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankSubTab extends StatelessWidget {
  final String label;
  final bool isActive;

  const _RankSubTab({required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF5C4008) : Colors.transparent,
        border: Border.all(color: const Color(0xFF5C4008)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFFFFD700) : Colors.white54,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RankTableHeader extends StatelessWidget {
  const _RankTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black45,
      child: const Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              'Rank',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              'Player',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              'Territory Controlled',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              'Wins',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTableRow extends StatelessWidget {
  final int index;
  const _RankTableRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final isTop3 = index < 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        color: index % 2 == 0
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: isTop3
                ? Icon(Icons.workspace_premium, color: colors[index], size: 20)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white70),
                  ),
          ),
          Expanded(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person, size: 14),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GeneralDominus',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Level ${42 - index}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 150,
            child: Text('17,366', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(
            width: 100,
            child: Text('189,296', style: TextStyle(color: Color(0xFFFFD700))),
          ),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SidebarSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFAA8820),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ProfileRankCard extends StatelessWidget {
  final String label;
  final String sublabel;

  const _ProfileRankCard({required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            child: Icon(Icons.person, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sublabel,
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniProfileCard extends StatelessWidget {
  final String name;
  final String stat;

  const _MiniProfileCard({required this.name, required this.stat});

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white10,
            child: Icon(Icons.person, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  stat,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPER UI COMPONENTS
// ─────────────────────────────────────────────

class GameCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GameCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1208).withValues(alpha: 0.85),
        border: Border.all(color: const Color(0xFFAA8820), width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }
}

class TacticalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double width;

  const TacticalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = const Color(0xFFFFD700),
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 50,
      child: Stack(
        children: [
          // Background with clip
          Positioned.fill(
            child: CustomPaint(
              painter: _TacticalButtonPainter(color: color, isPressed: false),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 16,
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

class _TacticalButtonPainter extends CustomPainter {
  final Color color;
  final bool isPressed;

  _TacticalButtonPainter({required this.color, required this.isPressed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const double notch = 12.0;

    path.moveTo(notch, 0);
    path.lineTo(size.width - notch, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - notch, size.height);
    path.lineTo(notch, size.height);
    path.lineTo(0, size.height / 2);
    path.close();

    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TacticalInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final Widget? suffixIcon;

  const TacticalInput({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: '[ $label ]',
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// LOGIN SCREEN — Overhauled to match Image 3
// ─────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _error;

  void _login() async {
    final gameManager = context.read<GameManager>();
    final success = await gameManager.login(
      _identifierController.text,
      _passwordController.text,
    );
    if (success) {
      if (mounted) {
        final state = gameManager.state;
        final hasCountry =
            state != null &&
            state['profile'] != null &&
            state['profile']['country'] != null;
        if (hasCountry) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/country_selection');
        }
      }
    } else {
      setState(() => _error = 'Invalid credentials');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<GameManager>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/world_map.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Frame
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3A2800), width: 10),
              ),
            ),
          ),
          // Page Title
          const Positioned(
            top: 40,
            left: 40,
            child: Text(
              'Login Page',
              style: TextStyle(
                color: Color(0xFFF4E19C),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Center Card
          Center(
            child: GameCard(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/game_logo.png', width: 120),
                  const SizedBox(height: 30),
                  TacticalInput(
                    controller: _identifierController,
                    label: 'Username / Email',
                  ),
                  TacticalInput(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF8B6914),
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        activeColor: const Color(0xFFFFD700),
                        checkColor: Colors.black,
                      ),
                      const Text(
                        'Remember Me',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Forgot Password',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  isLoading
                      ? const CircularProgressIndicator(
                          color: Color(0xFFFFD700),
                        )
                      : TacticalButton(label: 'LOGIN', onPressed: _login),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/register'),
                    child: const Text(
                      'NEW COMMANDER? ENLIST HERE',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// REGISTER SCREEN — Overhauled to match Image 2
// ─────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedCountry;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  String? _error;

  final List<String> _countries = [
    'USA',
    'Japan',
    'Russia',
    'Philippines',
    'Germany',
    'China',
    'France',
    'UK',
  ];

  void _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (!_acceptTerms) {
      setState(() => _error = 'Please accept Terms and Conditions');
      return;
    }

    final gameManager = context.read<GameManager>();
    final success = await gameManager.register(
      _usernameController.text,
      _emailController.text,
      _passwordController.text,
      _confirmPasswordController.text,
    );
    if (success) {
      if (_selectedCountry != null) {
        await gameManager.apiService.setCountry(_selectedCountry!);
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      setState(() => _error = 'Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<GameManager>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/world_map.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Frame
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3A2800), width: 10),
              ),
            ),
          ),
          // Page Title
          const Positioned(
            top: 40,
            left: 40,
            child: Text(
              'Register Page',
              style: TextStyle(
                color: Color(0xFFF4E19C),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Center Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: GameCard(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/game_logo.png', width: 100),
                    const SizedBox(height: 20),
                    TacticalInput(
                      controller: _usernameController,
                      label: 'Username',
                    ),
                    TacticalInput(controller: _emailController, label: 'Email'),
                    TacticalInput(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF8B6914),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    TacticalInput(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF8B6914),
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    // Country Dropdown
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1E12).withValues(alpha: 0.7),
                        border: Border.all(color: const Color(0xFF5C4008)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountry,
                          hint: const Text(
                            'Country Selection',
                            style: TextStyle(color: Color(0xFFAA8820)),
                          ),
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1208),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFFFFD700),
                          ),
                          items: _countries
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCountry = v),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (v) =>
                              setState(() => _acceptTerms = v ?? false),
                          activeColor: const Color(0xFFFFD700),
                          checkColor: Colors.black,
                        ),
                        const Text(
                          'Terms and Conditions',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFFFFD700),
                          )
                        : TacticalButton(
                            label: 'REGISTER',
                            onPressed: _register,
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'ALREADY SERVING? RETURN TO LOGIN',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COUNTRY SELECTION SCREEN
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// COUNTRY SELECTION SCREEN — Overhauled to match Image 4
// ─────────────────────────────────────────────
class CountrySelectionScreen extends StatelessWidget {
  const CountrySelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final countries = [
      {'name': 'USA', 'bonus': '+5 Marine Infantry', 'flag': '🇺🇸'},
      {'name': 'Japan', 'bonus': '+5 F-35 Fighter', 'flag': '🇯🇵'},
      {'name': 'Russia', 'bonus': '+5 Elite Infantry', 'flag': '🇷🇺'},
      {
        'name': 'Kusnia',
        'bonus': '+6 Elite Spetsnaz',
        'flag': '🇷🇸',
      }, // Mock flag for Kusnia
      {
        'name': 'USA ',
        'bonus': '+3 F-35 Infantry',
        'flag': '🇺🇸',
      }, // Variants as seen in image
      {'name': 'Japan ', 'bonus': '+1 F-35 Fighter', 'flag': '🇯🇵'},
      {'name': 'Kusnia ', 'bonus': '+1 Elite Infantry', 'flag': '🇷🇸'},
      {'name': 'Russia ', 'bonus': '+1 F-35 Fighter', 'flag': '🇷🇺'},
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF1A2A3A), Colors.black],
                  radius: 1.5,
                ),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Choose Your Country Screen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Permanent selection',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              Expanded(
                child: Row(
                  children: [
                    // Left Column
                    _buildCountryColumn(
                      context,
                      countries.sublist(0, 2),
                      countries.sublist(4, 6),
                    ),
                    // Center Globe
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 100,
                                spreadRadius: 20,
                              ),
                            ],
                            image: const DecorationImage(
                              image: AssetImage('assets/images/world_map.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Right Column
                    _buildCountryColumn(
                      context,
                      countries.sublist(2, 4),
                      countries.sublist(6, 8),
                    ),
                  ],
                ),
              ),
              TacticalButton(
                label: 'Choose Your Country Screen',
                width: 400,
                onPressed: () {},
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountryColumn(
    BuildContext context,
    List<Map<String, String>> top,
    List<Map<String, String>> bottom,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...top.map((c) => _CountryCard(country: c)),
          const SizedBox(height: 20),
          ...bottom.map((c) => _CountryCard(country: c)),
        ],
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  final Map<String, String> country;

  const _CountryCard({required this.country});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final gameManager = context.read<GameManager>();
        final success = await gameManager.apiService.setCountry(
          country['name']!.trim(),
        );
        if (success) {
          await gameManager.refreshState();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1620),
          border: Border.all(color: const Color(0xFF3A4A5A), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                // Portrait Placeholder
                Container(
                  height: 120,
                  width: double.infinity,
                  color: Colors.black26,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white24,
                    size: 60,
                  ),
                ),
                Positioned(
                  top: 5,
                  left: 5,
                  child: Text(
                    country['flag']!,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              color: Colors.black45,
              child: Column(
                children: [
                  Text(
                    country['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.military_tech,
                        color: Color(0xFFC9B96A),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        country['bonus']!,
                        style: const TextStyle(
                          color: Color(0xFFC9B96A),
                          fontSize: 10,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────
// SPLASH SCREEN — Overhauled to match Image 1
// ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          _navigateToLogin();
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onTap: _navigateToLogin,
          child: Stack(
            children: [
              // Background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/world_map.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              // Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      radius: 1.2,
                    ),
                  ),
                ),
              ),
              // Logo and Title
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/game_logo.png', width: 450),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              // Press Any Key
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _pulse,
                  child: const Text(
                    'PRESS ANY KEY TO CONQUER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                ),
              ),
              // Bottom Right Links
              Positioned(
                bottom: 40,
                right: 40,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _navigateToLogin,
                      child: const Text(
                        'LOGIN / CREATE ACCOUNT',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.settings, color: Colors.white30, size: 20),
                  ],
                ),
              ),
              // Decorative Corners
              const Positioned(
                top: 20,
                right: 20,
                child: Icon(Icons.close, color: Color(0xFF8B0000), size: 30),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFAA8820),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.castle,
                    color: Color(0xFFFFD700),
                    size: 32,
                  ),
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
    _MenuItem(
      label: 'SETTINGS',
      icon: Icons.settings_rounded,
      route: '/settings',
    ),
    _MenuItem(
      label: 'QUIT',
      icon: Icons.power_settings_new_rounded,
      route: null,
    ),
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
      ).animate(
        CurvedAnimation(
          parent: _menuController,
          curve: Interval(
            start.clamp(0, 1),
            end.clamp(0, 1),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
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
          pageBuilder: (_, _, _) => item.route == '/game'
              ? const GameScreen()
              : const SettingsScreen(),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(
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
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
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
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.75),
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
                  ? [
                      const Color(0xFFB8860B),
                      const Color(0xFFFFD700),
                      const Color(0xFFB8860B),
                    ]
                  : [
                      const Color(0xFF5C4008),
                      const Color(0xFF9A6F0A),
                      const Color(0xFF5C4008),
                    ],
            ),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFFFD700)
                  : const Color(0xFF8B6914),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.item.icon,
                color: _hovered ? Colors.white : Colors.white70,
                size: 20,
              ),
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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  String _status = 'Initializing command center...';

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addListener(() {
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
                        Image.asset(
                          'assets/images/game_logo.png',
                          width: 120,
                          height: 120,
                        ),
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
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
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
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (isReady)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: const Color(0xFF0B0B0B),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                PageRouteBuilder(
                                  pageBuilder: (_, _, _) =>
                                      const CommandCenterScreen(),
                                  transitionsBuilder: (_, anim, _, child) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      ),
                                ),
                              );
                            },
                            child: const Text(
                              'ENTER COMMAND CENTER',
                              style: TextStyle(
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
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
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFFFD700),
              size: 18,
            ),
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
          _ResourceChip(
            icon: Icons.grain_rounded,
            label: '1,200',
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(width: 16),
          _ResourceChip(
            icon: Icons.people_rounded,
            label: '850',
            color: const Color(0xFF4FC3F7),
          ),
          const SizedBox(width: 16),
          _ResourceChip(
            icon: Icons.shield_rounded,
            label: '300',
            color: const Color(0xFFEF9A9A),
          ),
        ],
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ResourceChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameManager>().state;
    String dynamicLabel = label;
    if (state != null && state['profile'] != null) {
      if (icon == Icons.grain_rounded)
        dynamicLabel = state['profile']['gold'].toString();
      if (icon == Icons.people_rounded)
        dynamicLabel = state['profile']['supplies'].toString();
      if (icon == Icons.shield_rounded)
        dynamicLabel = state['profile']['crystals'].toString();
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          dynamicLabel,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
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
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293C), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFFFFD700),
                      size: 18,
                    ),
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
                  _ResourceChip(
                    icon: Icons.grain_rounded,
                    label: '1,200',
                    color: const Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 18),
                  _ResourceChip(
                    icon: Icons.people_rounded,
                    label: '850',
                    color: const Color(0xFF4FC3F7),
                  ),
                  const SizedBox(width: 18),
                  _ResourceChip(
                    icon: Icons.shield_rounded,
                    label: '300',
                    color: const Color(0xFFEF9A9A),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
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
                            style: TextStyle(
                              color: Color(0xFFB0B7C5),
                              fontSize: 16,
                              height: 1.85,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              _DashboardCard(
                                title: 'Territories',
                                value:
                                    context
                                        .watch<GameManager>()
                                        .state?['profile']?['power_level']
                                        ?.toString() ??
                                    '16 / 24',
                                accent: Color(0xFFFFD700),
                                subtitle: 'Current Power Level',
                              ),
                              const SizedBox(width: 18),
                              _DashboardCard(
                                title: 'Nation',
                                value:
                                    context
                                        .watch<GameManager>()
                                        .state?['profile']?['country'] ??
                                    'USA',
                                accent: Color(0xFF4FC3F7),
                                subtitle: 'Strategic Alignment',
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
                              border: Border.all(
                                color: const Color(0xFF1E2A3A),
                              ),
                            ),
                            child: const Text(
                              'Enemy forces are concentrated on the eastern front. Deploy recon sweeps and prepare armored units for the next wave. Maintain supply lines and secure key ports before dusk.',
                              style: TextStyle(
                                color: Color(0xFFCAD3E0),
                                fontSize: 15,
                                height: 1.75,
                              ),
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
                                      pageBuilder: (_, _, _) =>
                                          const DeployArmyScreen(),
                                      transitionsBuilder: (_, anim, _, child) =>
                                          FadeTransition(
                                            opacity: anim,
                                            child: child,
                                          ),
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
                                      pageBuilder: (_, _, _) =>
                                          const WorldMapScreen(),
                                      transitionsBuilder: (_, anim, _, child) =>
                                          FadeTransition(
                                            opacity: anim,
                                            child: child,
                                          ),
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
                                  colors: [
                                    Color(0xFF101C29),
                                    Color(0xFF071018),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: const Color(0xFF1F2B38),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: 0.12,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage(
                                              'assets/images/world_map.jpg',
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _MapRegionBadge(
                                                label: 'Northern Front',
                                                status: 'Engaged',
                                              ),
                                              const SizedBox(width: 12),
                                              _MapRegionBadge(
                                                label: 'Coastal Port',
                                                status: 'Reinforce',
                                              ),
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
                              border: Border.all(
                                color: const Color(0xFF1E2A3A),
                              ),
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
                                Text(
                                  'Air surveillance detected increased movement near the western border.',
                                  style: TextStyle(
                                    color: Color(0xFFB0B7C5),
                                    height: 1.7,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Naval convoys are ready for port deployment within 12 hours.',
                                  style: TextStyle(
                                    color: Color(0xFFB0B7C5),
                                    height: 1.7,
                                  ),
                                ),
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

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.subtitle,
  });

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
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF92A1C2),
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFB0B7C5),
                fontSize: 13,
                height: 1.6,
              ),
            ),
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

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF061010),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB0B7C5), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class DeployArmyScreen extends StatelessWidget {
  const DeployArmyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameManager = context.watch<GameManager>();
    final territories = gameManager.state?['territories'] as List<dynamic>?;
    // For simplicity, we'll attack the first neutral territory found
    final targetTerritory = territories?.firstWhere(
      (t) => t['controlling_country'] == 'Neutral',
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF05070E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D13),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFFD700),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Deploy Army',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
          ),
        ),
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
            Text(
              targetTerritory != null
                  ? 'Targeting: ${targetTerritory['name']}. Prepare for assault.'
                  : 'All sectors secured or contested by allies. Monitor world map for intel.',
              style: const TextStyle(
                color: Color(0xFFB0B7C5),
                fontSize: 16,
                height: 1.7,
              ),
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
                          const Text(
                            'Armored Division',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Heavy tanks and mechanized infantry ready for frontal assault.',
                            style: TextStyle(
                              color: Color(0xFFB0B7C5),
                              height: 1.6,
                            ),
                          ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: targetTerritory == null
                                ? null
                                : () async {
                                    try {
                                      final result = await gameManager.attack(
                                        targetTerritory['id'],
                                      );
                                      if (context.mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: Text(
                                              result['battle_won']
                                                  ? 'VICTORY'
                                                  : 'DEFEAT',
                                            ),
                                            content: Text(result['message']),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                            child: const Text(
                              'DEPLOY NOW',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                          const Text(
                            'Recon Squadron',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Light airborne units prepared to survey enemy positions and relay battlefield intel.',
                            style: TextStyle(
                              color: Color(0xFFB0B7C5),
                              height: 1.6,
                            ),
                          ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () {},
                            child: const Text(
                              'LAUNCH RECON',
                              style: TextStyle(fontWeight: FontWeight.bold),
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFFD700),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'World Map',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
          ),
        ),
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
              style: TextStyle(
                color: Color(0xFFB0B7C5),
                fontSize: 16,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/world_map.jpg',
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.6),
                          ],
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
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Enemy forces are most active in the northern front. Dispatch strike teams or redirect reserves as needed.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 24,
                      child: _MapIndicator(
                        label: 'Northern Front',
                        status: 'Engaged',
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                    Positioned(
                      right: 24,
                      bottom: 24,
                      child: _MapIndicator(
                        label: 'Coastal Port',
                        status: 'Reinforce',
                        color: const Color(0xFF4FC3F7),
                      ),
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
                        Text(
                          'Allied Presence',
                          style: TextStyle(
                            color: Color(0xFFF4E19C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Three allied fleets are positioned along the southern coast.',
                          style: TextStyle(
                            color: Color(0xFFB0B7C5),
                            height: 1.6,
                          ),
                        ),
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
                        Text(
                          'Resource Flow',
                          style: TextStyle(
                            color: Color(0xFFF4E19C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Supply lines are stable for 18 hours. Continue advancing before reserves are depleted.',
                          style: TextStyle(
                            color: Color(0xFFB0B7C5),
                            height: 1.6,
                          ),
                        ),
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

  const _MapIndicator({
    required this.label,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121E29),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
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
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              status,
              style: const TextStyle(
                color: Color(0xFFF4E19C),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ENGAGED',
                style: TextStyle(
                  color: Color(0xFFD4B86F),
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF3A2800), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFFFD700),
                      ),
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
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
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
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
          ),
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
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
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
            activeThumbColor: const Color(0xFFFFD700),
            activeTrackColor: const Color(0xFF3A2800),
          ),
        ],
      ),
    );
  }
}
