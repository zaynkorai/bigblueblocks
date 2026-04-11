import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const NeonTurfApp());
}

class NeonTurfApp extends StatelessWidget {
  const NeonTurfApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Turf Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050508),
      ),
      home: const GameScreen(),
    );
  }
}

class GameCoordinate {
  final int x;
  final int y;
  const GameCoordinate(this.x, this.y);
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Mobile touch is easier with slightly smaller resolution than desktop pointer
  int gridSize = 16; 
  List<List<int>> grid = []; 
  int capturedCount = 0;
  int totalCapturable = 0;
  int obstaclesCount = 0;

  int normalMovesMade = 0;
  bool superReady = false;
  bool isSpecialMode = false;

  GameCoordinate targetCoord = const GameCoordinate(8, 8);
  Offset _panAccumulator = Offset.zero;

  List<GameCoordinate> previewCapturable = [];
  List<GameCoordinate> previewShadowed = [];

  double timeLeft = 60.0;
  String gameState = 'START'; 
  Timer? gameTimer;

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  void initGame() {
    grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    obstaclesCount = 0;
    Random rnd = Random();

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        if (x < 3 && y < 3) continue; // Keep Top-Left clear
        if (rnd.nextDouble() < 0.05) { // 5% obstacles
          grid[x][y] = 1;
          obstaclesCount++;
        }
      }
    }

    grid[0][0] = 2; // Starter capture
    capturedCount = 1;
    totalCapturable = (gridSize * gridSize) - obstaclesCount;

    normalMovesMade = 0;
    superReady = false;
    isSpecialMode = false;
    timeLeft = 60.0;
    
    targetCoord = GameCoordinate(gridSize ~/ 2, gridSize ~/ 2);
    _panAccumulator = Offset.zero;
    
    setState(() {
      gameState = 'PLAY';
      _refreshPreview();
    });

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (gameState == 'PLAY') {
        setState(() {
          timeLeft -= 0.1;
          if (timeLeft <= 0) {
            timeLeft = 0;
            gameState = 'END';
            timer.cancel();
          }
        });
      }
    });
  }
  
  Map<String, List<GameCoordinate>> _calcPreview(int tx, int ty, bool special) {
    List<GameCoordinate> capturable = [];
    List<GameCoordinate> shadowed = [];
    
    if (grid[tx][ty] == 1) return {'capturable': [], 'shadowed': []};

    int minX = special ? 0 : 0;
    int maxX = special ? gridSize - 1 : tx;
    int minY = special ? 0 : 0;
    int maxY = special ? gridSize - 1 : ty;

    List<List<bool>> shadow = List.generate(gridSize, (_) => List.filled(gridSize, false));

    for (int ox = 0; ox < gridSize; ox++) {
      for (int oy = 0; oy < gridSize; oy++) {
        if (grid[ox][oy] == 1) { // Obstacle
          if (!special) {
            if (ox <= tx && oy <= ty) { // In bounding box
              for (int i = 0; i <= ox; i++) {
                for (int j = 0; j <= oy; j++) shadow[i][j] = true;
              }
            }
          } else {
            // Omni-Grab casts shadows in all quadrants from the target
            if (ox <= tx && oy <= ty) {
              for (int i = 0; i <= ox; i++) for (int j = 0; j <= oy; j++) shadow[i][j] = true;
            }
            if (ox >= tx && oy <= ty) {
              for (int i = ox; i < gridSize; i++) for (int j = 0; j <= oy; j++) shadow[i][j] = true;
            }
            if (ox <= tx && oy >= ty) {
              for (int i = 0; i <= ox; i++) for (int j = oy; j < gridSize; j++) shadow[i][j] = true;
            }
            if (ox >= tx && oy >= ty) {
              for (int i = ox; i < gridSize; i++) for (int j = oy; j < gridSize; j++) shadow[i][j] = true;
            }
          }
        }
      }
    }

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        if (grid[x][y] != 1) {
          if (shadow[x][y]) {
            shadowed.add(GameCoordinate(x, y));
          } else if (grid[x][y] == 0) {
            capturable.add(GameCoordinate(x, y));
          }
        }
      }
    }

    return {'capturable': capturable, 'shadowed': shadowed};
  }
  
  void _refreshPreview() {
     var pre = _calcPreview(targetCoord.x, targetCoord.y, isSpecialMode);
     previewCapturable = pre['capturable']!;
     previewShadowed = pre['shadowed']!;
  }

  void _handleSwipeUpdate(DragUpdateDetails details) {
    if (gameState != 'PLAY') return;
    
    _panAccumulator += details.delta;
    double sensitivity = 18.0; // swipe pixels required to move 1 cell
    
    int dx = (_panAccumulator.dx / sensitivity).truncate();
    int dy = (_panAccumulator.dy / sensitivity).truncate();
    
    if (dx != 0 || dy != 0) {
      setState(() {
        int newX = (targetCoord.x + dx).clamp(0, gridSize - 1);
        int newY = (targetCoord.y + dy).clamp(0, gridSize - 1);
        targetCoord = GameCoordinate(newX, newY);
        
        // consume the processed delta
        _panAccumulator = Offset(
            _panAccumulator.dx - dx * sensitivity,
            _panAccumulator.dy - dy * sensitivity
        );
        
        _refreshPreview();
      });
    }
  }

  void _commitCapture() {
    if (gameState != 'PLAY') return;

    if (previewCapturable.isNotEmpty) {
      setState(() {
        for (var p in previewCapturable) {
          grid[p.x][p.y] = 2; // Capture
          capturedCount++;
        }

        if (isSpecialMode) {
          isSpecialMode = false;
          superReady = false;
          normalMovesMade = 0;
        } else {
          if (!superReady) {
            normalMovesMade++;
            if (normalMovesMade >= 4) {
              superReady = true;
            }
          }
        }

        if (capturedCount >= totalCapturable) {
          gameState = 'END';
          gameTimer?.cancel();
        }
        
        _refreshPreview();
      });
    }
  }

  Widget _StatCard(String label, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2235)),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 5))]
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget buildBoard() {
    if (gameState == 'START') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.grid_4x4, size: 64, color: Color(0xFF1E2235)),
            SizedBox(height: 16),
            Text("WAITING FOR INITIALIZATION", style: TextStyle(color: Colors.grey, letterSpacing: 2))
          ],
        )
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          // Trackpad-style swipe navigation
          onPanUpdate: _handleSwipeUpdate,
          onTap: _commitCapture,
          // Expand hit area to full container
          behavior: HitTestBehavior.opaque,
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxWidth),
            painter: GamePainter(gridSize, grid, targetCoord, previewCapturable, previewShadowed, isSpecialMode),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int pct = totalCapturable > 0 ? (capturedCount * 100 ~/ totalCapturable) : 0;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Text("NEON TURF", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [
               Shadow(color: Color(0xFF00F0FF), blurRadius: 10)
            ])),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 _StatCard("AREA SECURED", "$pct%"),
                 _StatCard("TIME LEFT", "${timeLeft.ceil()}s"),
              ]
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                 "SWIPE ANYWHERE to move crosshair.\nTAP to execute hack. Avoid red barriers.",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
              ),
            ),
            
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                 margin: const EdgeInsets.symmetric(horizontal: 24),
                 decoration: BoxDecoration(
                   color: const Color(0xFF030407),
                   border: Border.all(color: const Color(0xFF1E2235)),
                   boxShadow: const [BoxShadow(color: Color(0x3300F0FF), blurRadius: 30)]
                 ),
                 child: buildBoard()
              )
            ),
            
            // Super Action Button
            GestureDetector(
               onTap: () {
                  if (superReady && gameState == 'PLAY') {
                     setState(() { 
                       isSpecialMode = !isSpecialMode;
                       _refreshPreview();
                     });
                  }
               },
               child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                     color: isSpecialMode ? const Color(0x33BC13FE) : const Color(0xFF0F111A),
                     border: Border.all(color: superReady ? const Color(0xFFBC13FE) : const Color(0xFF1E2235)),
                     borderRadius: BorderRadius.circular(12),
                     boxShadow: superReady ? [const BoxShadow(color: Color(0x66BC13FE), blurRadius: 10)] : []
                  ),
                  child: Row(
                     children: [
                        Icon(Icons.stars_rounded, color: superReady ? Colors.white : Colors.grey, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                const Text("SUPER GRAB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                   value: superReady ? 1.0 : (normalMovesMade / 4.0),
                                   backgroundColor: Colors.black54,
                                   valueColor: AlwaysStoppedAnimation<Color>(superReady ? const Color(0xFFBC13FE) : const Color(0xFF00F0FF)),
                                ),
                                const SizedBox(height: 8),
                                Text(superReady ? (isSpecialMode ? "WARNING: OMNI-BLAST ARMED" : "READY! TAP TO ACTIVATE") : "$normalMovesMade / 4 MOVES TO UNLOCK", 
                                  style: TextStyle(color: superReady ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))
                             ]
                          )
                        )
                     ]
                  )
               )
            ),
            
            if (gameState != 'PLAY')
               ElevatedButton(
                  onPressed: initGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F0FF),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: Text(gameState == 'START' ? "HACK THE NETWORK" : (pct == 100 ? "VICTORY! REPLAY" : "NETWORK LOST! REBOOT"), 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.5))
               )
            else const SizedBox(height: 48), // Padding equivalent
         ]
        )
      )
    );
  }
}

