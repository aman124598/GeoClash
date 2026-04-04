import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:h3_flutter/h3_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

late final H3 h3;

const String apiBase = 'https://geoclash.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  h3 = const H3Factory().load();
  runApp(const GeoClashApp());
}

// ─── APP ROOT ───────────────────────────────────────────────
class GeoClashApp extends StatelessWidget {
  const GeoClashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoClash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F131E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00F0FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1B1F2B),
          primary: const Color(0xFF00F0FF),
          secondary: const Color(0xFF2FF801),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          bodyMedium: GoogleFonts.inter(color: Colors.white70),
          bodySmall: GoogleFonts.inter(color: Colors.white38),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ─── AUTH GATE ──────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  String? _sessionToken;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    setState(() {
      _sessionToken = token;
      _isLoading = false;
    });
  }

  void _onLoginSuccess(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);
    setState(() => _sessionToken = token);
  }

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    setState(() => _sessionToken = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF))),
      );
    }

    if (_sessionToken == null) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    return MainConsole(
      sessionToken: _sessionToken!,
      onLogout: _onLogout,
    );
  }
}

// ─── LOGIN SCREEN (Stitch Design) ──────────────────────────
class LoginScreen extends StatefulWidget {
  final Function(String token) onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = null; });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() { _isLoading = false; _error = 'Please fill in all fields'; });
      return;
    }

    try {
      final endpoint = _isSignUp
          ? '$apiBase/api/auth/sign-up/email'
          : '$apiBase/api/auth/sign-in/email';

      final body = _isSignUp
          ? {'email': email, 'password': password, 'name': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : email.split('@')[0]}
          : {'email': email, 'password': password};

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['session']?['token'];
        if (token != null) {
          widget.onLoginSuccess(token);
        } else {
          // Try to extract from set-cookie header
          final cookies = response.headers['set-cookie'];
          if (cookies != null) {
            widget.onLoginSuccess(cookies);
          } else {
            setState(() { _error = 'Login succeeded but no token received'; _isLoading = false; });
          }
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['message'] ?? data['error'] ?? 'Authentication failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E1A), Color(0xFF0F131E), Color(0xFF0A0E1A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Branding
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'v0.1',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF00F0FF).withOpacity(0.6),
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GEOCLASH',
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: const Color(0xFF00F0FF),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FF801),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Capture Your City.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white54,
                    ),
                  ),
                  Text(
                    'Stay Fit.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2FF801),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Form Title
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isSignUp ? 'Create Account' : 'Welcome Back',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Name field (sign up only)
                  if (_isSignUp) ...[
                    _buildTextField(_nameController, 'Your name', Icons.person_outline),
                    const SizedBox(height: 16),
                  ],

                  // ── Email field
                  _buildTextField(_emailController, 'Email address', Icons.email_outlined),
                  const SizedBox(height: 16),

                  // ── Password field
                  _buildTextField(_passwordController, 'Password', Icons.lock_outline, obscure: true),
                  const SizedBox(height: 8),

                  // ── Error
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2FF801),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(
                              _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Toggle sign up / sign in
                  GestureDetector(
                    onTap: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                        children: [
                          TextSpan(text: _isSignUp ? 'Already have an account? ' : "Don't have an account? "),
                          TextSpan(
                            text: _isSignUp ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white24, size: 20),
        filled: true,
        fillColor: const Color(0xFF1B1F2B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ─── MAIN CONSOLE (tabs) ───────────────────────────────────
enum AppView { map, missions, rankings, profile }

class MainConsole extends StatefulWidget {
  final String sessionToken;
  final VoidCallback onLogout;
  const MainConsole({super.key, required this.sessionToken, required this.onLogout});

  @override
  State<MainConsole> createState() => _MainConsoleState();
}

class _MainConsoleState extends State<MainConsole> {
  AppView _currentView = AppView.map;
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(28.6139, 77.2090);
  bool _isLoadingLocation = true;
  late IO.Socket socket;
  String _userName = 'Agent';
  int _totalSteps = 0;
  double _totalDistance = 0; // meters
  LatLng? _lastPosition;

  final Map<String, dynamic> _gameTiles = {};
  final List<LatLng> _activeTrail = [];

  List<dynamic> _missions = [];
  List<dynamic> _leaderboard = [];
  Map<String, dynamic> _userStats = {};
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _initLocationService();
    _initSocket();
    _fetchAllRealtimeData();
  }

  Future<void> _fetchAllRealtimeData() async {
    setState(() => _isLoadingData = true);
    await Future.wait([
      _fetchUserStats(),
      _fetchMissions(),
      _fetchLeaderboard(),
    ]);
    if (mounted) setState(() => _isLoadingData = false);
  }

  Future<void> _fetchUserStats() async {
    try {
      final res = await http.get(
        Uri.parse('$apiBase/api/user/stats'),
        headers: {'Authorization': 'Bearer ${widget.sessionToken}'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _userStats = data['stats'] ?? {};
          _userName = _userStats['name'] ?? 'Agent';
          _totalDistance = (_userStats['totalDistance'] ?? 0).toDouble();
        });
      }
    } catch (e) { print('Error fetching stats: $e'); }
  }

  Future<void> _fetchMissions() async {
    try {
      final res = await http.get(
        Uri.parse('$apiBase/api/user/missions'),
        headers: {'Authorization': 'Bearer ${widget.sessionToken}'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _missions = data['missions'] ?? []);
      }
    } catch (e) { print('Error fetching missions: $e'); }
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/api/leaderboard'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _leaderboard = data['leaderboard'] ?? []);
      }
    } catch (e) { print('Error fetching leaderboard: $e'); }
  }

  void _initSocket() {
    socket = IO.io(apiBase, IO.OptionBuilder()
      .setTransports(['websocket'])
      .build()
    );

    socket.onConnect((_) => print('Connected to server'));

    socket.on('tile_update', (data) {
      if (mounted) {
        setState(() {
          _gameTiles[data['h3Index']] = data;
        });
      }
    });

    socket.on('territory_captured', (data) {
      if (mounted) {
        setState(() {
          for (var hex in data['hexes']) {
            _gameTiles[hex] = {
              'h3Index': hex,
              'ownerId': data['userId'],
              'strength': 100,
            };
          }
          _activeTrail.clear();
        });
      }
    });

    socket.onDisconnect((_) => print('Disconnected'));
  }

  Future<void> _initLocationService() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _lastPosition = _currentPosition;
      _isLoadingLocation = false;
    });

    // AUTO-TRACKING: always capture on movement
    // Note: Configured for background execution
    late LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "GeoClash is capturing your trail in the background!",
          notificationTitle: "Passive Capture Active",
          enableWakeLock: true,
        )
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      );
    }

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          // Track distance
          if (_lastPosition != null) {
            final d = const Distance().as(LengthUnit.Meter, _lastPosition!, newPos);
            _totalDistance += d;
            // Rough step estimate: 1 step ≈ 0.75m
            _totalSteps = (_totalDistance / 0.75).round();
          }
          _lastPosition = newPos;
          _currentPosition = newPos;
          _activeTrail.add(newPos);
        });
        // Auto-sync every position to backend
        _syncCapture(position);
      }
    });
  }

  Future<void> _syncCapture(Position pos) async {
    try {
      await http.post(
        Uri.parse('$apiBase/api/capture'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.sessionToken}',
          'Cookie': widget.sessionToken,
        },
        body: jsonEncode({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy,
          'speed': pos.speed,
        }),
      );
    } catch (e) {
      print('Sync Error: $e');
    }
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentView.index,
            children: [
              _buildMapView(),
              _buildMissionsView(),
              _buildRankingsView(),
              _buildProfileView(),
            ],
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  // ─── MAP VIEW ─────────────────────────────────────────────
  Widget _buildMapView() {
    return Stack(
      children: [
        _isLoadingLocation 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition,
                initialZoom: 17.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.geoclash',
                ),
                // Add a semi-transparent label layer for streets/cities on top of satellite
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                PolygonLayer(polygons: _buildTerritoryPolygons()),
                PolylineLayer(
                  polylines: [
                    if (_activeTrail.length >= 2)
                    Polyline(
                      points: _activeTrail,
                      strokeWidth: 4,
                      color: const Color(0xFF00F0FF).withOpacity(0.8),
                      borderColor: const Color(0xFF00F0FF),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition,
                      width: 60,
                      height: 60,
                      child: _buildUserMarker(),
                    ),
                  ],
                ),
              ],
            ),
        // Top HUD
        _buildTopHUD(),
        // Stats bar
        _buildStatsBar(),
      ],
    );
  }

  Widget _buildTopHUD() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GEOCLASH',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: const Color(0xFF00F0FF),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2FF801).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFF2FF801).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2FF801)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TRACKING',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: const Color(0xFF2FF801),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildHUDStat('AREA', '${_gameTiles.length * 100}m²'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1F2B).withOpacity(0.7),
              border: Border.all(color: Colors.white10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.directions_walk, '$_totalSteps', 'Steps'),
                Container(width: 1, height: 30, color: Colors.white10),
                _buildStatItem(Icons.straighten, '${(_totalDistance / 1000).toStringAsFixed(2)}', 'KM'),
                Container(width: 1, height: 30, color: Colors.white10),
                _buildStatItem(Icons.hexagon_outlined, '${_gameTiles.length}', 'Tiles'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF00F0FF), size: 18),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
      ],
    );
  }

  Widget _buildHUDStat(String label, String value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F2B).withOpacity(0.6),
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label, 
                style: GoogleFonts.inter(
                  fontSize: 8, 
                  color: const Color(0xFF00F0FF).withOpacity(0.5), 
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                )
              ),
              const SizedBox(height: 4),
              Text(
                value, 
                style: GoogleFonts.inter(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 5,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.navigation, color: Color(0xFF00F0FF), size: 30),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MISSIONS VIEW ────────────────────────────────────────
  Widget _buildMissionsView() {
    final missions = _missions ?? [];
    final stats = _userStats ?? {};
    final double todayDist = ((stats['todayDistance'] ?? 0) as num).toDouble();
    final int todaySteps = (todayDist * 1.3).toInt();

    return _buildPageView('Missions', [
      _buildCard('Daily Activity', '$todaySteps Steps • ${(todayDist/1000).toStringAsFixed(2)} km today', Icons.directions_run),
      const SizedBox(height: 10),
      Text('ACTIVE MISSIONS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 2)),
      const SizedBox(height: 16),
      if (missions.isEmpty)
        _buildCard('No Missions', 'Start capturing to unlock active missions.', Icons.assignment_outlined)
      else
        ...missions.map((m) {
          final double progress = ((m['progress'] ?? 0) as num).toDouble();
          final double goal = ((m['goal'] ?? 0) as num).toDouble();
          final String unit = (m['id'] ?? '').startsWith('dist') ? 'km' : 'tiles';
          
          return _buildCard(
            m['title'] ?? 'Mission', 
            '${progress.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} $unit\n${m['desc'] ?? ''}', 
            m['icon'] == 'directions_walk' ? Icons.directions_walk : 
            m['icon'] == 'grid_view' ? Icons.grid_view : Icons.local_fire_department
          );
        }),
      _buildCard('Area Log', '${_gameTiles.length} tiles captured in this session.', Icons.history_edu),
    ]);
  }

  // ─── RANKINGS VIEW ────────────────────────────────────────
  Widget _buildRankingsView() {
    final stats = _userStats ?? {};
    final leaderboard = _leaderboard ?? [];
    
    return _buildPageView('Rankings', [
      if (stats.isNotEmpty && stats['rank'] != null)
        _buildCard('Your Global Rank', '#${stats['rank']} of ${stats['totalPlayers'] ?? '?'} players.', Icons.emoji_events_outlined),
      
      const SizedBox(height: 10),
      Text('TOP PLAYERS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 2)),
      const SizedBox(height: 16),
      
      if (leaderboard.isEmpty)
        _buildCard('Loading...', 'Fetching leaderboard data...', Icons.sync)
      else
        ...leaderboard.asMap().entries.map((entry) {
          final int idx = entry.key;
          final dynamic u = entry.value;
          return _buildLeaderboardTile(idx + 1, u['name'] ?? 'Anonymous', u['totalTiles'] ?? 0, u['color']);
        }),
    ]);
  }

  Widget _buildLeaderboardTile(int rank, String name, int tiles, String? colorHex) {
    Color userColor = const Color(0xFF00F0FF);
    if (colorHex != null) {
      try { userColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF'))); } catch (e) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank', style: GoogleFonts.jetBrainsMono(color: rank <= 3 ? const Color(0xFF00F0FF) : Colors.white24, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Container(width: 4, height: 24, decoration: BoxDecoration(color: userColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600))),
          Text('$tiles TILES', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF2FF801), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── PROFILE VIEW ─────────────────────────────────────────
  Widget _buildProfileView() {
    return _buildPageView('Profile', [
      _buildCard('Account', _userName, Icons.person_outline),
      _buildCard('Total Distance', '${(_totalDistance / 1000).toStringAsFixed(2)} km walked', Icons.straighten),
      _buildCard('Territory Control', '${_userStats['totalTiles'] ?? 0} tiles captured', Icons.hexagon_outlined),
      _buildCard('Season Streak', '${_userStats['currentStreak'] ?? 0} days active', Icons.local_fire_department_outlined),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text('Sign Out', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPageView(String title, List<Widget> children) {
    return Container(
      color: const Color(0xFF0F131E),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 2, width: 40, decoration: BoxDecoration(color: const Color(0xFF00F0FF), borderRadius: BorderRadius.circular(1))),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String label, String content, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F2B),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00F0FF), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(content, style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1F2B).withOpacity(0.8),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(AppView.map, Icons.map_outlined, 'Map'),
                  _buildNavItem(AppView.missions, Icons.flag_outlined, 'Missions'),
                  _buildNavItem(AppView.rankings, Icons.leaderboard_outlined, 'Rankings'),
                  _buildNavItem(AppView.profile, Icons.person_outline, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(AppView view, IconData icon, String label) {
    final bool isActive = _currentView == view;
    final Color color = isActive ? const Color(0xFF00F0FF) : Colors.white30;

    return GestureDetector(
      onTap: () => setState(() => _currentView = view),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 16,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF00F0FF),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── TERRITORY POLYGONS ───────────────────────────────────
  List<Polygon> _buildTerritoryPolygons() {
    List<Polygon> polygons = [];
    _gameTiles.forEach((h3Index, tileData) {
      try {
        final geoCoords = h3.cellToBoundary(BigInt.parse(h3Index, radix: 16));
        final points = geoCoords.map((coord) => LatLng(coord.lat, coord.lon)).toList();
        
        if (points.length >= 3) {
          polygons.add(
            Polygon(
              points: points,
              color: const Color(0xFF00F0FF).withOpacity(0.15),
              borderColor: const Color(0xFF00F0FF).withOpacity(0.4),
              borderStrokeWidth: 1,
            ),
          );
        }
      } catch (e) {
        print('Error parsing H3 boundary: $e');
      }
    });

    // Hex around user
    try {
      final userHex = h3.geoToCell(
        GeoCoord(lat: _currentPosition.latitude, lon: _currentPosition.longitude), 
        10
      );
      final geoCoords = h3.cellToBoundary(userHex);
      final points = geoCoords.map((coord) => LatLng(coord.lat, coord.lon)).toList();
      
      if (points.length >= 3) {
        polygons.add(
          Polygon(
            points: points,
            color: const Color(0xFF00F0FF).withOpacity(0.1),
            borderColor: const Color(0xFF00F0FF).withOpacity(0.3),
            borderStrokeWidth: 1,
          )
        );
      }
    } catch (e) {}

    return polygons;
  }
}
