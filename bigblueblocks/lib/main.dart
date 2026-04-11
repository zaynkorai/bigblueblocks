import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const BigBlueBlocksApp());
}

// ═══════════════════════════════════════════════════════
//  THEME CONSTANTS
// ═══════════════════════════════════════════════════════

const Color bgDarkBlue = Color(0xFF0A1931);
const Color cardDarkBlue = Color(0xFF152A4A);
const Color gameYellow = Color(0xFFFFC900);
const Color fontWhite = Colors.white;

const List<Color> shapeColors = [
  Colors.transparent, // 0 - Empty
  Colors.white, // 1 - Hurdle
  Color(0xFF00F0FF), // 2 - Cyan
  Color(0xFFFFC900), // 3 - Yellow
  Color(0xFFBC13FE), // 4 - Purple
  Color(0xFFFF5E00), // 5 - Orange
  Color(0xFF0077FF), // 6 - Blue
  Color(0xFF00FF55), // 7 - Green
  Color(0xFFFF003C), // 8 - Red
  Color(0xFFFF33CC), // 9 - Pink
  Color(0xFFCCFF00), // 10 - Lime
  Color(0xFF00CED1), // 11 - Teal
  Color(0xFFFF6B81), // 12 - Coral
  Color(0xFF7B68EE), // 13 - Slate Blue
  Color(0xFFFFD700), // 14 - Gold
  Color(0xFF40E0D0), // 15 - Turquoise
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
  const BigBlueBlocksApp({Key? key}) : super(key: key);

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
  const GameScreen({Key? key}) : super(key: key);
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
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
  bool _showTraceHint = true;

  // ── Gamification ──
  int comboCount = 0;
  int streakCount = 0;

  int get level => min((linesCleared ~/ 5) + 1, 10);
  int get hurdleCount => min(level, 4);
  int get score => gameScore;

  // ── Settings ──
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  /// Gated haptic feedback — respects vibration toggle.
  void _haptic(HapticType type) {
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
  }

  void _showSettings() {
    showDialog(
      context: context,
      barrierColor: bgDarkBlue.withValues(alpha: 0.8),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: cardDarkBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('SETTINGS',
                        style: TextStyle(
                            color: fontWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const SizedBox(height: 24),
                    _settingsRow(
                      icon: Icons.volume_up_rounded,
                      label: 'Sound',
                      value: _soundEnabled,
                      onChanged: (v) {
                        setDialogState(() => _soundEnabled = v);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    _settingsRow(
                      icon: Icons.vibration_rounded,
                      label: 'Vibration',
                      value: _vibrationEnabled,
                      onChanged: (v) {
                        setDialogState(() => _vibrationEnabled = v);
                        setState(() {});
                        if (v) _haptic(HapticType.light);
                      },
                    ),
                    const SizedBox(height: 24),
                    Divider(color: fontWhite.withValues(alpha: 0.1)),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showMoreSettings();
                      },
                      child: Text(
                        'More Settings',
                        style: TextStyle(
                          color: fontWhite.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMoreSettings() {
    showDialog(
      context: context,
      barrierColor: bgDarkBlue.withValues(alpha: 0.8),
      builder: (ctx) {
        return Dialog(
          backgroundColor: cardDarkBlue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('MORE SETTINGS',
                    style: TextStyle(
                        color: fontWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 24),

                // App Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgDarkBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_view_rounded,
                          color: gameYellow, size: 28),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BigBlueBlocks',
                              style: TextStyle(
                                  color: fontWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text('Version 1.0.0',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Links
                _linkRow(icon: Icons.mail_rounded, label: 'Contact Us'),
                _linkRow(
                    icon: Icons.share_rounded, label: 'Share with friends'),
                const SizedBox(height: 12),

                // Social Icons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialIcon(Icons.facebook_rounded),
                    _socialIcon(Icons.camera_alt_rounded), // Insta placeholder
                    _socialIcon(
                        Icons.alternate_email_rounded), // Twitter/X placeholder
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: fontWhite.withValues(alpha: 0.1)),
                const SizedBox(height: 12),

                _linkRow(
                    icon: Icons.description_rounded, label: 'Terms of Service'),
                _linkRow(
                    icon: Icons.privacy_tip_rounded, label: 'Privacy Policy'),
                _linkRow(icon: Icons.info_rounded, label: 'About Us'),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close',
                      style: TextStyle(
                          color: gameYellow, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _linkRow({required IconData icon, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          _haptic(HapticType.light);
        },
        child: Row(
          children: [
            Icon(icon, color: fontWhite.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: fontWhite.withValues(alpha: 0.9), fontSize: 14)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: fontWhite.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () => _haptic(HapticType.light),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgDarkBlue.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: fontWhite.withValues(alpha: 0.8), size: 22),
        ),
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: gameYellow, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: fontWhite, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: gameYellow,
          activeTrackColor: gameYellow.withValues(alpha: 0.3),
          inactiveThumbColor: fontWhite.withValues(alpha: 0.4),
          inactiveTrackColor: fontWhite.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  // ── Visual Feedback ──
  final List<ScorePopup> _scorePopups = [];
  String? _comboText;
  Timer? _comboTimer;

  // ── Animations ──
  late AnimationController _pulseController;
  late AnimationController _shakeController;

  // ═══════════════════════════════════════════════════
  //  LIFECYCLE
  // ═══════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    initGame();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _comboTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════
  //  PIECE GENERATION
  // ═══════════════════════════════════════════════════

  // Pieces grouped by difficulty tier
  // Tier 0 (Levels 1-4): dot, 2-line, corner, 3-line, O-block, L-block
  // Tier 1 (Levels 5-6): 4-line, T-block
  // Tier 2 (Levels 7+): 5-line, Plus, U
  static final List<List<List<GameCoordinate>>> _pieceTiers = [
    // ── Tier 0 (Levels 1-4) ──
    [
      [const GameCoordinate(0, 0)],
      [const GameCoordinate(0, 0), const GameCoordinate(1, 0)],
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(1, 1)
      ],
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(2, 0)
      ],
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(1, 1)
      ],
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(0, 2),
        const GameCoordinate(1, 2)
      ],
    ],
    // ── Tier 1 (Levels 5-6) ──
    [
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(2, 0),
        const GameCoordinate(3, 0)
      ],
      [
        const GameCoordinate(1, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(1, 1),
        const GameCoordinate(2, 1)
      ],
    ],
    // ── Tier 2 (Levels 7+) ──
    [
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(1, 0),
        const GameCoordinate(2, 0),
        const GameCoordinate(3, 0),
        const GameCoordinate(4, 0)
      ],
      [
        const GameCoordinate(1, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(1, 1),
        const GameCoordinate(2, 1),
        const GameCoordinate(1, 2)
      ],
      [
        const GameCoordinate(0, 0),
        const GameCoordinate(2, 0),
        const GameCoordinate(0, 1),
        const GameCoordinate(1, 1),
        const GameCoordinate(2, 1)
      ],
    ],
  ];

  /// Returns the available piece pool for the current level.
  /// Higher levels unlock harder tiers while keeping all earlier shapes.
  List<List<GameCoordinate>> _piecePoolForLevel(int lvl) {
    List<List<GameCoordinate>> pool = [];
    pool.addAll(_pieceTiers[0]); // Always available
    if (lvl >= 5) pool.addAll(_pieceTiers[1]);
    if (lvl >= 7) pool.addAll(_pieceTiers[2]);
    return pool;
  }

  List<GamePiece?> _createPieceSet() {
    const int minColor = 2;
    const int maxColor = 15;
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

  void selectPiece(int index) {
    if (availablePieces[index] == null) return;
    setState(() {
      selectedPieceIndex = index;
      activeTrace.clear();
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
    _showTraceHint = true;

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
      grid[c.x][c.y] = 0;
    }

    int lineBonus = 150 * totalLines;
    int comboBonus = comboCount > 1 ? 100 * (comboCount - 1) : 0;
    int totalBonus = cellPoints + lineBonus + comboBonus;

    gameScore += totalBonus;
    linesCleared += totalLines;

    _placeHurdles();
    totalCapturable = gridSize * gridSize - hurdleCount;

    // Queue score popup (Timer removal can call setState safely later)
    _queueScorePopup("+$totalBonus", gameYellow);

    _haptic(HapticType.heavy);
    return totalLines;
  }

  /// Check if every non-hurdle cell is empty → perfect clear.
  /// Mutates state directly — call from within setState.
  void _checkPerfectClear() {
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (grid[x][y] >= 2) return;
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
      if (mounted)
        setState(() {
          _comboText = null;
        });
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
    for (var c in activeTrace) {
      if (grid[c.x][c.y] == 0) {
        grid[c.x][c.y] = currentPiece.colorIndex;
        capturedCount++;
        placementPoints += 10;
      }
    }

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
    _showTraceHint = false;

    // ── Refill from next set if all used ──
    if (availablePieces.every((p) => p == null)) {
      availablePieces = List<GamePiece?>.from(nextPieces);
      nextPieces = _createPieceSet();
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
      gameState = 'END';
      if (gameScore > highScore) {
        highScore = gameScore;
        isNewHighScore = true;
      }
      _shakeController.forward(from: 0);
    } else {
      _requiresLift = true;
    }
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
    return Container(
      width: layout.statCardWidth,
      padding:
          EdgeInsets.symmetric(vertical: layout.statCardPadV, horizontal: 4),
      decoration: BoxDecoration(
        color: highlight ? gameYellow.withValues(alpha: 0.15) : cardDarkBlue,
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: gameYellow.withValues(alpha: 0.4), width: 1)
            : null,
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
                      color: fontWhite.withValues(alpha: 0.7),
                      fontSize: layout.fontSm * 0.85,
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
                  fontSize: layout.fontMd,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ],
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
            _requiresLift = false;

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
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: GamePainter(
              gridSize,
              grid,
              playerCoord,
              activeTrace,
              selectedPieceIndex != null &&
                      availablePieces[selectedPieceIndex!] != null
                  ? availablePieces[selectedPieceIndex!]!.colorIndex
                  : 0,
            ),
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
            onTap: () => selectPiece(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: gameYellow.withValues(alpha: 0.3),
                            blurRadius: 10)
                      ]
                    : null,
              ),
              child: piece == null
                  ? null
                  : RepaintBoundary(
                      child: CustomPaint(
                        painter: ShapeHudPainter(piece.shape, piece.colorIndex),
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
        duration: const Duration(milliseconds: 1200),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, progress, _) {
          return Center(
            child: Transform.translate(
              offset: Offset(0, -progress * 60),
              child: Opacity(
                opacity: (1.0 - progress).clamp(0.0, 1.0),
                child: Text(
                  popup.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: popup.color,
                    fontSize: popup.isLarge ? 20 : 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                          color: popup.color.withValues(alpha: 0.6),
                          blurRadius: 10),
                    ],
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
        child: Column(
          children: [
            // ── Top bar: spacing + settings gear ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.spacingSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _showSettings,
                    child: Icon(Icons.settings_rounded,
                        color: fontWhite.withValues(alpha: 0.4),
                        size: layout.fontMd * 1.8),
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
                if (highScore > 0)
                  _buildStatCard("BEST", "$highScore", layout,
                      icon: Icons.emoji_events),
              ],
            ),

            SizedBox(height: layout.spacingXs),

            // ── Board ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: layout.spacingSm),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        double shake = sin(_shakeController.value * pi * 6) *
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
                          boxShadow: comboCount > 1
                              ? [
                                  BoxShadow(
                                    color: gameYellow.withValues(
                                        alpha: (0.2 + comboCount * 0.08)
                                            .clamp(0.0, 0.6)),
                                    blurRadius: 10.0 + comboCount * 3.0,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
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
                                          boxShadow: [
                                            BoxShadow(
                                                color: gameYellow.withValues(
                                                    alpha: 0.4),
                                                blurRadius: 20),
                                          ],
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
                              if (gameState == 'STUCK' || gameState == 'END')
                                Container(
                                  color: bgDarkBlue.withValues(alpha: 0.9),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (isNewHighScore) ...[
                                          const Icon(Icons.stars,
                                              color: gameYellow, size: 56),
                                          SizedBox(height: layout.spacingMd),
                                          Text("NEW RECORD!",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: gameYellow,
                                                  fontSize: layout.fontXl,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 2)),
                                        ] else ...[
                                          Text(
                                              gameState == 'STUCK'
                                                  ? "TRAPPED!"
                                                  : "GAME OVER",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: gameState == 'STUCK'
                                                      ? gameYellow
                                                      : fontWhite,
                                                  fontSize: layout.fontXl,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                        SizedBox(height: layout.spacingSm),
                                        Text("FINAL SCORE: $score",
                                            style: TextStyle(
                                                color: fontWhite,
                                                fontSize: layout.fontMd,
                                                letterSpacing: 1.5)),
                                        if (streakCount > 0) ...[
                                          SizedBox(height: layout.spacingXs),
                                          Text("STREAK: $streakCount",
                                              style: TextStyle(
                                                  color: fontWhite.withValues(
                                                      alpha: 0.6),
                                                  fontSize: layout.fontSm,
                                                  letterSpacing: 1)),
                                        ],
                                        if (linesCleared > 0) ...[
                                          SizedBox(height: layout.spacingXs),
                                          Text(
                                              "LINES: $linesCleared  •  LEVEL: $level",
                                              style: TextStyle(
                                                  color: fontWhite.withValues(
                                                      alpha: 0.5),
                                                  fontSize: layout.fontSm,
                                                  letterSpacing: 1)),
                                        ],
                                      ],
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
              ),
            ),

            // ── Hint text ──
            if (gameState == 'PLAY' && _showTraceHint)
              Padding(
                padding: EdgeInsets.symmetric(vertical: layout.spacingXs),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: Text(
                    activeTrace.length <= 1
                        ? "TAP ANY CELL TO START"
                        : "DRAG TO TRACE THE SHAPE",
                    style: TextStyle(
                      color: gameYellow,
                      fontSize: layout.fontSm,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

            SizedBox(height: layout.spacingXs),

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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SHAPE HUD PAINTER (mini piece preview)
// ═══════════════════════════════════════════════════════

class ShapeHudPainter extends CustomPainter {
  final List<GameCoordinate> targetShape;
  final int colorIndex;

  ShapeHudPainter(this.targetShape, this.colorIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (targetShape.isEmpty) return;
    int maxW = targetShape.map((e) => e.x).reduce(max) + 1;
    int maxH = targetShape.map((e) => e.y).reduce(max) + 1;

    double cs = min(size.width / 4, size.height / 4);

    double offX = (size.width - (maxW * cs)) / 2;
    double offY = (size.height - (maxH * cs)) / 2;

    // Guard color index bounds
    Color color = (colorIndex >= 0 && colorIndex < shapeColors.length)
        ? shapeColors[colorIndex]
        : Colors.grey;

    Paint p = Paint()..color = color;
    for (var c in targetShape) {
      Rect rect =
          Rect.fromLTWH(offX + c.x * cs, offY + c.y * cs, cs, cs).deflate(2.0);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.25)), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════
//  GAME BOARD PAINTER
// ═══════════════════════════════════════════════════════

class GamePainter extends CustomPainter {
  final int gridSize;
  final List<List<int>> grid;
  final GameCoordinate playerCoord;
  final Set<GameCoordinate> activeTrace;
  final int activeColorIndex;

  GamePainter(this.gridSize, this.grid, this.playerCoord, this.activeTrace,
      this.activeColorIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (grid.isEmpty) return;

    double cellSize = size.width / gridSize;
    double inset = 3.0;
    double radius = 8.0;

    Paint gridPaint = Paint()
      ..color = cardDarkBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    Paint obstaclePaint = Paint()..color = fontWhite;

    Paint hurdleXPaint = Paint()
      ..color = bgDarkBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Guard color index for trace paint
    Color traceColor =
        (activeColorIndex >= 0 && activeColorIndex < shapeColors.length)
            ? shapeColors[activeColorIndex]
            : Colors.grey;
    Paint tracePaint = Paint()..color = traceColor.withValues(alpha: 0.45);

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        Rect rect =
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        Rect cellRect = rect.deflate(inset);
        RRect rrect =
            RRect.fromRectAndRadius(cellRect, Radius.circular(radius));

        if (grid[x][y] == 1) {
          // Hurdle: solid white rounded rect with X mark
          canvas.drawRRect(rrect, obstaclePaint);
          double xi = cellRect.width * 0.28;
          canvas.drawLine(
            Offset(cellRect.left + xi, cellRect.top + xi),
            Offset(cellRect.right - xi, cellRect.bottom - xi),
            hurdleXPaint,
          );
          canvas.drawLine(
            Offset(cellRect.right - xi, cellRect.top + xi),
            Offset(cellRect.left + xi, cellRect.bottom - xi),
            hurdleXPaint,
          );
        } else if (grid[x][y] >= 2) {
          // Captured cell with color, guarded
          int ci = grid[x][y];
          Color cellColor = (ci >= 0 && ci < shapeColors.length)
              ? shapeColors[ci]
              : Colors.grey;
          Paint capturedPaint = Paint()..color = cellColor;
          canvas.drawRRect(rrect, capturedPaint);

          // Subtle inner border for depth
          Paint innerBorder = Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  cellRect.deflate(1.5), Radius.circular(radius - 1)),
              innerBorder);
        }
      }
    }

    // Active trace highlight
    for (var t in activeTrace) {
      Rect rect =
          Rect.fromLTWH(t.x * cellSize, t.y * cellSize, cellSize, cellSize);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.deflate(inset + 1), Radius.circular(radius)),
          tracePaint);
    }

    // Grid lines
    for (int i = 0; i <= gridSize; i++) {
      double pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    // Player cursor
    if (activeTrace.isNotEmpty && activeColorIndex != 0) {
      Color cursorColor =
          (activeColorIndex >= 0 && activeColorIndex < shapeColors.length)
              ? shapeColors[activeColorIndex]
              : Colors.grey;
      Paint playerCore = Paint()..color = cursorColor;
      Rect pRect = Rect.fromLTWH(playerCoord.x * cellSize,
          playerCoord.y * cellSize, cellSize, cellSize);
      canvas.drawCircle(pRect.center, cellSize * 0.35, playerCore);

      Paint dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(pRect.center, cellSize * 0.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