class GamePainter extends CustomPainter {
  final int gridSize;
  final List<List<int>> grid;
  final GameCoordinate? touchCoord;
  final List<GameCoordinate> previewCapturable;
  final List<GameCoordinate> previewShadowed;
  final bool isSpecialMode;

  GamePainter(this.gridSize, this.grid, this.touchCoord, this.previewCapturable, this.previewShadowed, this.isSpecialMode);

  @override
  void paint(Canvas canvas, Size size) {
    if (grid.isEmpty) return; 

    double cellSize = size.width / gridSize;

    Paint gridPaint = Paint()
      ..color = const Color(0x1A00F0FF) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    Paint capturedPaint = Paint()..color = const Color(0xFF00F0FF);
    Paint obstaclePaint = Paint()..color = const Color(0xFFFF003C);
    Paint obstacleCorePaint = Paint()..color = const Color(0xFFFFB3C6);

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        Rect rect = Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        if (grid[x][y] == 1) {
          canvas.drawRect(rect.deflate(cellSize * 0.15), obstaclePaint);
          canvas.drawRect(
              Rect.fromLTWH(x * cellSize + cellSize / 2 - 2, y * cellSize + cellSize / 2 - 2, 4, 4),
              obstacleCorePaint);
        } else if (grid[x][y] == 2) {
          canvas.drawRect(rect.deflate(1), Paint()..color = const Color(0x3300F0FF));
          canvas.drawRect(
              Rect.fromLTWH(x * cellSize + cellSize / 2 - 2, y * cellSize + cellSize / 2 - 2, 4, 4),
              capturedPaint);
        }
      }
    }

    // Grid lines layered on top
    for (int i = 0; i <= gridSize; i++) {
      double pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    // Draw interaction preview
    if (touchCoord != null) {
      Paint goodPaint = Paint()..color = isSpecialMode ? const Color(0x99BC13FE) : const Color(0x9900F0FF);
      Paint badPaint = Paint()..color = const Color(0x80FF003C);

      for (var p in previewCapturable) {
        canvas.drawRect(Rect.fromLTWH(p.x * cellSize, p.y * cellSize, cellSize, cellSize).deflate(1), goodPaint);
      }
      for (var p in previewShadowed) {
        canvas.drawRect(Rect.fromLTWH(p.x * cellSize, p.y * cellSize, cellSize, cellSize).deflate(1), badPaint);
      }

      Paint crosshair = Paint()
        ..color = isSpecialMode ? Colors.white : const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(Rect.fromLTWH(touchCoord!.x * cellSize, touchCoord!.y * cellSize, cellSize, cellSize).deflate(1), crosshair);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
