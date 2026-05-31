import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame/collisions.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flame/parallax.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(GameWidget(game: MyRunnerGame()));
}

// ==========================================
//                GAME ENGINE CORE
// ==========================================
class MyRunnerGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  late Player player;
  final double groundY = 400;
  final Random _random = Random();

  // Game Stats
  int score = 0;
  int distance = 0;
  int combo = 0;
  double comboTimer = 0.0;
  int coinsCollected = 0;

  // Persistence
  int highScore = 0;
  int totalCoins = 0;

  // HUD
  late TextComponent scoreText;
  late TextComponent comboText;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load Audio
    await FlameAudio.audioCache.loadAll([
      'jump.wav',
      'collect.wav',
      'powerup.wav',
      'gameover.wav',
    ]);

    await _loadProgress();

    // Background
    add(GameBackground());
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFF0F1B2E),
        priority: -10,
      ),
    );

    player = Player(groundY: groundY);
    add(player);

    add(Ground(groundY: groundY));
    add(Spawner());

    // HUD
    scoreText = TextComponent(
      text: 'Score: 0   Dist: 0m',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      position: Vector2(20, 20),
      priority: 100,
    );

    comboText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 52,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, 110),
      priority: 100,
    );

    add(scoreText);
    add(comboText);

    // Modern Camera tracking system
    camera.follow(player);

    // Register Overlays
    overlays.addEntry(
      'MainMenu',
      (context, game) => MainMenuOverlay(game: this),
    );
    overlays.addEntry(
      'GameOver',
      (context, game) => GameOverOverlay(game: this),
    );

    // Start with Main Menu
    pauseEngine();
    overlays.add('MainMenu');
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('highScore') ?? 0;
    totalCoins = prefs.getInt('totalCoins') ?? 0;
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (score > highScore) {
      highScore = score;
    }
    await prefs.setInt('highScore', highScore);
    totalCoins += coinsCollected;
    await prefs.setInt('totalCoins', totalCoins);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // FIXED: Changed .contains() to .isActive() with braces
    if (overlays.isActive('MainMenu') || overlays.isActive('GameOver')) {
      return;
    }

    distance = (player.position.x / 10).floor();
    score += (280 * dt * (1 + (combo ~/ 7))).floor();

    scoreText.text = 'Score: $score   Dist: ${distance}m';

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        combo = 0;
        comboText.text = '';
      }
    }
  }

  void addCombo(int amount) {
    combo += amount;
    comboTimer = 3.2;
    coinsCollected += amount;

    comboText.text = 'COMBO x$combo';
    comboText.scale = Vector2(1.6, 1.6);
    comboText.add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.28, curve: Curves.easeOutBack),
      ),
    );

    FlameAudio.play('collect.wav');

    if (combo >= 8 && combo % 6 == 0) {
      shakeScreen(intensity: 16);
    }
  }

  void startGame() {
    overlays.remove('MainMenu');
    resetGame();
    resumeEngine();
  }

  void gameOver() async {
    FlameAudio.play('gameover.wav');
    pauseEngine();
    await _saveProgress();
    overlays.add('GameOver');
  }

  void restartGame() {
    overlays.remove('GameOver');
    resetGame();
    resumeEngine();
  }

  void returnToMenu() {
    overlays.remove('GameOver');
    resetGame();
    pauseEngine();
    overlays.add('MainMenu');
  }

  void resetGame() {
    score = 0;
    distance = 0;
    combo = 0;
    comboTimer = 0;
    coinsCollected = 0;

    player.resetPlayer();

    children.whereType<Obstacle>().forEach((e) => e.removeFromParent());
    children.whereType<Collectible>().forEach((e) => e.removeFromParent());
    children.whereType<GoldenFeather>().forEach((e) => e.removeFromParent());
  }

  void shakeScreen({double intensity = 18.0, double duration = 0.7}) {
    final original = camera.viewfinder.position.clone();
    final shake = SequenceEffect(
      List.generate(14, (i) {
        final p = i / 13;
        final curr = intensity * (1 - p * 0.8);
        return MoveEffect.to(
          original +
              Vector2(
                (_random.nextDouble() - 0.5) * curr,
                (_random.nextDouble() - 0.5) * curr * 0.7,
              ),
          EffectController(duration: duration / 14, curve: Curves.easeOut),
        );
      }),
      onComplete: () => camera.viewfinder.add(
        MoveEffect.to(original, EffectController(duration: 0.1)),
      ),
    );
    camera.viewfinder.add(shake);
  }

  @override
  void onTapDown(TapDownEvent event) => player.startCharge();
  @override
  void onTapUp(TapUpEvent event) => player.endCharge();
  @override
  void onTapCancel(TapCancelEvent event) => player.endCharge();
}

