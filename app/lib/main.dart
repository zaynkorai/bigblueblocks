import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:bigblueblocks/services/notification_service.dart';
import 'package:bigblueblocks/services/ad_helper.dart';
import 'painters.dart';
import 'settings_dialog.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize notifications
  await NotificationService().init();

  // Initialize Google Mobile Ads SDK
  MobileAds.instance.initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const BigBlueBlocksApp());
}

// ═══════════════════════════════════════════════════════
//  THEME CONSTANTS
// ═══════════════════════════════════════════════════════

const Color bgDarkBlue = Color(0xFF010816);
const Color cardDarkBlue = Color(0xFF0B1B3C);
const Color gameYellow = Color(0xFFFFC900);
const Color fontWhite = Colors.white;

const List<Color> shapeColors = [
  Colors.transparent, // 0 - Empty
  Colors.white, // 1 - Hurdle
  Color(0xFFFFC900), // 2 - Yellow
  Color(0xFF2E7DFF), // 3 - Blue
  Color(0xFFFF003C), // 4 - Red
];

enum HapticType { light, medium, heavy, selection }

// ═══════════════════════════════════════════════════════
//  RESPONSIVE LAYOUT HELPER
// ═══════════════════════════════════════════════════════

class GameLayout {
  final double screenWidth;
  final double screenHeight;
  final double safeTop;
  final double safeBottom;

  GameLayout({
    required this.screenWidth,
    required this.screenHeight,
    this.safeTop = 0,
    this.safeBottom = 0,
  });

  double get usableHeight => screenHeight - safeTop - safeBottom;
  bool get isTablet => screenWidth >= 600;

  double get boardMaxSize {
    double maxByWidth = screenWidth - 16;
    double maxByHeight = usableHeight * 0.48;
    return min(maxByWidth, maxByHeight).clamp(200.0, 520.0);
  }

  double get statCardWidth => (screenWidth / 4.5).clamp(65.0, 110.0);
  double get statCardPadV => (usableHeight * 0.008).clamp(4.0, 12.0);
  double get pieceSlotSize => (screenWidth * 0.2).clamp(52.0, 88.0);
  double get nextSlotSize => (pieceSlotSize * 0.52).clamp(28.0, 48.0);

  double get fontSm => (screenWidth * 0.025).clamp(8.0, 12.0);
  double get fontMd => (screenWidth * 0.038).clamp(13.0, 20.0);
  double get fontLg => (screenWidth * 0.055).clamp(18.0, 28.0);
  double get fontXl => (screenWidth * 0.07).clamp(22.0, 34.0);

  double get spacingXs => (usableHeight * 0.003).clamp(2.0, 4.0);
  double get spacingSm => (usableHeight * 0.005).clamp(3.0, 6.0);
  double get spacingMd => (usableHeight * 0.008).clamp(4.0, 10.0);

  double get buttonPadV => (usableHeight * 0.018).clamp(10.0, 20.0);
  double get buttonWidth => (screenWidth * 0.62).clamp(180.0, 280.0);
  double get buttonFontSize => (screenWidth * 0.04).clamp(13.0, 18.0);
}

// ═══════════════════════════════════════════════════════
//  DATA CLASSES
// ═══════════════════════════════════════════════════════

class GameCoordinate {
  final int x;
  final int y;
  const GameCoordinate(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameCoordinate &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class GamePiece {
  final List<GameCoordinate> shape;
  final int colorIndex;
  GamePiece(this.shape, this.colorIndex);
}

class ScorePopup {
  final String text;
  final Color color;
  final bool isLarge;
  final Key key;

  ScorePopup({
    required this.text,
    required this.color,
    this.isLarge = false,
  }) : key = UniqueKey();
}

// ═══════════════════════════════════════════════════════
//  APP
// ═══════════════════════════════════════════════════════

class BigBlueBlocksApp extends StatelessWidget {
  const BigBlueBlocksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BigBlueBlocks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgDarkBlue,
        textTheme: GoogleFonts.orbitronTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: fontWhite,
          displayColor: fontWhite,
        ),
      ),
      home: const GameScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  GAME SCREEN
// ═══════════════════════════════════════════════════════

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _demoRunId = 0;
  static const int gridSize = 8;

  // ── Core State ──
  List<List<int>> grid = [];
  int capturedCount = 0;
  int totalCapturable = 0;
  int linesCleared = 0;
  int gameScore = 0;
  GameCoordinate playerCoord = const GameCoordinate(0, 0);
  bool _requiresLift = false;
  String gameState = 'PLAY';
  int highScore = 0;
  bool isNewHighScore = false;

  // ── Pieces ──
  List<GamePiece?> availablePieces = [null, null, null];
  List<GamePiece?> nextPieces = [null, null, null];
  int? selectedPieceIndex;
  Set<GameCoordinate> activeTrace = {};

  Set<GameCoordinate> _clearingCells = {};
  late AnimationController _clearController;
  Set<GameCoordinate> _thudCells = {};
  late AnimationController _thudController;
  late AnimationController _dealController;

  // ── True Interactive Tutorial & Hint System ──
  int _tutorialStep =
      0; // 0=off, 1=select piece, 2=trace on grid (combines old 2 & 3)
  List<GameCoordinate>? _hintTrace;
  Timer? _idleTimer;

  bool _isAutoPlayingDemo = false;
  Offset _handPos = const Offset(-100, -100);
  bool _handVisible = false;
  bool _handPressed = false;
  Duration _handDuration = const Duration(milliseconds: 300);
  Curve _handCurve = Curves.easeInOut;

