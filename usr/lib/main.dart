import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const AngryBirdsCloneApp());
}

class AngryBirdsCloneApp extends StatelessWidget {
  const AngryBirdsCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Angry Birds Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GameScreen(),
      },
    );
  }
}

enum GameState { ready, dragging, flying, finished }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;

  // Game Constants (Logical Size: 1000x600)
  final double logicalWidth = 1000;
  final double logicalHeight = 600;
  final double groundY = 500;
  final double gravity = 1200.0;
  final Offset slingAnchor = const Offset(200, 400);
  final double maxDragDistance = 100.0;
  final double dragMultiplier = 7.0;
  final double birdRadius = 15.0;

  // Game State
  GameState gameState = GameState.ready;
  Offset birdPos = const Offset(200, 400);
  Offset birdVelocity = Offset.zero;
  int score = 0;
  int birdsLeft = 3;
  bool levelCleared = false;

  // Entities
  List<Pig> pigs = [];
  List<Block> blocks = [];
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    _initLevel();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _initLevel() {
    gameState = GameState.ready;
    birdPos = slingAnchor;
    birdVelocity = Offset.zero;
    score = 0;
    birdsLeft = 3;
    levelCleared = false;
    particles.clear();

    // Create a simple structure
    blocks = [
      // Left tower
      Block(const Rect.fromLTWH(650, 400, 20, 100)),
      Block(const Rect.fromLTWH(750, 400, 20, 100)),
      Block(const Rect.fromLTWH(640, 380, 140, 20)), // Roof
      
      // Right tower
      Block(const Rect.fromLTWH(850, 400, 20, 100)),
      Block(const Rect.fromLTWH(950, 400, 20, 100)),
      Block(const Rect.fromLTWH(840, 380, 140, 20)), // Roof
      
      // Center bridge
      Block(const Rect.fromLTWH(760, 280, 100, 20)),
    ];

    pigs = [
      Pig(const Offset(710, 480), 18), // Inside left tower
      Pig(const Offset(910, 480), 18), // Inside right tower
      Pig(const Offset(810, 260), 18), // On top of center bridge
    ];
  }

  void _nextBird() {
    if (pigs.every((p) => !p.isAlive)) {
      setState(() {
        levelCleared = true;
        gameState = GameState.finished;
      });
      return;
    }

    if (birdsLeft > 1) {
      setState(() {
        birdsLeft--;
        gameState = GameState.ready;
        birdPos = slingAnchor;
        birdVelocity = Offset.zero;
      });
    } else {
      setState(() {
        birdsLeft = 0;
        gameState = GameState.finished;
      });
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    double dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    // Update particles
    for (int i = particles.length - 1; i >= 0; i--) {
      particles[i].update(dt);
      if (particles[i].life <= 0) {
        particles.removeAt(i);
      }
    }

    if (gameState != GameState.flying) {
      setState(() {});
      return;
    }

    // Physics Update
    birdVelocity += Offset(0, gravity) * dt;
    birdPos += birdVelocity * dt;

    bool collisionOccurred = false;

    // Floor collision
    if (birdPos.dy + birdRadius >= groundY) {
      birdPos = Offset(birdPos.dx, groundY - birdRadius);
      birdVelocity = Offset(birdVelocity.dx * 0.6, -birdVelocity.dy * 0.4); // Friction and bounce
      collisionOccurred = true;
    }

    // Off-screen check
    if (birdPos.dx > logicalWidth + 100 || birdPos.dx < -100) {
      _nextBird();
      return;
    }

    // Pig collisions (Circle vs Circle)
    for (var pig in pigs) {
      if (!pig.isAlive) continue;
      double dist = (birdPos - pig.position).distance;
      if (dist < birdRadius + pig.radius) {
        pig.isAlive = false;
        score += 500;
        birdVelocity *= 0.8; // Slow down bird
        _spawnParticles(pig.position, Colors.green);
        collisionOccurred = true;
      }
    }

    // Block collisions (Circle vs AABB)
    for (var block in blocks) {
      if (!block.isAlive) continue;
      
      // Find closest point on rect to circle center
      double testX = birdPos.dx.clamp(block.rect.left, block.rect.right);
      double testY = birdPos.dy.clamp(block.rect.top, block.rect.bottom);
      
      double distX = birdPos.dx - testX;
      double distY = birdPos.dy - testY;
      double distance = sqrt((distX * distX) + (distY * distY));

      if (distance <= birdRadius) {
        block.isAlive = false;
        score += 100;
        _spawnParticles(block.rect.center, Colors.brown);
        collisionOccurred = true;

        // Simple bounce resolution
        if (birdPos.dx < block.rect.left || birdPos.dx > block.rect.right) {
          birdVelocity = Offset(-birdVelocity.dx * 0.5, birdVelocity.dy * 0.8);
        } else {
          birdVelocity = Offset(birdVelocity.dx * 0.8, -birdVelocity.dy * 0.5);
        }
      }
    }

    // Stop bird if it's moving very slowly on the ground
    if (birdPos.dy >= groundY - birdRadius - 1 && birdVelocity.distance < 30) {
      _nextBird();
    }

    setState(() {});
  }

  void _spawnParticles(Offset pos, Color color) {
    final random = Random();
    for (int i = 0; i < 10; i++) {
      double angle = random.nextDouble() * 2 * pi;
      double speed = random.nextDouble() * 150 + 50;
      particles.add(Particle(
        position: pos,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        color: color,
        life: 0.5 + random.nextDouble() * 0.5,
      ));
    }
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    if (gameState != GameState.ready) return;
    
    // Convert screen coordinates to logical coordinates
    double scaleX = logicalWidth / size.width;
    double scaleY = logicalHeight / size.height;
    Offset logicalTouch = Offset(details.localPosition.dx * scaleX, details.localPosition.dy * scaleY);

    if ((logicalTouch - birdPos).distance < 50) {
      setState(() {
        gameState = GameState.dragging;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    if (gameState != GameState.dragging) return;

    double scaleX = logicalWidth / size.width;
    double scaleY = logicalHeight / size.height;
    Offset logicalTouch = Offset(details.localPosition.dx * scaleX, details.localPosition.dy * scaleY);

    Offset dragVector = logicalTouch - slingAnchor;
    if (dragVector.distance > maxDragDistance) {
      dragVector = (dragVector / dragVector.distance) * maxDragDistance;
    }

    setState(() {
      birdPos = slingAnchor + dragVector;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (gameState != GameState.dragging) return;

    Offset dragVector = slingAnchor - birdPos;
    
    // Only launch if dragged far enough
    if (dragVector.distance > 10) {
      setState(() {
        gameState = GameState.flying;
        birdVelocity = dragVector * dragMultiplier;
      });
    } else {
      setState(() {
        gameState = GameState.ready;
        birdPos = slingAnchor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          Size screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          
          return GestureDetector(
            onPanStart: (details) => _handlePanStart(details, screenSize),
            onPanUpdate: (details) => _handlePanUpdate(details, screenSize),
            onPanEnd: _handlePanEnd,
            child: Stack(
              children: [
                // Game Canvas
                CustomPaint(
                  size: screenSize,
                  painter: GamePainter(
                    logicalSize: Size(logicalWidth, logicalHeight),
                    gameState: gameState,
                    birdPos: birdPos,
                    slingAnchor: slingAnchor,
                    birdRadius: birdRadius,
                    groundY: groundY,
                    pigs: pigs,
                    blocks: blocks,
                    particles: particles,
                    dragMultiplier: dragMultiplier,
                    gravity: gravity,
                  ),
                ),
                
                // UI Overlay
                Positioned(
                  top: 40,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: $score',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          3,
                          (index) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.circle,
                              color: index < birdsLeft ? Colors.red : Colors.grey.withOpacity(0.5),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 32),
                    onPressed: _initLevel,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                ),

                // Game Over / Win Screen
                if (gameState == GameState.finished)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            levelCleared ? 'LEVEL CLEARED!' : 'GAME OVER',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Final Score: $score',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton.icon(
                            onPressed: _initLevel,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 20)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Models ---

class Pig {
  Offset position;
  double radius;
  bool isAlive = true;
  Pig(this.position, this.radius);
}

class Block {
  Rect rect;
  bool isAlive = true;
  Block(this.rect);
}

class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double life;
  double maxLife;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
  }) : maxLife = life;

  void update(double dt) {
    position += velocity * dt;
    life -= dt;
  }
}

// --- Rendering ---

class GamePainter extends CustomPainter {
  final Size logicalSize;
  final GameState gameState;
  final Offset birdPos;
  final Offset slingAnchor;
  final double birdRadius;
  final double groundY;
  final List<Pig> pigs;
  final List<Block> blocks;
  final List<Particle> particles;
  final double dragMultiplier;
  final double gravity;

  GamePainter({
    required this.logicalSize,
    required this.gameState,
    required this.birdPos,
    required this.slingAnchor,
    required this.birdRadius,
    required this.groundY,
    required this.pigs,
    required this.blocks,
    required this.particles,
    required this.dragMultiplier,
    required this.gravity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale canvas to fit logical size
    double scaleX = size.width / logicalSize.width;
    double scaleY = size.height / logicalSize.height;
    canvas.scale(scaleX, scaleY);

    _drawBackground(canvas);
    _drawBlocks(canvas);
    _drawPigs(canvas);
    
    if (gameState == GameState.dragging) {
      _drawTrajectory(canvas);
    }
    
    _drawSlingshotBack(canvas);
    
    if (gameState != GameState.finished || birdsLeft > 0) {
      _drawBird(canvas, birdPos);
    }
    
    _drawSlingshotFront(canvas);
    _drawParticles(canvas);
  }

  void _drawBackground(Canvas canvas) {
    // Sky
    final skyPaint = Paint()..color = const Color(0xFF87CEEB);
    canvas.drawRect(Rect.fromLTWH(0, 0, logicalSize.width, groundY), skyPaint);

    // Sun
    final sunPaint = Paint()..color = Colors.yellow.withOpacity(0.8);
    canvas.drawCircle(const Offset(850, 100), 50, sunPaint);

    // Ground
    final groundPaint = Paint()..color = const Color(0xFF55AA55);
    canvas.drawRect(Rect.fromLTWH(0, groundY, logicalSize.width, logicalSize.height - groundY), groundPaint);
    
    // Ground dirt
    final dirtPaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRect(Rect.fromLTWH(0, groundY + 20, logicalSize.width, logicalSize.height - groundY - 20), dirtPaint);
  }

  void _drawSlingshotBack(Canvas canvas) {
    final woodPaint = Paint()
      ..color = const Color(0xFF5C4033)
      ..style = PaintingStyle.fill;
    
    // Back pole
    canvas.drawRect(Rect.fromLTWH(slingAnchor.dx - 15, slingAnchor.dy, 10, groundY - slingAnchor.dy), woodPaint);
    
    // Back rubber band
    if (gameState == GameState.dragging || gameState == GameState.ready) {
      final bandPaint = Paint()
        ..color = const Color(0xFF301934)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(slingAnchor.dx - 10, slingAnchor.dy + 10), birdPos, bandPaint);
    }
  }

  void _drawSlingshotFront(Canvas canvas) {
    final woodPaint = Paint()
      ..color = const Color(0xFF8B5A2B)
      ..style = PaintingStyle.fill;
    
    // Main stem
    canvas.drawRect(Rect.fromLTWH(slingAnchor.dx - 5, slingAnchor.dy + 30, 15, groundY - slingAnchor.dy - 30), woodPaint);
    
    // Front pole
    canvas.drawRect(Rect.fromLTWH(slingAnchor.dx + 5, slingAnchor.dy, 10, 40), woodPaint);

    // Front rubber band
    if (gameState == GameState.dragging || gameState == GameState.ready) {
      final bandPaint = Paint()
        ..color = const Color(0xFF4A0E4E)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(slingAnchor.dx + 10, slingAnchor.dy + 10), birdPos, bandPaint);
    }
  }

  void _drawBird(Canvas canvas, Offset pos) {
    // Body
    final bodyPaint = Paint()..color = const Color(0xFFD32F2F);
    canvas.drawCircle(pos, birdRadius, bodyPaint);

    // Belly
    final bellyPaint = Paint()..color = const Color(0xFFE0E0E0);
    canvas.drawArc(
      Rect.fromCircle(center: pos, radius: birdRadius),
      0, pi, true, bellyPaint,
    );

    // Eyes
    final whitePaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    canvas.drawCircle(pos + const Offset(4, -4), 4, whitePaint);
    canvas.drawCircle(pos + const Offset(12, -4), 4, whitePaint);
    canvas.drawCircle(pos + const Offset(5, -4), 1.5, blackPaint);
    canvas.drawCircle(pos + const Offset(13, -4), 1.5, blackPaint);

    // Beak
    final beakPaint = Paint()..color = const Color(0xFFFFC107);
    final path = Path()
      ..moveTo(pos.dx + 14, pos.dy)
      ..lineTo(pos.dx + 22, pos.dy + 4)
      ..lineTo(pos.dx + 14, pos.dy + 8)
      ..close();
    canvas.drawPath(path, beakPaint);
  }

  void _drawPigs(Canvas canvas) {
    for (var pig in pigs) {
      if (!pig.isAlive) continue;
      
      // Body
      final bodyPaint = Paint()..color = const Color(0xFF8BC34A);
      canvas.drawCircle(pig.position, pig.radius, bodyPaint);
      
      // Snout
      final snoutPaint = Paint()..color = const Color(0xFF689F38);
      canvas.drawOval(
        Rect.fromCenter(center: pig.position + const Offset(5, 2), width: 14, height: 10),
        snoutPaint,
      );
      
      // Snout holes
      final blackPaint = Paint()..color = const Color(0xFF33691E);
      canvas.drawCircle(pig.position + const Offset(2, 2), 1.5, blackPaint);
      canvas.drawCircle(pig.position + const Offset(8, 2), 1.5, blackPaint);

      // Eyes
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawCircle(pig.position + const Offset(0, -6), 3, whitePaint);
      canvas.drawCircle(pig.position + const Offset(10, -6), 3, whitePaint);
      canvas.drawCircle(pig.position + const Offset(1, -6), 1, blackPaint);
      canvas.drawCircle(pig.position + const Offset(11, -6), 1, blackPaint);
    }
  }

  void _drawBlocks(Canvas canvas) {
    final woodPaint = Paint()..color = const Color(0xFFD7CCC8);
    final borderPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var block in blocks) {
      if (!block.isAlive) continue;
      canvas.drawRect(block.rect, woodPaint);
      canvas.drawRect(block.rect, borderPaint);
      
      // Draw some wood grain lines
      canvas.drawLine(
        Offset(block.rect.left + 5, block.rect.top + 5),
        Offset(block.rect.right - 5, block.rect.bottom - 5),
        borderPaint..strokeWidth = 1,
      );
    }
  }

  void _drawTrajectory(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    Offset pos = birdPos;
    Offset vel = (slingAnchor - birdPos) * dragMultiplier;
    
    // Simulate physics for trajectory
    for (int i = 0; i < 40; i++) {
      vel += Offset(0, gravity) * 0.05;
      pos += vel * 0.05;
      
      if (i % 3 == 0) {
        canvas.drawCircle(pos, 3, paint);
      }
      
      if (pos.dy > groundY) break;
    }
  }

  void _drawParticles(Canvas canvas) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.life / particle.maxLife)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(particle.position, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