// ==========================================
//                PLAYER
// ==========================================
class Player extends SpriteAnimationComponent
    with CollisionCallbacks, HasGameReference<MyRunnerGame> {
  final double groundY;
  double velocityY = 0;
  final double gravity = 920;
  final double normalJumpStrength = -550;
  final double phoenixJumpStrength = -720;

  double _currentJumpStrength = -550;
  bool isOnGround = true;
  bool isPhoenix = false;
  int phoenixLevel = 1;
  double phoenixTimeRemaining = 0;

  bool isCharging = false;
  double chargeTime = 0;

  late SpriteAnimation runAnimation;
  late SpriteAnimation jumpAnimation;
  late SpriteAnimation phoenixAnimation;

  Player({required this.groundY})
    : super(
        size: Vector2(68, 68),
        position: Vector2(100, 300),
        anchor: Anchor.bottomLeft,
      );

  void resetPlayer() {
    position = Vector2(100, 300);
    velocityY = 0;
    isOnGround = true;
    isPhoenix = false;
    phoenixLevel = 1;
    phoenixTimeRemaining = 0;
    _currentJumpStrength = normalJumpStrength;
    animation = runAnimation;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final image = await game.images.load('dash_spritesheet.png');
    final sheet = SpriteSheet.fromColumnsAndRows(
      image: image,
      columns: 8,
      rows: 3,
    );

    runAnimation = sheet.createAnimation(row: 0, stepTime: 0.07, loop: true);
    jumpAnimation = sheet.createAnimation(row: 1, stepTime: 0.11, loop: false);
    phoenixAnimation = sheet.createAnimation(
      row: 2,
      stepTime: 0.07,
      loop: true,
    );

    animation = runAnimation;

    add(
      RectangleHitbox(
        size: Vector2(size.x * 0.65, size.y * 0.82),
        position: Vector2(size.x * 0.18, size.y * 0.1),
      ),
    );
  }

  void startCharge() {
    if (isOnGround) isCharging = true;
  }

  void endCharge() {
    if (isCharging && isOnGround) {
      final power = (chargeTime * 1.15).clamp(0.0, 1.45);
      velocityY = _currentJumpStrength * (1 + power);
      isOnGround = false;
      animation = isPhoenix ? phoenixAnimation : jumpAnimation;
      FlameAudio.play('jump.wav');
    }
    isCharging = false;
    chargeTime = 0;
  }

  void activatePhoenix(double duration, {int level = 1}) {
    isPhoenix = true;
    phoenixLevel = level.clamp(1, 3);
    phoenixTimeRemaining = duration;
    _currentJumpStrength = phoenixJumpStrength;
    animation = phoenixAnimation;

    FlameAudio.play('powerup.wav');
    _spawnPhoenixParticles();
    game.shakeScreen(intensity: 12 + level * 6);
  }

  void _spawnPhoenixParticles() {
    final rand = Random();
    game.add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 55,
          lifespan: 1.7,
          generator: (i) => AcceleratedParticle(
            position: position + Vector2(width / 2, -height / 2.5),
            speed: Vector2(
              (rand.nextDouble() - 0.5) * 280,
              -rand.nextDouble() * 200 - 70,
            ),
            acceleration: Vector2(0, 160),
            child: CircleParticle(
              radius: rand.nextDouble() * 6 + 3,
              paint: Paint()..color = Colors.orangeAccent,
            ),
          ),
        ),
      ),
    );
  }

  void _deactivatePhoenix() {
    isPhoenix = false;
    phoenixLevel = 1;
    phoenixTimeRemaining = 0;
    _currentJumpStrength = normalJumpStrength;
    if (isOnGround) animation = runAnimation;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // FIXED: Changed .contains() to .isActive()
    if (game.overlays.isActive('MainMenu') ||
        game.overlays.isActive('GameOver')) {
      return;
    }

    if (isPhoenix) {
      phoenixTimeRemaining -= dt;
      if (phoenixTimeRemaining <= 0) _deactivatePhoenix();
    }

    if (isCharging) chargeTime += dt;

    final currentSpeed = 265 + (position.x / 6500) * 125;
    position.x += currentSpeed * dt;

    velocityY += gravity * dt;
    position.y += velocityY * dt;

    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;
      if (!isOnGround) {
        isOnGround = true;
        animation = isPhoenix ? phoenixAnimation : runAnimation;
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is Obstacle) {
      if (isPhoenix) {
        other.removeFromParent();
      } else {
        game.gameOver();
      }
    } else if (other is Collectible) {
      other.removeFromParent();
      game.addCombo(1);
    } else if (other is GoldenFeather) {
      other.removeFromParent();
      final newDuration = isPhoenix ? phoenixTimeRemaining + 4.5 : 6.0;
      final newLevel = isPhoenix ? phoenixLevel + 1 : 1;
      activatePhoenix(newDuration, level: newLevel);
    }
  }
}