  final List<GlobalKey> _pieceKeys = [GlobalKey(), GlobalKey(), GlobalKey()];
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  // ── Gamification ──
  int comboCount = 0;
  int streakCount = 0;

  int get level => min((linesCleared ~/ 5) + 1, 10);
  int get hurdleCount => min(level, 4);
  int get score => gameScore;

  // ── Banner Ad ──
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // ── Settings ──
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _notificationsEnabled = true;

  Future<void> _updateDailyReminder(bool enabled) async {
    if (enabled) {
      bool granted = await NotificationService().requestPermissions();
      if (granted) {
        await NotificationService().scheduleDailyReminder(hour: 10, minute: 0);
      } else {
        if (mounted) {
          setState(() {
            _notificationsEnabled = false;
          });
          _saveSettings();
        }
      }
    } else {
      await NotificationService().cancelDailyReminder();
    }
  }

  /// Gated haptic and sound feedback.
  void _haptic(HapticType type) {
    try {
      if (_soundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }
      if (!_vibrationEnabled) return;
      switch (type) {
        case HapticType.light:
          HapticFeedback.lightImpact();
        case HapticType.medium:
          HapticFeedback.mediumImpact();
        case HapticType.heavy:
          HapticFeedback.heavyImpact();
        case HapticType.selection:
          HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  void _showSettings() {
    showDialog(
      context: context,
      barrierColor: bgDarkBlue.withValues(alpha: 0.8),
      builder: (ctx) => SettingsDialog(
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
        onSoundChanged: (v) {
          setState(() => _soundEnabled = v);
          _saveSettings();
          if (v) SystemSound.play(SystemSoundType.click);
        },
        onVibrationChanged: (v) {
          setState(() => _vibrationEnabled = v);
          _saveSettings();
          if (v) _haptic(HapticType.light);
        },
        onMoreSettings: () {
          Navigator.pop(ctx);
          _showMoreSettings();
        },
      ),
    );
  }

  void _showMoreSettings() {
    showDialog(
      context: context,
      barrierColor: bgDarkBlue.withValues(alpha: 0.8),
      builder: (ctx) => MoreSettingsDialog(
        notificationsEnabled: _notificationsEnabled,
        onNotificationsChanged: (v) async {
          setState(() => _notificationsEnabled = v);
          _saveSettings();
          await _updateDailyReminder(v);
        },
        onHapticLight: () => _haptic(HapticType.light),
      ),
    );
  }

  Offset _globalToStack(Offset global) {
    RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return global;
    return stackBox.globalToLocal(global);
  }

  Offset _getPieceCenter(int index) {
    RenderBox? box =
        _pieceKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return _globalToStack(box.localToGlobal(box.size.center(Offset.zero)));
  }

  Offset _getBoardCellCenter(int x, int y) {
    RenderBox? box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    Offset topLeft = _globalToStack(box.localToGlobal(Offset.zero));
    double cellSize = box.size.width / gridSize;
    return Offset(topLeft.dx + x * cellSize + cellSize / 2,
        topLeft.dy + y * cellSize + cellSize / 2);
  }

  void _showTutorial() {
    setState(() {
      _tutorialStep = 1;
      _requiresLift = false;
      activeTrace.clear();
      _hintTrace = null;
      selectedPieceIndex = null;
    });
    _startDemoLoop();
  }

  void _startDemoLoop() async {
    if (_isAutoPlayingDemo) return;
    _isAutoPlayingDemo = true;
    _demoRunId = DateTime.now().millisecondsSinceEpoch;
    final int currentRun = _demoRunId;

    bool isActive() =>
        mounted &&
        _isAutoPlayingDemo &&
        _tutorialStep == 1 &&
        _demoRunId == currentRun;

    try {
      while (isActive()) {
        if (_pieceKeys[0].currentContext == null ||
            _boardKey.currentContext == null) {
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        }

        int targetPiece = availablePieces.indexWhere((p) => p != null);
        if (targetPiece == -1) break;

        RenderBox? targetBox = _pieceKeys[targetPiece]
            .currentContext
            ?.findRenderObject() as RenderBox?;
        double hoverOffset =
            targetBox != null ? targetBox.size.height * 0.4 : 40.0;

        // 1. Hand Appears over shape
        setState(() {
          selectedPieceIndex = null;
          _handDuration = const Duration(milliseconds: 0);
          _handPos = _getPieceCenter(targetPiece) - Offset(0, hoverOffset);
          _handVisible = true;
          _handPressed = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (!isActive()) break;

        // 2. Hand moves down to press it
        setState(() {
          _handDuration = const Duration(milliseconds: 300);
          _handCurve = Curves.easeOut;
          _handPos = _getPieceCenter(targetPiece);
          _handPressed = true;
        });
        await Future.delayed(const Duration(milliseconds: 300));
        if (!isActive()) break;

        if (mounted) {
          setState(() {
            selectedPieceIndex = targetPiece;
            _hintTrace = _getHintTraceForPiece(targetPiece);
          });
          _haptic(HapticType.selection);
        }

        await Future.delayed(const Duration(milliseconds: 400));
        if (!isActive()) break;

        // 3. Move hand to grid start
        final trace = _hintTrace;
        if (trace != null && trace.isNotEmpty) {
          setState(() {
            _handPressed = false;
            _handDuration = const Duration(milliseconds: 600);
            _handCurve = Curves.easeInOut;
            _handPos = _getBoardCellCenter(trace.first.x, trace.first.y);
          });
          await Future.delayed(const Duration(milliseconds: 600));
          if (!isActive()) break;

          setState(() {
            _handPressed = true;
            playerCoord = trace.first;
            activeTrace.clear();
            activeTrace.add(trace.first);
          });
          await Future.delayed(const Duration(milliseconds: 100));

          // Sweep across trace
          for (int i = 1; i < trace.length; i++) {
            setState(() {
              _handDuration = const Duration(milliseconds: 200);
              _handCurve = Curves.linear;
              _handPos = _getBoardCellCenter(trace[i].x, trace[i].y);
            });

            await Future.delayed(const Duration(milliseconds: 180));
            if (!isActive()) break;

            setState(() {
              playerCoord = trace[i];
              activeTrace.add(trace[i]);
            });
            await Future.delayed(const Duration(milliseconds: 20));
          }
          await Future.delayed(const Duration(milliseconds: 600));
        }

        // 4. Fade & reset
        if (!isActive()) break;
        setState(() {
          _handVisible = false;
          _handPressed = false;
          selectedPieceIndex = null;
          _hintTrace = null;
          activeTrace.clear();
        });

        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } finally {
      if (mounted && _demoRunId == currentRun) {
        setState(() {
          _isAutoPlayingDemo = false;
          _handVisible = false;
          _handPressed = false;
        });
      }
    }
  }

  // ── Visual Feedback ──
  final List<ScorePopup> _scorePopups = [];
  String? _comboText;
  Timer? _comboTimer;

  // ── Animations ──
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _fingerController;

  // ═══════════════════════════════════════════════════
  //  LIFECYCLE
  // ═══════════════════════════════════════════════════

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

      // Ensure we don't call setState if unmounted
      if (!mounted) return;

      setState(() {
        highScore = prefs.getInt('highScore') ?? 0;
        _soundEnabled = prefs.getBool('soundEnabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      });

      // Ensure reminder state matches preference
      await _updateDailyReminder(_notificationsEnabled);

      if (isFirstLaunch) {
        await prefs.setBool('isFirstLaunch', false);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showTutorial();
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      // Always remove splash screen after attempt
      FlutterNativeSplash.remove();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setBool('vibrationEnabled', _vibrationEnabled);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
  }

  Future<void> _saveHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', score);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        setState(() {});
      });
    _thudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(() {
        setState(() {});
      });
    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fingerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    initGame();
    _loadBannerAd();

    // Schedule settings load after first frame to ensure bindings are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    _clearController.dispose();
    _thudController.dispose();
    _dealController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _fingerController.dispose();
    _comboTimer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  /// Loads a 320×50 standard banner ad.
  void _loadBannerAd() {
    if (!AdHelper.isSupportedPlatform) {
      return;
    }
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().dismissAllNotifications();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_tutorialStep == 1 && _isAutoPlayingDemo) {
        setState(() {
          _tutorialStep = 0;
          _isAutoPlayingDemo = false;
          _handVisible = false;
          activeTrace.clear();
        });
      }
    }
  }

  @override
  void didChangeMetrics() {
    if (_tutorialStep == 1 && _isAutoPlayingDemo) {
      if (mounted) {
        setState(() {
          _isAutoPlayingDemo = false;
          _tutorialStep = 0;
          _handVisible = false;
          activeTrace.clear();
        });
      }

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showTutorial();
      });
    }
  }

  // ═══════════════════════════════════════════════════
  //  PIECE GENERATION
  // ═══════════════════════════════════════════════════

  // Pieces grouped by difficulty tier
  // Tier 0 (Levels 1-4): dot, 2-line, corner, 3-line, O-block, L-block
  // Tier 1 (Levels 5-6): 4-line, T-block
  // Tier 2 (Levels 7+): 5-line, Plus, U
  static final List<List<List<GameCoordinate>>> _pieceTiers = [
    // ── Tier 0 (Levels 1-5): Very Simple ──
    [
      [const GameCoordinate(0, 0), const GameCoordinate(1, 0)], // 2-line
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(2, 0)
      ], // 3-line
    ],
    // ── Tier 1 (Levels 6-10): Intermediate ──
    [
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(1, 1)
      ], // 2x2 Square
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(2, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(0, 2)
      ], // Corner (Big L)
    ],
    // ── Tier 2 (Levels 11+): Advanced (but still simple) ──
    [
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(2, 0),
        const GameCoordinate(3, 0)
      ], // 4-line
      [
        const GameCoordinate(1, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(1, 1),
        const GameCoordinate(2, 1)
      ], // T-block
      [const GameCoordinate(2, 2)], // 3x3 Square
    ],
  ];

  /// Returns the available piece pool for the current level.
  /// Higher levels unlock harder tiers while keeping all earlier shapes.
  List<List<GameCoordinate>> _piecePoolForLevel(int lvl) {
    List<List<GameCoordinate>> pool = [];
    pool.addAll(_pieceTiers[0]); // Always available
    if (lvl >= 6) pool.addAll(_pieceTiers[1]);
    if (lvl >= 11) pool.addAll(_pieceTiers[2]);
    return pool;
  }

  List<GamePiece?> _createPieceSet() {
    const int minColor = 2;
    const int maxColor = 4;
    Random rnd = Random();
    List<GamePiece?> pieces = [];
    final pool = _piecePoolForLevel(level);

    for (int i = 0; i < 3; i++) {
      var piece = List<GameCoordinate>.from(pool[rnd.nextInt(pool.length)]);
      int colorIdx = minColor + rnd.nextInt(maxColor - minColor + 1);

      int rots = rnd.nextInt(4);
      for (int r = 0; r < rots; r++) {
        piece = piece.map((c) => GameCoordinate(-c.y, c.x)).toList();
      }

      int minX = piece.map((e) => e.x).reduce(min);
      int minY = piece.map((e) => e.y).reduce(min);
      List<GameCoordinate> normalized =
          piece.map((c) => GameCoordinate(c.x - minX, c.y - minY)).toList();

      pieces.add(GamePiece(normalized, colorIdx));
    }
    return pieces;
  }

  List<GameCoordinate>? _getHintTraceForPiece(int index) {
    var piece = availablePieces[index];
    if (piece == null) return null;
    List<GameCoordinate> pShape = piece.shape;

    for (int ox = 0; ox < gridSize; ox++) {
      for (int oy = 0; oy < gridSize; oy++) {
        bool fits = true;
        for (var c in pShape) {
          int px = c.x + ox;
          int py = c.y + oy;
          if (px < 0 ||
              px >= gridSize ||
              py < 0 ||
              py >= gridSize ||
              grid[px][py] != 0) {
            fits = false;
            break;
          }
        }
        if (fits) {
          return pShape.map((c) => GameCoordinate(ox + c.x, oy + c.y)).toList();
        }
      }
    }
    return null;
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_hintTrace != null && _tutorialStep == 0) {
      if (mounted) setState(() => _hintTrace = null);
    }
    if (gameState != 'PLAY') return;
    _idleTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (_tutorialStep > 0) return; // Tutorial handles its own trace

      if (selectedPieceIndex == null) {
        for (int i = 0; i < 3; i++) {
          if (availablePieces[i] != null) {
            setState(() {
              selectedPieceIndex = i;
              _hintTrace = _getHintTraceForPiece(i);
            });
            break;
          }
        }
      } else {
        setState(() {
          _hintTrace = _getHintTraceForPiece(selectedPieceIndex!);
        });
      }
    });
  }

  void selectPiece(int index) {
    if (availablePieces[index] == null) return;
    setState(() {
      selectedPieceIndex = index;
      activeTrace.clear();
      if (_tutorialStep == 1) {
        _tutorialStep = 2;
        _isAutoPlayingDemo = false;
        _handVisible = false;
      }
      if (_tutorialStep == 2) {
        _hintTrace = _getHintTraceForPiece(index);
      } else {
        _resetIdleTimer();
      }
    });
  }

  // ═══════════════════════════════════════════════════
  //  PLACEMENT LOGIC
  // ═══════════════════════════════════════════════════

  bool canPlacePiece(GamePiece piece) {
    for (int ox = 0; ox < gridSize; ox++) {
      for (int oy = 0; oy < gridSize; oy++) {
        for (var anchor in piece.shape) {
          int dx = ox - anchor.x;
          int dy = oy - anchor.y;
          bool fits = true;
          for (var c in piece.shape) {
            int px = c.x + dx;
            int py = c.y + dy;
            if (px < 0 ||
                px >= gridSize ||
                py < 0 ||
                py >= gridSize ||
                grid[px][py] != 0) {
              fits = false;
              break;
            }
          }
          if (fits) return true;
        }
      }
    }
    return false;
  }

  bool canAnyPieceFit() {
    for (var piece in availablePieces) {
      if (piece != null && canPlacePiece(piece)) return true;
    }
    return false;
  }

  bool isValidTraceShape(Set<GameCoordinate> sim, List<GameCoordinate> target) {
    if (sim.length > target.length) return false;
    var simList = sim.toList();
    GameCoordinate pivot = simList.first;
    for (var tPivot in target) {
      int dx = tPivot.x - pivot.x;
      int dy = tPivot.y - pivot.y;
      bool match = true;
      for (var s in sim) {
        bool found = false;
        for (var t in target) {
          if (s.x + dx == t.x && s.y + dy == t.y) {
            found = true;
            break;
          }
        }
        if (!found) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════
  //  HURDLES
  // ═══════════════════════════════════════════════════

  void _placeHurdles() {
    // Remove existing hurdles
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (grid[x][y] == 1) grid[x][y] = 0;
      }
    }

    Random rnd = Random();
    int placed = 0;
    int attempts = 0;
    while (placed < hurdleCount && attempts < 200) {
      int rx = rnd.nextInt(gridSize);
      int ry = rnd.nextInt(gridSize);
      if (grid[rx][ry] == 0 && !(rx == playerCoord.x && ry == playerCoord.y)) {
        grid[rx][ry] = 1;
        placed++;
      }
      attempts++;
    }
    _haptic(HapticType.heavy);
  }

  // ═══════════════════════════════════════════════════
  //  GAME INIT
  // ═══════════════════════════════════════════════════

  void initGame() {
    grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    playerCoord = const GameCoordinate(0, 0);
    _requiresLift = false;
    linesCleared = 0;
    gameScore = 0;
    comboCount = 0;
    streakCount = 0;
    _scorePopups.clear();
    _comboText = null;

    _placeHurdles();

    capturedCount = 0;
    totalCapturable = gridSize * gridSize - hurdleCount;

    availablePieces = _createPieceSet();
    nextPieces = _createPieceSet();
    selectedPieceIndex = 0;
    activeTrace.clear();
    _resetIdleTimer();

    setState(() {
      gameState = 'PLAY';
      isNewHighScore = false;
    });
  }

  // ═══════════════════════════════════════════════════
  //  LINE CLEAR (fixes double-counting at intersections)
  //  Mutates state directly — call from within setState.
  // ═══════════════════════════════════════════════════

  int _performLineClear() {
    List<int> rowsToClear = [];
    List<int> colsToClear = [];

    for (int y = 0; y < gridSize; y++) {
      bool full = true;
      bool hasHurdle = false;
      for (int x = 0; x < gridSize; x++) {
        if (grid[x][y] == 0) {
          full = false;
          break;
        }
        if (grid[x][y] == 1) hasHurdle = true;
      }
      if (full && !hasHurdle) rowsToClear.add(y);
    }

    for (int x = 0; x < gridSize; x++) {
      bool full = true;
      bool hasHurdle = false;
      for (int y = 0; y < gridSize; y++) {
        if (grid[x][y] == 0) {
          full = false;
          break;
        }
        if (grid[x][y] == 1) hasHurdle = true;
      }
      if (full && !hasHurdle) colsToClear.add(x);
    }

    if (rowsToClear.isEmpty && colsToClear.isEmpty) return 0;

    // Collect unique cells to avoid double-counting at intersections
    Set<GameCoordinate> cellsToClear = {};
    for (int y in rowsToClear) {
      for (int x = 0; x < gridSize; x++) {
        cellsToClear.add(GameCoordinate(x, y));
      }
    }
    for (int x in colsToClear) {
      for (int y = 0; y < gridSize; y++) {
        cellsToClear.add(GameCoordinate(x, y));
      }
    }

    int totalLines = rowsToClear.length + colsToClear.length;

    int cellPoints = 0;
    for (var c in cellsToClear) {
      if (grid[c.x][c.y] >= 2) {
        capturedCount--;
        cellPoints += 10;
      }
    }

    if (totalLines > 0) {
      final cellsToClearCopy = Set<GameCoordinate>.from(cellsToClear);
      setState(() {
        _clearingCells = cellsToClearCopy;
      });
      _clearController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            for (var c in cellsToClearCopy) {
              grid[c.x][c.y] = 0;
            }
            _clearingCells = _clearingCells.difference(cellsToClearCopy);
            _placeHurdles();
            totalCapturable = gridSize * gridSize - hurdleCount;
          });
        }
      });
    }

    int lineBonus = 150 * totalLines;
    int comboBonus = comboCount > 1 ? 100 * (comboCount - 1) : 0;
    int totalBonus = cellPoints + lineBonus + comboBonus;

    gameScore += totalBonus;
    linesCleared += totalLines;

    if (totalLines == 0) {
      _placeHurdles();
      totalCapturable = gridSize * gridSize - hurdleCount;
    }

    // Queue score popup (Timer removal can call setState safely later)
    _queueScorePopup("+$totalBonus", gameYellow, isLarge: totalLines > 0);

    _haptic(HapticType.heavy);
    return totalLines;
  }

  /// Check if every non-hurdle cell is empty → perfect clear.
  /// Mutates state directly — call from within setState.
  void _checkPerfectClear() {
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (grid[x][y] >= 2 && !_clearingCells.contains(GameCoordinate(x, y))) {
          return;
        }
      }
    }
    gameScore += 1000;
    _queueScorePopup("✦ PERFECT CLEAR +1000 ✦", const Color(0xFF00F0FF),
        isLarge: true);
    _haptic(HapticType.heavy);
  }

  // ═══════════════════════════════════════════════════
  //  VISUAL FEEDBACK (popups & combo text)
  // ═══════════════════════════════════════════════════

  void _queueScorePopup(String text, Color color, {bool isLarge = false}) {
    var popup = ScorePopup(text: text, color: color, isLarge: isLarge);
    _scorePopups.add(popup);
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _scorePopups.remove(popup);
        });
      }
    });
  }

  void _queueComboText(String text) {
    _comboText = text;
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _comboText = null;
        });
      }
    });
  }

  String _comboLabel(int combo) {
    if (combo >= 5) return "×$combo UNSTOPPABLE!";
    if (combo >= 4) return "×$combo INSANE!";
    if (combo >= 3) return "×$combo CHAIN!";
    return "×$combo COMBO!";
  }

  // ═══════════════════════════════════════════════════
  //  MOVE EXECUTION
  // ═══════════════════════════════════════════════════

  /// Checks if the active trace matches the selected piece length,
  /// and if so, places the piece on the grid. Call from within setState.
  void _tryCompletePlacement() {
    if (selectedPieceIndex == null) return;
    if (availablePieces[selectedPieceIndex!] == null) return;
    GamePiece currentPiece = availablePieces[selectedPieceIndex!]!;

    if (activeTrace.length != currentPiece.shape.length) return;

    // ── Place cells on grid ──
    int placementPoints = 0;
    _thudCells = Set.from(activeTrace);
    for (var c in activeTrace) {
      if (grid[c.x][c.y] == 0) {
        grid[c.x][c.y] = currentPiece.colorIndex;
        capturedCount++;
        placementPoints += 10;
      }
    }
    _thudController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _thudCells.clear();
        });
      }
    });

    // ── Streak bonus ──
    streakCount++;
    int streakBonus = streakCount * 5;
    gameScore += placementPoints + streakBonus;
    _haptic(HapticType.heavy);

    // ── Line clear ──
    int cleared = _performLineClear();
    if (cleared > 0) {
      comboCount++;
      if (comboCount > 1) {
        _queueComboText(_comboLabel(comboCount));
      }
      _checkPerfectClear();
    } else {
      comboCount = 0;
    }

    // ── Clean up piece ──
    availablePieces[selectedPieceIndex!] = null;
    selectedPieceIndex = null;
    activeTrace.clear();

    // ── Advance tutorial on first successful placement ──
    if (_tutorialStep == 2) {
      _tutorialStep = 0;
      _hintTrace = null;
      _resetIdleTimer();
    }

    // ── Refill from next set if all used ──
    if (availablePieces.every((p) => p == null)) {
      availablePieces = List<GamePiece?>.from(nextPieces);
      nextPieces = _createPieceSet();
      _dealController.forward(from: 0.0);
    }

    // ── Auto-select next available piece ──
    for (int i = 0; i < 3; i++) {
      if (availablePieces[i] != null) {
        selectedPieceIndex = i;
        break;
      }
    }

    // ── Check game over ──
    if (!canAnyPieceFit()) {
      _tutorialStep = 0; // stop tutorial
      gameState = 'END';
      if (gameScore > highScore) {
        highScore = gameScore;
        isNewHighScore = true;
        _saveHighScore(highScore);

        // Notify player of new record
        NotificationService().showInstantNotification(
          title: '🏆 New Record!',
          body:
              'Fantastic! You just set a new high score of $highScore! Keep up the great work.',
          useBigText: true,
        );
      }
      _shakeController.forward(from: 0);
    } else {
      _requiresLift = true;
    }
    _resetIdleTimer();
  }

  void _executeMoveTo(int newX, int newY) {
    if (selectedPieceIndex == null) return;
    // Guard: reset if piece index is invalid
    if (availablePieces[selectedPieceIndex!] == null) {
      selectedPieceIndex = null;
      return;
    }
    GamePiece currentPiece = availablePieces[selectedPieceIndex!]!;

    if (newX < 0 || newX >= gridSize || newY < 0 || newY >= gridSize) return;
    if (grid[newX][newY] != 0) return;

    GameCoordinate newPos = GameCoordinate(newX, newY);

    if (activeTrace.contains(newPos)) {
      setState(() {
        playerCoord = newPos;
      });
      _haptic(HapticType.selection);
      return;
    }

    Set<GameCoordinate> simulatedTrace = Set.from(activeTrace)..add(newPos);
    if (!isValidTraceShape(simulatedTrace, currentPiece.shape)) {
      _haptic(HapticType.selection);
      _shakeController.forward(from: 0);
      if (_tutorialStep == 2) {
        activeTrace.clear(); // Safe-fail, let them try again
      }
      return;
    }

    _haptic(HapticType.light);

    setState(() {
      playerCoord = newPos;
      activeTrace.add(newPos);
      _tryCompletePlacement();
    });
  }

  // ═══════════════════════════════════════════════════
  //  UI HELPERS
  // ═══════════════════════════════════════════════════

  Widget _buildStatCard(String label, String value, GameLayout layout,
      {IconData? icon, bool highlight = false}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('$label-$value'),
      duration: Duration(milliseconds: highlight ? 400 : 200),
      tween: Tween(begin: highlight ? 1.4 : 1.15, end: 1.0),
      curve: highlight ? Curves.elasticOut : Curves.easeOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: layout.statCardWidth,
        padding:
            EdgeInsets.symmetric(vertical: layout.statCardPadV, horizontal: 4),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: gameYellow, size: layout.fontSm),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: highlight
                            ? gameYellow.withValues(alpha: 0.9)
                            : fontWhite.withValues(alpha: 0.7),
                        fontSize: layout.fontSm * 1.2,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                    color: highlight ? gameYellow : fontWhite,
                    fontSize: layout.fontMd * 1.5,
                    fontWeight: FontWeight.bold,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BOARD
  // ═══════════════════════════════════════════════════

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) {
            if (gameState != 'PLAY') return;
            if (_tutorialStep == 1) {
              setState(() {
                _tutorialStep = 2;
                _isAutoPlayingDemo = false;
                _handVisible = false;
              });
            }
            _requiresLift = false;
            _resetIdleTimer();

            double cellSize = constraints.maxWidth / gridSize;
            int tappedX = (details.localPosition.dx / cellSize).floor();
            int tappedY = (details.localPosition.dy / cellSize).floor();

            if (tappedX >= 0 &&
                tappedX < gridSize &&
                tappedY >= 0 &&
                tappedY < gridSize) {
              if (grid[tappedX][tappedY] != 0) return;

              GameCoordinate tappedPos = GameCoordinate(tappedX, tappedY);
              setState(() {
                playerCoord = tappedPos;
                if (selectedPieceIndex != null) {
                  activeTrace.clear();
                  activeTrace.add(tappedPos);
                  // Immediately complete if piece is 1 cell (tap = place)
                  _tryCompletePlacement();
                }
              });
              _haptic(HapticType.selection);
            }
          },
          onPanUpdate: (details) {
            if (gameState != 'PLAY' || _requiresLift) return;
            _resetIdleTimer();

            double cellSize = constraints.maxWidth / gridSize;
            int hoverX = (details.localPosition.dx / cellSize).floor();
            int hoverY = (details.localPosition.dy / cellSize).floor();

            if (hoverX >= 0 &&
                hoverX < gridSize &&
                hoverY >= 0 &&
                hoverY < gridSize) {
              if (hoverX != playerCoord.x || hoverY != playerCoord.y) {
                _executeMoveTo(hoverX, hoverY);
              }
            }
          },
          behavior: HitTestBehavior.opaque,
          child: TweenAnimationBuilder<Offset>(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            tween: Tween<Offset>(
              begin: Offset(playerCoord.x.toDouble(), playerCoord.y.toDouble()),
              end: Offset(playerCoord.x.toDouble(), playerCoord.y.toDouble()),
            ),
            builder: (context, visualOffset, child) {
              return CustomPaint(
                key: _boardKey,
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: GamePainter(
                  gridSize,
                  grid,
                  visualOffset,
                  activeTrace,
                  selectedPieceIndex != null &&
                          availablePieces[selectedPieceIndex!] != null
                      ? availablePieces[selectedPieceIndex!]!.colorIndex
                      : 0,
                  _hintTrace,
                  _fingerController.value,
                  _clearingCells,
                  _clearController.value,
                  _thudCells,
                  _thudController.value,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  //  PIECE SELECTOR
  // ═══════════════════════════════════════════════════

  Widget _buildPieceSelector(GameLayout layout) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(3, (index) {
          GamePiece? piece = availablePieces[index];
          bool isSelected = selectedPieceIndex == index;

          return GestureDetector(
            onPanDown: (_) => selectPiece(index),
            child: AnimatedBuilder(
              animation: _dealController,
              builder: (context, child) {
                double scl = piece != null
                    ? Curves.elasticOut
                        .transform(_dealController.value.clamp(0.0, 1.0))
                    : 1.0;
                return Transform.scale(
                  scale: scl,
                  child: child,
                );
              },
              child: AnimatedContainer(
                key: _pieceKeys[index],
                duration: const Duration(milliseconds: 88),
                width: layout.pieceSlotSize,
                height: layout.pieceSlotSize,
                margin: EdgeInsets.symmetric(horizontal: layout.spacingSm),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cardDarkBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? gameYellow : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: piece == null
                    ? null
                    : RepaintBoundary(
                        child: CustomPaint(
                          painter:
                              ShapeHudPainter(piece.shape, piece.colorIndex),
                        ),
                      ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  NEXT PREVIEW
  // ═══════════════════════════════════════════════════

  Widget _buildNextPreview(GameLayout layout) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("NEXT",
            style: TextStyle(
              color: fontWhite.withValues(alpha: 0.35),
              fontSize: layout.fontSm * 0.9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            )),
        SizedBox(width: layout.spacingSm),
        ...List.generate(3, (index) {
          GamePiece? piece = nextPieces[index];
          return Container(
            width: layout.nextSlotSize,
            height: layout.nextSlotSize,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: cardDarkBlue.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: piece == null
                ? null
                : RepaintBoundary(
                    child: CustomPaint(
                      painter: ShapeHudPainter(piece.shape, piece.colorIndex),
                    ),
                  ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  SCORE POPUP WIDGET
  // ═══════════════════════════════════════════════════

  Widget _buildScorePopupWidget(ScorePopup popup) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: popup.key,
        duration: const Duration(milliseconds: 1000),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, progress, _) {
          double scl = 0.8 + (progress * 0.4); // starts smaller, grows
          return Center(
            child: Transform.translate(
              offset: Offset(0, -progress * 100), // floats higher
              child: Transform.scale(
                scale: scl,
                child: Opacity(
                  opacity: (1.0 - (progress * progress)).clamp(0.0, 1.0),
                  child: Text(
                    popup.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: popup.color,
                      fontSize: popup.isLarge ? 38.0 : 30.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                        Shadow(
                          color: popup.color.withValues(alpha: 0.4),
                          offset: const Offset(0, 0),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final layout = GameLayout(
      screenWidth: mq.size.width,
      screenHeight: mq.size.height,
      safeTop: mq.padding.top,
      safeBottom: mq.padding.bottom,
    );

    return Scaffold(
      backgroundColor: bgDarkBlue,
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            // ── Main game column ──
            Column(
              children: [
                // ── Top bar: spacing + settings gear ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: layout.spacingSm),
                  child: Row(
                    children: [
                      if (highScore > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events,
                                color: gameYellow, size: layout.fontMd * 1.8),
                            const SizedBox(width: 8),
                            Text(
                              "$highScore",
                              style: TextStyle(
                                color: gameYellow,
                                fontSize: layout.fontMd,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (_tutorialStep > 0) const SizedBox(width: 12),
                          ],
                        ),
                      if (_tutorialStep > 0)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _tutorialStep = 0;
                              _hintTrace = null;
                              _isAutoPlayingDemo = false;
                              _handVisible = false;
                              selectedPieceIndex = null;
                              activeTrace.clear();
                              _resetIdleTimer();
                            });
                          },
                          child: Text("SKIP",
                              style: TextStyle(
                                  color: fontWhite.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.bold)),
                        ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _showTutorial(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.help_outline_rounded,
                              color: fontWhite.withValues(alpha: 0.6),
                              size: layout.fontMd * 1.4),
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _showSettings(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.settings_rounded,
                              color: gameYellow, size: layout.fontMd * 1.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Stats Row ──
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: layout.spacingSm,
                  runSpacing: layout.spacingXs,
                  children: [
                    _buildStatCard("SCORE", "$score", layout),
                    _buildStatCard("LVL", "$level", layout),
                    if (comboCount > 1)
                      _buildStatCard("COMBO", "×$comboCount", layout,
                          highlight: true),
                  ],
                ),

                SizedBox(height: layout.spacingXs),

                // ── Board ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: AspectRatio(
                              aspectRatio: 1,
                            child: AnimatedBuilder(
                              animation: Listenable.merge(
                                  [_shakeController, _fingerController]),
                              builder: (context, child) {
                                double shake =
                                    sin(_shakeController.value * pi * 6) *
                                        (1 - _shakeController.value) *
                                        6;
                                return Transform.translate(
                                  offset: Offset(shake, 0),
                                  child: child,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: bgDarkBlue,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: comboCount > 1 ? gameYellow : fontWhite,
                                    width: comboCount > 1 ? 3.0 : 2.0,
                                  ),
                                ),
                                padding: const EdgeInsets.all(3.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      RepaintBoundary(child: _buildBoard()),

                                      // Score popups
                                      ..._scorePopups
                                          .map((p) => _buildScorePopupWidget(p)),

                                      // Combo text overlay
                                      if (_comboText != null)
                                        IgnorePointer(
                                          child: Center(
                                            child: TweenAnimationBuilder<double>(
                                              key: ValueKey(_comboText),
                                              duration:
                                                  const Duration(milliseconds: 400),
                                              tween: Tween(begin: 0.5, end: 1.0),
                                              curve: Curves.elasticOut,
                                              builder: (context, scale, child) {
                                                return Transform.scale(
                                                    scale: scale, child: child);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 20, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: bgDarkBlue.withValues(
                                                      alpha: 0.85),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                      color: gameYellow, width: 2),
                                                ),
                                                child: Text(_comboText!,
                                                    style: TextStyle(
                                                      color: gameYellow,
                                                      fontSize: layout.fontLg * 0.9,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 2,
                                                    )),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Game over overlay
                                      if (gameState == 'STUCK' ||
                                          gameState == 'END')
                                        TweenAnimationBuilder<double>(
                                          key: const ValueKey('game_over_fade'),
                                          duration:
                                              const Duration(milliseconds: 400),
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          curve: Curves.easeOut,
                                          builder: (context, opacity, child) {
                                            return Opacity(
                                                opacity: opacity, child: child);
                                          },
                                          child: Container(
                                            color:
                                                bgDarkBlue.withValues(alpha: 0.9),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (isNewHighScore) ...[
                                                    const Icon(Icons.stars,
                                                        color: gameYellow,
                                                        size: 56),
                                                    SizedBox(
                                                        height: layout.spacingMd),
                                                    Text("NEW RECORD!",
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                            color: gameYellow,
                                                            fontSize: layout.fontXl,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            letterSpacing: 2)),
                                                  ] else ...[
                                                    Text(
                                                        gameState == 'STUCK'
                                                            ? "TRAPPED!"
                                                            : "GAME OVER",
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                            color:
                                                                gameState == 'STUCK'
                                                                    ? gameYellow
                                                                    : fontWhite,
                                                            fontSize: layout.fontXl,
                                                            fontWeight:
                                                                FontWeight.bold)),
                                                  ],
                                                  SizedBox(
                                                      height: layout.spacingSm),
                                                  Text("FINAL SCORE: $score",
                                                      style: TextStyle(
                                                          color: fontWhite,
                                                          fontSize: layout.fontMd,
                                                          letterSpacing: 1.5)),
                                                  if (streakCount > 0) ...[
                                                    SizedBox(
                                                        height: layout.spacingXs),
                                                    Text("STREAK: $streakCount",
                                                        style: TextStyle(
                                                            color: fontWhite
                                                                .withValues(
                                                                    alpha: 0.6),
                                                            fontSize: layout.fontSm,
                                                            letterSpacing: 1)),
                                                  ],
                                                  if (linesCleared > 0) ...[
                                                    SizedBox(
                                                        height: layout.spacingXs),
                                                    Text(
                                                        "LINES: $linesCleared  •  LEVEL: $level",
                                                        style: TextStyle(
                                                            color: fontWhite
                                                                .withValues(
                                                                    alpha: 0.5),
                                                            fontSize: layout.fontSm,
                                                            letterSpacing: 1)),
                                                  ],
                                                  SizedBox(
                                                      height: layout.spacingMd),
                                                  GestureDetector(
                                                    onPanDown: (_) {
                                                      _haptic(HapticType.light);
                                                      initGame();
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 32,
                                                          vertical: 16),
                                                      decoration: BoxDecoration(
                                                        color: gameYellow,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                100),
                                                      ),
                                                      child: const Text(
                                                          "PLAY AGAIN",
                                                          style: TextStyle(
                                                              color: bgDarkBlue,
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              letterSpacing: 1.5)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: 102,
                  child: (_isAdLoaded && _bannerAd != null)
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 4),
                            Transform.scale(
                              scale: 0.75,
                              child: SizedBox(
                                height: _bannerAd!.size.height.toDouble(),
                                width: _bannerAd!.size.width.toDouble(),
                                child: AdWidget(ad: _bannerAd!),
                              ),
                            ),
                            const SizedBox(height: 48),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                // ── Piece selector ──
                _buildPieceSelector(layout),

                SizedBox(height: layout.spacingXs),

                // ── Next preview ──
                if (gameState == 'PLAY') _buildNextPreview(layout),

                SizedBox(height: layout.spacingSm),

                // ── Action button ──
                if (gameState != 'PLAY')
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      double s = 1.0 + (_pulseController.value * 0.025);
                      return Transform.scale(scale: s, child: child);
                    },
                    child: SizedBox(
                      width: layout.buttonWidth,
                      child: ElevatedButton(
                        onPressed: () {
                          _haptic(HapticType.light);
                          initGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gameYellow,
                          elevation: 0,
                          padding:
                              EdgeInsets.symmetric(vertical: layout.buttonPadV),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100)),
                        ),
                        child: Text("NEW GAME",
                            style: TextStyle(
                                color: bgDarkBlue,
                                fontSize: layout.buttonFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                    ),
                  )
                else
                  SizedBox(height: layout.spacingSm),

                SizedBox(height: layout.spacingXs),

              ],
            ),

            // ── Animated Global Hand for Tutorial Demo ──
            if (_tutorialStep == 1)
              AnimatedPositioned(
                  duration: _handDuration,
                  curve: _handCurve,
                  left: _handPos.dx -
                      (layout.pieceSlotSize * 0.4), // center offset correctly
                  top: _handPos.dy - (layout.pieceSlotSize * 0.1),
                  child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _handVisible ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: _handPressed ? 0.8 : 1.0,
                        child: IgnorePointer(
                            child: Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: layout.pieceSlotSize * 0.8,
                        )),
                      ))),
          ],
        ),
      ),
    );
  }
}