// ==========================================
//           ENVIRONMENT & OBJECTS
// ==========================================
class Ground extends RectangleComponent {
  Ground({required double groundY})
    : super(
        size: Vector2(999999, 45),
        position: Vector2(0, groundY),
        paint: Paint()..color = Colors.green.shade800,
      );
}

class Obstacle extends RectangleComponent with CollisionCallbacks {
  Obstacle(Vector2 pos, {Vector2? customSize})
    : super(
        size: customSize ?? Vector2(42, 68),
        position: pos,
        paint: Paint()..color = Colors.red.shade700,
      ) {
    add(RectangleHitbox());
  }
}

class Collectible extends CircleComponent with CollisionCallbacks {
  Collectible(Vector2 pos)
    : super(
        radius: 17,
        position: pos,
        paint: Paint()..color = Colors.yellow.shade300,
      ) {
    add(CircleHitbox());
  }
}

class GoldenFeather extends SpriteComponent
    with CollisionCallbacks, HasGameReference<MyRunnerGame> {
  GoldenFeather(Vector2 pos) : super(position: pos, size: Vector2(50, 50));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('golden_feather.png');
    add(CircleHitbox());
  }
}

// ==========================================
//                SPAWNER
// ==========================================
class Spawner extends Component with HasGameReference<MyRunnerGame> {
  double timer = 0;
  double spawnInterval = 1.75;

  @override
  void update(double dt) {
    super.update(dt);

    // FIXED: Changed .contains() to .isActive() with braces
    if (game.overlays.isActive('MainMenu') ||
        game.overlays.isActive('GameOver')) {
      return;
    }

    timer += dt;
    spawnInterval = (2.1 - game.player.position.x / 9500).clamp(0.82, 2.1);

    if (timer > spawnInterval) {
      timer = 0;
      final rand = game._random.nextDouble();
      final spawnX = game.player.position.x + game.size.x + 90;

      if (rand < 0.09) {
        game.add(GoldenFeather(Vector2(spawnX, game.groundY - 175)));
      } else if (rand < 0.33) {
        for (int i = 0; i < 5; i++) {
          game.add(
            Collectible(
              Vector2(spawnX + i * 46, game.groundY - 115 - (i % 3) * 45),
            ),
          );
        }
      } else if (rand < 0.55) {
        game.add(
          Obstacle(
            Vector2(spawnX, game.groundY - 195),
            customSize: Vector2(52, 50),
          ),
        );
      } else {
        game.add(Obstacle(Vector2(spawnX, game.groundY - 65)));
      }
    }
  }
}

// ==========================================
//                PARALLAX BACKGROUND
// ==========================================
class GameBackground extends ParallaxComponent<MyRunnerGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    parallax = await game.loadParallax(
      [
        ParallaxImageData('bg_sky.png'),
        ParallaxImageData('bg_mountains.png'),
        ParallaxImageData('bg_hills.png'),
        ParallaxImageData('bg_trees.png'),
      ],
      baseVelocity: Vector2(35, 0),
      velocityMultiplierDelta: Vector2(2.8, 1.0),
    );
  }
}

// ==========================================
//                MAIN MENU
// ==========================================
class MainMenuOverlay extends StatelessWidget {
  final MyRunnerGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        width: 420,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "PHOENIX RUN",
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "High Score: ${game.highScore}",
              style: const TextStyle(fontSize: 26, color: Colors.white),
            ),
            Text(
              "Total Coins: ${game.totalCoins}",
              style: const TextStyle(fontSize: 26, color: Colors.amber),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: game.startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 20,
                ),
              ),
              child: const Text(
                "PLAY",
                style: TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
//                GAME OVER
// ==========================================
class GameOverOverlay extends StatelessWidget {
  final MyRunnerGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        width: 380,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "GAME OVER",
              style: TextStyle(
                fontSize: 42,
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Score: ${game.score}",
              style: const TextStyle(fontSize: 28, color: Colors.white),
            ),
            Text(
              "Distance: ${game.distance}m",
              style: const TextStyle(fontSize: 24, color: Colors.white70),
            ),
            Text(
              "Coins: +${game.coinsCollected}",
              style: const TextStyle(fontSize: 24, color: Colors.amber),
            ),
            Text(
              "High Score: ${game.highScore}",
              style: const TextStyle(fontSize: 22, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: game.returnToMenu,
                  child: const Text("MENU"),
                ),
                ElevatedButton(
                  onPressed: game.restartGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text("RESTART"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
